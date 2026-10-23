import Foundation
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
@Observable
final class DayStore {
    var days: [Day] {
        didSet {
            guard !isRestoring else { return }
            guard save() else {
                isRestoring = true
                days = oldValue
                isRestoring = false
                return
            }
            removeUnusedPhotos()
            rescheduleNotifications()
            reloadWidgetTimelines()
        }
    }
    var categories: [CategoryDefinition] {
        didSet {
            guard !isRestoring else { return }
            guard saveCategories() else {
                isRestoring = true
                categories = oldValue
                isRestoring = false
                return
            }
            // Widget cards take a custom category's colour, which can change without any day changing.
            reloadWidgetTimelines()
        }
    }
    private(set) var deletedDays: [DeletedDay] = []
    /// The most recent deletion, offered for undo until dismissed.
    private(set) var lastDeleted: DeletedDay?
    private(set) var syncConflicts: [SyncConflict] = []
    // Failures are kept as values rather than text, so their messages follow a language change.
    private var loadFailed = false
    private enum SaveFailure { case library, categories }
    private var saveFailure: SaveFailure?
    private var syncPreparationFailure: Error?

    var loadError: String? {
        loadFailed ? String(localized: "本机数据未能完整读取，原始数据已保留。请先导出原始数据，或从备份恢复。",
                            bundle: AppLocalization.bundle, locale: AppLocalization.locale) : nil
    }

    var saveError: String? {
        switch saveFailure {
        case nil: return nil
        case .library:
            return String(localized: "本机数据未能保存，之前的数据已保留。请检查可用空间，或从备份恢复。",
                          bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .categories:
            return String(localized: "分类更改未能保存，之前的数据已保留。请检查可用空间，或从备份恢复。",
                          bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
    }

    var syncPreparationError: String? {
        syncPreparationFailure.map { error in
            String(localized: "迁移前备份未完成，同步尚未开启；本机日子仍可使用。\(error.localizedDescription)",
                   bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
    }

    private let storageKey: String
    private let photoFiles: PhotoFileStore?
    private let categoriesKey = SharedStorage.categoriesKey
    private let deletedKey = "deletedDays.v1"
    private let conflictsKey = "syncConflicts.v1"
    private let recoveryKey = "recoveryBackup.v1"
    /// Raw stored data kept when a restore replaces a library that couldn't be read or backed up.
    private let unreadableKey = "unreadableData.v1"
    private let migrationKey = "preCloudKitBackup.v1"
    private let migrationDecidedKey = "preCloudKitBackupDecided.v1"
    private let legacyDayIDsKey = "importedLegacyDayIDs.v1"
    private let legacyCategoryIDsKey = "importedLegacyCategoryIDs.v1"
    private let pendingRestoreKey = "pendingRestore.v1"
    private let defaults: UserDefaults
    private var isRestoring = false
    private var cloudSyncEnabled = false
    private var cloudSyncRequested = false
    /// Debounce/serialize handle for `NotificationManager.sync`.
    private(set) var rescheduleTask: Task<Void, Never>?
    /// Set after init so we can wire the notification scheduler without a circular dependency.
    var settings: AppSettings? {
        didSet { rescheduleNotifications() }
    }

    convenience init() {
        self.init(defaults: SharedStorage.defaults, photoDirectory: SharedStorage.photoDirectory)
    }

    /// Custom stores can omit file storage; the app and widget always share the App Group directory.
    init(defaults: UserDefaults, photoDirectory: URL? = nil) {
        self.defaults = defaults
        self.photoFiles = photoDirectory.map(PhotoFileStore.init(directory:))
        self.storageKey = photoDirectory == nil ? SharedStorage.legacyDaysKey : SharedStorage.daysKey
        self.days = []
        self.categories = CategoryDefinition.system
        isRestoring = true
        defer { isRestoring = false }
        do {
            // Replay an interrupted restore before exposing any partially restored data.
            if let pending = defaults.data(forKey: pendingRestoreKey) {
                let backup = try (photoFiles?.decoder() ?? JSONDecoder()).decode(DayBackup.self, from: pending)
                try backup.validate()
                try writeBackup(backup)
                defaults.removeObject(forKey: pendingRestoreKey)
            }
            if let data = defaults.data(forKey: storageKey) ?? defaults.data(forKey: SharedStorage.legacyDaysKey) {
                let decoded = try (photoFiles?.decoder() ?? JSONDecoder()).decode([Day].self, from: data)
                try DayBackup.validateDays(decoded)
                self.days = decoded
            }
            if let data = defaults.data(forKey: categoriesKey) {
                let decoded = try JSONDecoder().decode([CategoryDefinition].self, from: data)
                guard Set(decoded.map(\.id)).count == decoded.count else {
                    throw DayBackup.BackupError.invalidRecords
                }
                self.categories = Self.normalizedCategories(decoded)
            }
            // Older builds stored these photos inline; both formats decode.
            var storedDeleted: [DeletedDay] = []
            var storedConflicts: [SyncConflict] = []
            if let data = defaults.data(forKey: deletedKey) {
                storedDeleted = try (photoFiles?.decoder() ?? JSONDecoder()).decode([DeletedDay].self, from: data)
                self.deletedDays = Self.unexpired(storedDeleted.filter { entry in !days.contains(where: { $0.id == entry.id }) })
            }
            if let data = defaults.data(forKey: conflictsKey) {
                storedConflicts = try (photoFiles?.decoder() ?? JSONDecoder()).decode([SyncConflict].self, from: data)
                self.syncConflicts = Self.unexpired(storedConflicts)
            }
            try DayBackup(days: days, categories: categories, deletedDays: deletedDays,
                          syncConflicts: syncConflicts).validate()
            // Expired entries leave storage too, and their photos with them.
            if deletedDays != storedDeleted { persistDeletedDays() }
            if syncConflicts != storedConflicts,
               let data = try? (photoFiles?.encoder() ?? JSONEncoder()).encode(syncConflicts) {
                defaults.set(data, forKey: conflictsKey)
            }
            removeUnusedPhotos()
        } catch {
            loadFailed = true
        }
    }

    @discardableResult
    func save() -> Bool {
        persist(days, storageKey: storageKey)
    }

    @discardableResult
    func saveCategories() -> Bool {
        persist(categories, storageKey: categoriesKey, failure: .categories)
    }

    /// `failure` picks the message shown when the write fails.
    private func persist<Value: Encodable>(_ value: Value, storageKey: String,
                                           failure: SaveFailure = .library) -> Bool {
        guard loadError == nil else { return false }
        do {
            let data = try (photoFiles?.encoder() ?? JSONEncoder()).encode(value)
            defaults.set(data, forKey: storageKey)
            saveFailure = nil
            if cloudSyncEnabled {
                CloudLibrarySync.shared.updateLocal(days: days, categories: categories)
            }
            return true
        } catch {
            saveFailure = failure
            return false
        }
    }

    func dismissSaveError() {
        saveFailure = nil
    }

    /// Asks WidgetKit to rebuild every timeline; tests replace it to count the requests.
    @ObservationIgnored var reloadWidgets: () -> Void = {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func reloadWidgetTimelines() {
        reloadWidgets()
    }

    @discardableResult
    func add(_ day: Day) -> Bool {
        saveFailure = nil
        guard loadError == nil, !days.contains(where: { $0.id == day.id }) else { return false }
        // Restore the active copy before removing its recoverable deleted copy.
        days.insert(normalized(day), at: 0)
        guard saveError == nil else { return false }
        deletedDays.removeAll { $0.id == day.id }
        persistDeletedDays()
        return true
    }
    @discardableResult
    func update(_ day: Day) -> Bool {
        saveFailure = nil
        guard loadError == nil, let i = days.firstIndex(where: { $0.id == day.id }) else { return false }
        days[i] = normalized(day)
        return saveError == nil
    }

    /// Saves an edit made from `base`, the day as its editor opened it. A sync can change the day
    /// while the editor is open: what the edit left alone keeps the newer value, and where both
    /// changed the same thing the edit wins and the version it replaces is kept in 同步保留版本.
    @discardableResult
    func update(_ edit: Day, editedFrom base: Day) -> Bool {
        saveFailure = nil
        guard loadError == nil, let i = days.firstIndex(where: { $0.id == edit.id }) else { return false }
        let current = days[i]
        guard current != base else { return update(edit) }
        let (merged, conflicted) = Self.merging(edit, from: base, onto: current)
        guard conflicted else { return update(merged) }
        var nextDays = days
        nextDays[i] = normalized(merged)
        commitChange(days: nextDays, categories: categories,
                     syncConflicts: Self.unexpired(syncConflicts + [SyncConflict(record: .day(current))]),
                     failure: .library)
        return saveError == nil
    }

    /// A three-way merge of `edit`, made from `base`, onto `current`. Fields that only mean something
    /// together (the date and its calendar, a photo and its framing, a category and its label, the
    /// reminders and their time) move as one group; `conflicted` is true when both sides changed a
    /// group differently, and there the edit wins, or `current` does when `editWins` is false.
    ///
    /// Nonisolated, as it reads no store state: Swift 6.2 rejects the nested `group` capturing its
    /// closures in a Release build when the merge is main-actor isolated.
    nonisolated static func merging(_ edit: Day, from base: Day, onto current: Day,
                                    editWins: Bool = true) -> (day: Day, conflicted: Bool) {
        var merged = current
        var conflicted = false
        func group(_ same: (Day, Day) -> Bool, _ copy: (inout Day, Day) -> Void) {
            guard !same(edit, base) else { return }
            if !same(current, base) && !same(current, edit) {
                conflicted = true
                guard editWins else { return }
            }
            copy(&merged, edit)
        }
        group({ $0.title == $1.title }) { $0.title = $1.title }
        group({ $0.date == $1.date && $0.recurring == $1.recurring && $0.lunar == $1.lunar }) {
            $0.date = $1.date; $0.recurring = $1.recurring; $0.lunar = $1.lunar
        }
        group({ $0.categoryID == $1.categoryID && $0.categoryLabel == $1.categoryLabel && $0.category == $1.category }) {
            $0.categoryID = $1.categoryID; $0.categoryLabel = $1.categoryLabel; $0.category = $1.category
        }
        group({ $0.photo == $1.photo && $0.photoData == $1.photoData
                && $0.coverFocusX == $1.coverFocusX && $0.coverFocusY == $1.coverFocusY }) {
            $0.photo = $1.photo; $0.photoData = $1.photoData; $0.coverFocusX = $1.coverFocusX; $0.coverFocusY = $1.coverFocusY
        }
        group({ $0.reminderOffsets == $1.reminderOffsets && $0.reminderTime == $1.reminderTime }) {
            $0.reminderOffsets = $1.reminderOffsets; $0.reminderTime = $1.reminderTime
        }
        group({ $0.note == $1.note }) { $0.note = $1.note }
        group({ $0.location == $1.location }) { $0.location = $1.location }
        group({ $0.pinned == $1.pinned }) { $0.pinned = $1.pinned }
        return (merged, conflicted)
    }
    func delete(_ day: Day) {
        guard loadError == nil, let current = days.first(where: { $0.id == day.id }) else { return }
        let id = day.id
        let previous = deletedDays
        deletedDays.removeAll { $0.id == id }
        deletedDays.insert(DeletedDay(day: current, deletedAt: .now), at: 0)
        deletedDays = Self.unexpired(deletedDays)
        // Keep the day active unless its recoverable copy was saved first.
        guard persistDeletedDays() else {
            deletedDays = previous
            saveFailure = .library
            return
        }
        days.removeAll { $0.id == id }
        // The active list couldn't be saved, so the day is still active: take back its trash entry.
        guard !days.contains(where: { $0.id == id }) else {
            deletedDays = previous
            persistDeletedDays()
            return
        }
        lastDeleted = deletedDays.first { $0.id == id }
        Task { await NotificationManager.shared.cancel(dayId: id) }
    }

    func undoLastDeletion() {
        guard let entry = lastDeleted else { return }
        lastDeleted = nil
        restoreDeletedDay(id: entry.id)
    }

    func dismissLastDeletion() {
        lastDeleted = nil
    }

    func restoreDeletedDay(id: String) {
        guard loadError == nil, let entry = deletedDays.first(where: { $0.id == id }),
              !days.contains(where: { $0.id == id }) else { return }
        add(entry.day)
    }

    /// Deletes the day from every copy this device keeps of it: 最近删除, 同步保留版本, the
    /// recovery copy and the pre-migration backup. Its photo goes with the last of them.
    func permanentlyDeleteDay(id: String) {
        guard loadError == nil else { return }
        let previous = deletedDays
        deletedDays.removeAll { $0.id == id }
        // The entry stays listed while it is still on disk.
        guard persistDeletedDays() else {
            deletedDays = previous
            saveFailure = .library
            return
        }
        // Still seen, so that 导入旧版 iCloud 数据 can't bring it back.
        let seen = defaults.stringArray(forKey: legacyDayIDsKey) ?? []
        if !seen.contains(id) { defaults.set(seen + [id], forKey: legacyDayIDsKey) }
        let conflicts = syncConflicts.filter { !Self.isVersion(of: id, $0) }
        if conflicts != syncConflicts, let data = try? (photoFiles?.encoder() ?? JSONEncoder()).encode(conflicts) {
            defaults.set(data, forKey: conflictsKey)
            syncConflicts = conflicts
        }
        for key in [recoveryKey, migrationKey] { removeDay(id, fromBackupAt: key) }
        removeUnusedPhotos()
    }

    private static func isVersion(of dayID: String, _ conflict: SyncConflict) -> Bool {
        if case .day(let day) = conflict.record { return day.id == dayID }
        return false
    }

    private func removeDay(_ id: String, fromBackupAt key: String) {
        guard let data = defaults.data(forKey: key), var backup = try? decodeLocalBackup(data) else { return }
        let count = backup.days.count + backup.deletedDays.count + backup.syncConflicts.count
        backup.days.removeAll { $0.id == id }
        backup.deletedDays.removeAll { $0.id == id }
        backup.syncConflicts.removeAll { Self.isVersion(of: id, $0) }
        guard backup.days.count + backup.deletedDays.count + backup.syncConflicts.count < count,
              let encoded = try? localBackupData(backup) else { return }
        defaults.set(encoded, forKey: key)
    }

    @discardableResult
    private func persistDeletedDays() -> Bool {
        guard let data = try? (photoFiles?.encoder() ?? JSONEncoder()).encode(deletedDays) else { return false }
        defaults.set(data, forKey: deletedKey)
        removeUnusedPhotos()
        return true
    }

    /// Photo files are shared by content, so one is deleted only once no stored record uses it:
    /// active, deleted and replaced days, and the recovery, migration and restore journals.
    private func removeUnusedPhotos() {
        guard let photoFiles, loadError == nil else { return }
        let documents = [storageKey, deletedKey, conflictsKey, recoveryKey, migrationKey, pendingRestoreKey]
            .compactMap { defaults.data(forKey: $0) }
        try? photoFiles.removeFiles(unreferencedBy: documents)
    }

    /// Recently deleted days and replaced sync versions stay recoverable for 30 days.
    static let retention: TimeInterval = 30 * 24 * 60 * 60

    private static func unexpired(_ entries: [DeletedDay], now: Date = .now) -> [DeletedDay] {
        entries.filter { now.timeIntervalSince($0.deletedAt) < retention }
    }

    private static func unexpired(_ entries: [SyncConflict], now: Date = .now) -> [SyncConflict] {
        entries.filter { now.timeIntervalSince($0.createdAt) < retention }
    }

    /// A restored backup's entries keep their dates, so older ones have already expired.
    private static func unexpired(_ backup: DayBackup) -> DayBackup {
        var current = backup
        current.deletedDays = unexpired(backup.deletedDays)
        current.syncConflicts = unexpired(backup.syncConflicts)
        return current
    }

    var hasRecoveryBackup: Bool { defaults.data(forKey: recoveryKey) != nil }
    var hasUnreadableDataCopy: Bool { defaults.data(forKey: unreadableKey) != nil }

    /// Copies of the library this device keeps besides the library itself, 最近删除 and 同步保留版本:
    /// the recovery copy, the pre-migration backup, the raw data a restore replaced, the first
    /// storage format's days, and checkpoints sync no longer uses.
    var hasInternalCopies: Bool {
        [recoveryKey, migrationKey, unreadableKey].contains { defaults.data(forKey: $0) != nil }
            || staleLegacyDays != nil || CloudLibrarySync.shared.hasStaleCheckpoints
    }

    /// The first format's days, left in place when the current one was first written. Stores
    /// without a photo directory still use that key for the library itself.
    private var staleLegacyDays: Data? {
        guard storageKey != SharedStorage.legacyDaysKey, defaults.data(forKey: storageKey) != nil else { return nil }
        return defaults.data(forKey: SharedStorage.legacyDaysKey)
    }

    /// Deletes every internal copy, and the photos only they still used. The library, 最近删除
    /// and 同步保留版本 stay.
    func clearInternalCopies() throws {
        guard loadError == nil else { throw DayBackup.BackupError.unreadable }
        try CloudLibrarySync.shared.removeStaleCheckpoints()
        if staleLegacyDays != nil { defaults.removeObject(forKey: SharedStorage.legacyDaysKey) }
        // The pre-migration backup's records stay seen, so 导入旧版 iCloud 数据 can't bring back
        // the ones deleted since.
        let seen = seenLegacyIDs()
        defaults.set(Array(seen.days), forKey: legacyDayIDsKey)
        defaults.set(Array(seen.categories), forKey: legacyCategoryIDsKey)
        for key in [recoveryKey, migrationKey, unreadableKey] { defaults.removeObject(forKey: key) }
        // Decided, so starting sync again doesn't keep a new one.
        defaults.set(true, forKey: migrationDecidedKey)
        removeUnusedPhotos()
    }

    func deleteUnreadableDataCopy() {
        defaults.removeObject(forKey: unreadableKey)
    }

    func exportUnreadableDataCopy() throws -> Data {
        guard let data = defaults.data(forKey: unreadableKey) else { throw DayBackup.BackupError.unreadable }
        return data
    }
    var hasMigrationBackup: Bool { defaults.data(forKey: migrationKey) != nil }

    private var currentBackup: DayBackup {
        DayBackup(days: days, categories: categories, deletedDays: deletedDays, syncConflicts: syncConflicts)
    }

    func exportMigrationBackup() throws -> Data {
        guard let data = defaults.data(forKey: migrationKey) else { throw DayBackup.BackupError.unreadable }
        return try decodeLocalBackup(data).encoded()
    }

    func exportBackup() throws -> Data {
        guard loadError == nil else { throw DayBackup.BackupError.unreadable }
        return try currentBackup.encoded()
    }

    /// A new raw copy leaves out the previous one, which would otherwise nest inside it, photos
    /// and all, on every repair.
    func exportOriginalData(includingRawCopy: Bool = true) throws -> Data {
        let keys = Set([storageKey, SharedStorage.legacyDaysKey, categoriesKey, deletedKey, conflictsKey, pendingRestoreKey,
                    recoveryKey, migrationKey] + (includingRawCopy ? [unreadableKey] : []))
        var original = Dictionary(uniqueKeysWithValues: keys.compactMap { key in
            defaults.data(forKey: key).map { (key, $0) }
        })
        if let photoFiles { original.merge(try photoFiles.originalFiles()) { _, current in current } }
        return try JSONEncoder().encode(original)
    }

    func restoreBackup(_ backup: DayBackup) throws {
        // An invalid backup is refused as a whole, even where only expired entries are wrong.
        try backup.validate()
        let current = Self.unexpired(backup)
        try restoreBackup(current, encoded: current.encoded())
    }

    private func restoreBackup(_ backup: DayBackup, encoded: Data?) throws {
        try backup.validate()
        let wasUnreadable = loadError != nil
        // The library being replaced becomes the recovery copy, but only once nothing can fail any
        // more: a restore that fails keeps the recovery copy it had.
        var recovery: Data?
        do {
            guard loadError == nil else { throw DayBackup.BackupError.unreadable }
            recovery = try localBackupData(currentBackup)
        } catch {
            // Damaged photo files must not prevent an explicit repair or lose their original bytes.
            // An older recovery backup is part of that raw copy, and isn't the library replaced now.
            defaults.set(try exportOriginalData(includingRawCopy: false), forKey: unreadableKey)
        }
        let data = try encoded ?? localBackupData(backup, repairCorruptFiles: true)
        try applyBackup(backup, encoded: data, repairCorruptFiles: true) { [defaults, recoveryKey] in
            if let recovery { defaults.set(recovery, forKey: recoveryKey) }
            else { defaults.removeObject(forKey: recoveryKey) }
        }
        loadFailed = false
        saveFailure = nil
        // Reminders weren't rescheduled while the library was unreadable.
        if wasUnreadable { rescheduleNotifications() }
        if cloudSyncEnabled {
            CloudLibrarySync.shared.updateLocal(days: days, categories: categories)
        } else if cloudSyncRequested {
            enableCloudSync()
        }
    }

    func restorePreviousBackup() throws {
        guard let data = defaults.data(forKey: recoveryKey) else { throw DayBackup.BackupError.unreadable }
        try restoreBackup(Self.unexpired(decodeLocalBackup(data)), encoded: nil)
    }

    /// Decided once, before CloudKit first starts: keeps the library as it was, unless it holds
    /// nothing. Libraries edited after that already belong to CloudKit.
    func keepMigrationBackup() throws {
        guard !defaults.bool(forKey: migrationDecidedKey) else { return }
        if let data = defaults.data(forKey: migrationKey) {
            // Earlier builds also kept one for a fresh, empty library.
            if let backup = try? decodeLocalBackup(data), !backup.holdsUserData {
                defaults.removeObject(forKey: migrationKey)
            }
        } else if currentBackup.holdsUserData {
            defaults.set(try localBackupData(currentBackup), forKey: migrationKey)
        }
        defaults.set(true, forKey: migrationDecidedKey)
    }

    private func localBackupData(_ backup: DayBackup, repairCorruptFiles: Bool = false) throws -> Data {
        try backup.validate()
        // Internal journals reference immutable photos and do not inherit the portable export limit.
        return try (photoFiles?.encoder(repairCorruptFiles: repairCorruptFiles) ?? JSONEncoder()).encode(backup)
    }

    private func decodeLocalBackup(_ data: Data) throws -> DayBackup {
        let backup = try (photoFiles?.decoder() ?? JSONDecoder()).decode(DayBackup.self, from: data)
        try backup.validate()
        return backup
    }

    /// `beforeWriting` runs once every fallible step has succeeded, just before the library is written.
    private func applyBackup(_ backup: DayBackup, encoded: Data, repairCorruptFiles: Bool = false,
                             beforeWriting: () -> Void = {}) throws {
        // All fallible photo writes finish before a replayable journal is published.
        let values = try encodedBackupValues(backup, repairCorruptFiles: repairCorruptFiles)
        beforeWriting()
        defaults.set(encoded, forKey: pendingRestoreKey)
        for (key, data) in values { defaults.set(data, forKey: key) }
        isRestoring = true
        categories = Self.normalizedCategories(backup.categories)
        days = backup.days
        deletedDays = backup.deletedDays
        syncConflicts = backup.syncConflicts
        isRestoring = false
        defaults.removeObject(forKey: pendingRestoreKey)
        saveFailure = nil
        removeUnusedPhotos()
        rescheduleNotifications()
        reloadWidgetTimelines()
    }

    private func writeBackup(_ backup: DayBackup) throws {
        for (key, data) in try encodedBackupValues(backup) { defaults.set(data, forKey: key) }
    }

    private func encodedBackupValues(_ backup: DayBackup, repairCorruptFiles: Bool = false) throws -> [(String, Data)] {
        let encoder = JSONEncoder()
        // Photos in active, deleted and retained days all live in the shared file store.
        let photoEncoder = photoFiles?.encoder(repairCorruptFiles: repairCorruptFiles) ?? encoder
        let daysData = try photoEncoder.encode(backup.days)
        let categoriesData = try encoder.encode(backup.categories)
        let deletedData = try photoEncoder.encode(backup.deletedDays)
        let conflictsData = try photoEncoder.encode(backup.syncConflicts)
        return [(storageKey, daysData), (categoriesKey, categoriesData),
                (deletedKey, deletedData), (conflictsKey, conflictsData)]
    }

    func restoreSyncConflict(id: String) throws {
        guard loadError == nil, let conflict = syncConflicts.first(where: { $0.id == id }) else {
            throw DayBackup.BackupError.unreadable
        }
        var backup = DayBackup(days: days, categories: categories, deletedDays: deletedDays,
                               syncConflicts: syncConflicts.filter { $0.id != id })
        switch conflict.record {
        case .day(let day):
            if let index = backup.days.firstIndex(where: { $0.id == day.id }) { backup.days[index] = day }
            else { backup.days.append(day) }
            backup.deletedDays.removeAll { $0.id == day.id }
        case .category(let category):
            if let index = backup.categories.firstIndex(where: { $0.id == category.id }) {
                backup.categories[index] = category
            } else { backup.categories.append(category) }
            for index in backup.days.indices where backup.days[index].categoryID == category.id {
                backup.days[index].categoryLabel = category.name
            }
        }
        try restoreBackup(backup, encoded: nil)
    }

    func discardSyncConflict(id: String) throws {
        guard loadError == nil else { throw DayBackup.BackupError.unreadable }
        let remaining = syncConflicts.filter { $0.id != id }
        defaults.set(try (photoFiles?.encoder() ?? JSONEncoder()).encode(remaining), forKey: conflictsKey)
        syncConflicts = remaining
        removeUnusedPhotos()
    }

    func resetToSamples() {
        guard loadError == nil else { return }
        deletedDays = []
        persistDeletedDays()
        syncConflicts = []
        defaults.removeObject(forKey: conflictsKey)
        categories = CategoryDefinition.system
        days = SampleData.days
    }

    func rescheduleNotifications() {
        // An unreadable library loads as empty, which would cancel every pending reminder.
        guard let settings, loadError == nil else { return }
        // Coalesce rapid edits: cancel any task waiting to run, and chain off the
        // previous one so we never dispatch overlapping syncs that would race on
        // UNUserNotificationCenter (both calls would remove-stale then add-new and
        // could end up with duplicate requests).
        let previous = rescheduleTask
        rescheduleTask?.cancel()
        let snapshot = days
        rescheduleTask = Task {
            await previous?.value
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }
            await NotificationManager.shared.sync(days: snapshot, settings: settings)
        }
    }

    func enableCloudSync() {
        cloudSyncRequested = true
        guard !cloudSyncEnabled, loadError == nil else { return }
        do {
            try keepMigrationBackup()
            syncPreparationFailure = nil
            cloudSyncEnabled = true
            startCloudSync()
        } catch {
            syncPreparationFailure = error
        }
    }

    /// Stops iCloud sync and removes what this device kept for it. The library is untouched.
    func disableCloudSync() {
        cloudSyncRequested = false
        cloudSyncEnabled = false
        syncPreparationFailure = nil
        CloudLibrarySync.shared.stop()
    }

    private func startCloudSync() {
        CloudLibrarySync.shared.start(days: days, categories: categories) { [weak self] update in
            guard let self else { throw DayBackup.BackupError.unreadable }
            try self.applyCloudUpdate(update)
        }
    }

    /// Starts iCloud sync again from an empty checkpoint, after the old one couldn't be read. Local
    /// days stay; the next sync compares each with iCloud, keeping replaced versions in 同步保留版本.
    func resetCloudSync() throws {
        guard cloudSyncEnabled else { return }
        try CloudLibrarySync.shared.resetUnreadableCheckpoint()
        startCloudSync()
    }

    func category(for id: String) -> CategoryDefinition {
        categories.first(where: { $0.id == id }) ?? Self.fallbackCategory
    }

    func category(for day: Day) -> CategoryDefinition {
        category(for: day.categoryID)
    }

    func days(in categoryID: String?, today: Date = Today.date) -> [Day] {
        guard let categoryID else { return sortedDays(days, today: today) }
        // Filter before sort — sort cost grows N log N, so trimming first is cheaper.
        return sortedDays(days.filter { $0.categoryID == categoryID }, today: today)
    }

    func sortedDays(_ source: [Day], today: Date = Today.date) -> [Day] {
        // Decorate-sort-undecorate: compute DayInfo once per day instead of on every
        // comparator call. With N days the sort issues ~N log N comparisons; without
        // memoizing we'd hit DayInfo.compute (which can do a multi-year lunar walk for
        // recurring lunar days) ~2N log N times per sort.
        source
            .map { ($0, DayInfo.compute($0, today: today)) }
            .sorted { lhs, rhs in
                if lhs.0.pinned != rhs.0.pinned { return lhs.0.pinned && !rhs.0.pinned }
                if lhs.1.isPast != rhs.1.isPast { return !lhs.1.isPast }
                return lhs.1.days < rhs.1.days
            }
            .map(\.0)
    }

    func daysByCategory(today: Date = Today.date) -> [String: [Day]] {
        Dictionary(grouping: sortedDays(days, today: today), by: \.categoryID)
    }

    @discardableResult
    func addCategory(name: String, icon: String, colorToken: CategoryColorToken) -> CategoryDefinition {
        guard loadError == nil else { return Self.fallbackCategory }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = CategoryDefinition(
            id: "custom.\(UUID().uuidString)",
            name: cleanName.isEmpty
                ? String(localized: "新分类", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : cleanName,
            icon: cleanIcon.isEmpty ? "tag" : cleanIcon,
            colorToken: colorToken,
            isSystem: false
        )
        categories.append(category)
        return category
    }

    /// False when nothing changed: the category is gone (deleted on another device, say), is a
    /// system category, or couldn't be saved.
    @discardableResult
    func updateCategory(_ category: CategoryDefinition) -> Bool {
        guard loadError == nil else { return false }
        guard let index = categories.firstIndex(where: { $0.id == category.id }),
              !categories[index].isSystem else { return false }
        let cleanName = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanIcon = category.icon.trimmingCharacters(in: .whitespacesAndNewlines)
        var updatedCategories = categories
        updatedCategories[index] = CategoryDefinition(
            id: category.id,
            name: cleanName.isEmpty ? categories[index].name : cleanName,
            icon: cleanIcon.isEmpty ? categories[index].icon : cleanIcon,
            colorToken: category.colorToken,
            isSystem: false
        )
        let label = updatedCategories[index].name
        func stale(_ day: Day) -> Bool { day.categoryID == category.id && day.categoryLabel != label }
        func relabeled(_ day: Day) -> Day {
            guard stale(day) else { return day }
            var updated = day
            updated.categoryLabel = label
            return updated
        }
        let staleConflict = syncConflicts.contains { conflict in
            if case .day(let day) = conflict.record { return stale(day) }
            return false
        }
        guard days.contains(where: stale) || deletedDays.contains(where: { stale($0.day) }) || staleConflict else {
            categories = updatedCategories
            return saveError == nil
        }
        // Copies in 最近删除 and 同步保留版本 take the new name too, as deleteCategory moves them.
        let updatedDeleted = deletedDays.map { DeletedDay(day: relabeled($0.day), deletedAt: $0.deletedAt) }
        let updatedConflicts = syncConflicts.map { conflict in
            guard case .day(let day) = conflict.record else { return conflict }
            var updated = conflict
            updated.record = .day(relabeled(day))
            return updated
        }
        commitChange(days: days.map(relabeled), categories: updatedCategories,
                     deletedDays: updatedDeleted, syncConflicts: updatedConflicts)
        return saveError == nil
    }

    /// False when nothing changed, as for `updateCategory`, or the target is gone too.
    @discardableResult
    func deleteCategory(id: String, migrateTo targetID: String) -> Bool {
        guard loadError == nil else { return false }
        guard let category = categories.first(where: { $0.id == id }),
              !category.isSystem,
              categories.contains(where: { $0.id == targetID && $0.id != id }) else { return false }

        let target = self.category(for: targetID)
        let updatedCategories = categories.filter { $0.id != id }
        func migrated(_ day: Day) -> Day {
            guard day.categoryID == id else { return day }
            var updated = day
            updated.categoryID = target.id
            updated.categoryLabel = target.name
            updated.category = DayCategory(rawValue: target.id) ?? .life
            return updated
        }
        // Copies in 最近删除 and 同步保留版本 move too, or restoring one would bring back a day
        // whose category no longer exists.
        let updatedDeleted = deletedDays.map { DeletedDay(day: migrated($0.day), deletedAt: $0.deletedAt) }
        let updatedConflicts = syncConflicts.map { conflict in
            guard case .day(let day) = conflict.record else { return conflict }
            var updated = conflict
            updated.record = .day(migrated(day))
            return updated
        }
        commitChange(days: days.map(migrated), categories: updatedCategories,
                     deletedDays: updatedDeleted, syncConflicts: updatedConflicts)
        return saveError == nil
    }

    /// Writes several parts of the library at once through the restore journal; `failure` names
    /// the message shown if it can't.
    private func commitChange(days: [Day], categories: [CategoryDefinition],
                              deletedDays: [DeletedDay]? = nil, syncConflicts: [SyncConflict]? = nil,
                              failure: SaveFailure = .categories) {
        do {
            let backup = DayBackup(days: days, categories: categories, deletedDays: deletedDays ?? self.deletedDays,
                                   syncConflicts: syncConflicts ?? self.syncConflicts)
            let encoded = try localBackupData(backup)
            try applyBackup(backup, encoded: encoded)
            saveFailure = nil
            if cloudSyncEnabled { CloudLibrarySync.shared.updateLocal(days: days, categories: categories) }
        } catch {
            saveFailure = failure
        }
    }

    private func normalized(_ day: Day) -> Day {
        var updated = day
        // Cloud days can arrive before their category definition. Keep the reference
        // and label snapshot until the definition arrives; display lookup can fall back.
        if let definition = categories.first(where: { $0.id == day.categoryID }) {
            updated.categoryLabel = definition.name
            updated.category = DayCategory(rawValue: definition.id) ?? .life
        }
        updated.coverFocusX = min(1, max(0, updated.coverFocusX))
        updated.coverFocusY = min(1, max(0, updated.coverFocusY))
        return updated
    }

    private static var fallbackCategory: CategoryDefinition {
        CategoryDefinition.system.first(where: { $0.id == DayCategory.life.rawValue })
            ?? CategoryDefinition(id: DayCategory.life.rawValue, name: DayCategory.life.label,
                                  icon: "sparkles", colorToken: .terracotta, isSystem: true)
    }

    private static func normalizedCategories(_ decoded: [CategoryDefinition]) -> [CategoryDefinition] {
        var result = decoded
        for systemCategory in CategoryDefinition.system where !result.contains(where: { $0.id == systemCategory.id }) {
            result.append(systemCategory)
        }
        return result
    }

    // Legacy KVS has no per-record tombstones. Import only after explicit user action.
    @discardableResult
    func importLegacyCloudData() throws -> Int {
        let legacy = legacyCloudRecords()
        return try importLegacyData(days: legacy.days, categories: legacy.categories)
    }

    /// Whether the legacy iCloud keys still hold a day or category this device has not seen.
    func hasUnseenLegacyCloudData() -> Bool {
        let legacy = legacyCloudRecords()
        return hasUnseenLegacyData(days: legacy.days, categories: legacy.categories)
    }

    func hasUnseenLegacyData(days legacyDays: [Day], categories legacyCategories: [CategoryDefinition]) -> Bool {
        let seen = seenLegacyIDs()
        return legacyDays.contains { !seen.days.contains($0.id) }
            || legacyCategories.contains { !seen.categories.contains($0.id) }
    }

    private func legacyCloudRecords() -> (days: [Day], categories: [CategoryDefinition]) {
        let legacy = ICloudSyncStore.shared
        legacy.refresh()
        let remoteDays: ICloudSyncStore.RemoteValue<[Day]>? = legacy.remoteValue(for: ICloudSyncStore.Key.days)
        let remoteCategories: ICloudSyncStore.RemoteValue<[CategoryDefinition]>? = legacy.remoteValue(for: ICloudSyncStore.Key.categories)
        return (remoteDays?.value ?? [], remoteCategories?.value ?? [])
    }

    private func seenLegacyIDs() -> (days: Set<String>, categories: Set<String>) {
        let premigration = migrationBackupIDs()
        return (Set(defaults.stringArray(forKey: legacyDayIDsKey) ?? []).union(days.map(\.id))
                    .union(deletedDays.map(\.id)).union(premigration.days),
                Set(defaults.stringArray(forKey: legacyCategoryIDsKey) ?? []).union(categories.map(\.id))
                    .union(premigration.categories))
    }

    /// The library before CloudKit already held the legacy records, without an import recording
    /// them, so its IDs stay seen after those records are deleted.
    private func migrationBackupIDs() -> (days: [String], categories: [String]) {
        guard let data = defaults.data(forKey: migrationKey),
              let library = try? JSONDecoder().decode(LibraryIDs.self, from: data) else { return ([], []) }
        return (library.days.map(\.id) + library.deletedDays.map(\.day.id), library.categories.map(\.id))
    }

    /// Reads only record IDs, so photos aren't loaded.
    private struct LibraryIDs: Decodable {
        struct Record: Decodable { let id: String }
        struct Deleted: Decodable { let day: Record }
        let days: [Record]
        let deletedDays: [Deleted]
        let categories: [Record]
    }

    @discardableResult
    func importLegacyData(days legacyDays: [Day], categories legacyCategories: [CategoryDefinition]) throws -> Int {
        guard loadError == nil else { throw DayBackup.BackupError.unreadable }
        try DayBackup(days: legacyDays, categories: legacyCategories, deletedDays: []).validate()
        let (seenDays, seenCategories) = seenLegacyIDs()
        let additions = legacyDays.filter { !seenDays.contains($0.id) }
        let categoryAdditions = legacyCategories.filter { !seenCategories.contains($0.id) }
        if !additions.isEmpty || !categoryAdditions.isEmpty {
            let backup = DayBackup(days: days + additions, categories: categories + categoryAdditions,
                                   deletedDays: deletedDays, syncConflicts: syncConflicts)
            let encoded = try localBackupData(backup)
            let recovery = try localBackupData(currentBackup)
            try keepMigrationBackup()
            try applyBackup(backup, encoded: encoded) { [defaults, recoveryKey] in
                defaults.set(recovery, forKey: recoveryKey)
            }
            if cloudSyncEnabled { CloudLibrarySync.shared.updateLocal(days: days, categories: categories) }
        }
        defaults.set(Array(seenDays.union(legacyDays.map(\.id))), forKey: legacyDayIDsKey)
        defaults.set(Array(seenCategories.union(legacyCategories.map(\.id))), forKey: legacyCategoryIDsKey)
        return additions.count
    }

    func applyCloudUpdate(_ update: CloudLibraryUpdate) throws {
        guard loadError == nil else { throw DayBackup.BackupError.unreadable }
        try DayBackup(days: update.upsertedDays, categories: update.upsertedCategories, deletedDays: []).validate()
        for day in update.recoveryDays { try DayBackup.validateDays([day]) }
        for category in update.recoveryCategories {
            try DayBackup(days: [], categories: [category], deletedDays: []).validate()
        }
        var nextDays = days.filter { !update.deletedDayIDs.contains($0.id) }
        var nextCategories = categories.filter { $0.isSystem || !update.deletedCategoryIDs.contains($0.id) }
        for day in update.upsertedDays {
            if let index = nextDays.firstIndex(where: { $0.id == day.id }) { nextDays[index] = day }
            else { nextDays.append(day) }
        }
        for category in update.upsertedCategories {
            if let index = nextCategories.firstIndex(where: { $0.id == category.id }) { nextCategories[index] = category }
            else { nextCategories.append(category) }
        }
        nextCategories = Self.normalizedCategories(nextCategories)
        var nextDeleted = deletedDays.filter { entry in !nextDays.contains(where: { $0.id == entry.id }) }
        for day in days where update.deletedDayIDs.contains(day.id) && !nextDeleted.contains(where: { $0.id == day.id }) {
            nextDeleted.append(DeletedDay(day: day, deletedAt: .now))
        }
        var nextConflicts = syncConflicts
        var conflictRecords = update.recoveryDays.map(CloudLibraryRecord.day)
            + update.recoveryCategories.map(CloudLibraryRecord.category)
        // Even an equal value can be queued before a later local edit. Retain every replaced
        // version for the retention period.
        conflictRecords += days.filter { day in
            nextDays.first(where: { $0.id == day.id }) != day
        }.map(CloudLibraryRecord.day)
        conflictRecords += categories.filter { category in
            nextCategories.first(where: { $0.id == category.id }) != category
        }.map(CloudLibraryRecord.category)
        for record in conflictRecords where !nextConflicts.contains(where: { $0.record == record }) {
            nextConflicts.append(SyncConflict(record: record))
        }
        nextDeleted = Self.unexpired(nextDeleted)
        nextConflicts = Self.unexpired(nextConflicts)
        let backup = DayBackup(days: nextDays, categories: nextCategories, deletedDays: nextDeleted,
                               syncConflicts: nextConflicts)
        guard nextDays != days || nextCategories != categories || nextDeleted != deletedDays
                || !update.recoveryDays.isEmpty || !update.recoveryCategories.isEmpty else { return }
        var recoveryDays = days
        var recoveryCategories = categories
        for day in update.recoveryDays.reversed() {
            // A retried delivery may follow a newer local edit. Preserve that edit;
            // replayed remote content can use the original conflict recovery value.
            guard days.first(where: { $0.id == day.id }) == nextDays.first(where: { $0.id == day.id }) else { continue }
            recoveryDays.removeAll { $0.id == day.id }
            recoveryDays.append(day)
        }
        for category in update.recoveryCategories.reversed() {
            guard categories.first(where: { $0.id == category.id }) == nextCategories.first(where: { $0.id == category.id }) else { continue }
            recoveryCategories.removeAll { $0.id == category.id }
            recoveryCategories.append(category)
        }
        let recovery = DayBackup(days: recoveryDays, categories: recoveryCategories,
                                 deletedDays: deletedDays.filter { entry in !recoveryDays.contains(where: { $0.id == entry.id }) },
                                 syncConflicts: syncConflicts)
        let recoveryData = try localBackupData(recovery)
        let encoded = try localBackupData(backup)
        try applyBackup(backup, encoded: encoded) { [defaults, recoveryKey] in
            defaults.set(recoveryData, forKey: recoveryKey)
        }
    }
}
