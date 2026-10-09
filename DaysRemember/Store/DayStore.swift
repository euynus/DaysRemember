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
        }
    }
    private(set) var deletedDays: [DeletedDay] = []
    /// The most recent deletion, offered for undo until dismissed.
    private(set) var lastDeleted: DeletedDay?
    private(set) var syncConflicts: [SyncConflict] = []
    private(set) var loadError: String?
    private(set) var saveError: String?
    private(set) var syncPreparationError: String?

    private let storageKey: String
    private let photoFiles: PhotoFileStore?
    private let categoriesKey = "categories.v1"
    private let deletedKey = "deletedDays.v1"
    private let conflictsKey = "syncConflicts.v1"
    private let recoveryKey = "recoveryBackup.v1"
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
    private var rescheduleTask: Task<Void, Never>?
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
            if let data = defaults.data(forKey: deletedKey) {
                self.deletedDays = Self.unexpired(try (photoFiles?.decoder() ?? JSONDecoder())
                    .decode([DeletedDay].self, from: data)
                    .filter { entry in !days.contains(where: { $0.id == entry.id }) })
            }
            if let data = defaults.data(forKey: conflictsKey) {
                self.syncConflicts = Self.unexpired(try (photoFiles?.decoder() ?? JSONDecoder())
                    .decode([SyncConflict].self, from: data))
            }
            try DayBackup(days: days, categories: categories, deletedDays: deletedDays,
                          syncConflicts: syncConflicts).validate()
        } catch {
            loadError = String(localized: "本机数据未能完整读取，原始数据已保留。请先导出原始数据，或从备份恢复。",
                               bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
    }

    @discardableResult
    func save() -> Bool {
        persist(days, storageKey: storageKey)
    }

    @discardableResult
    func saveCategories() -> Bool {
        persist(categories, storageKey: categoriesKey)
    }

    private func persist<Value: Encodable>(_ value: Value, storageKey: String) -> Bool {
        guard loadError == nil else { return false }
        do {
            let data = try (photoFiles?.encoder() ?? JSONEncoder()).encode(value)
            defaults.set(data, forKey: storageKey)
            saveError = nil
            if cloudSyncEnabled {
                CloudLibrarySync.shared.updateLocal(days: days, categories: categories)
            }
            return true
        } catch {
            saveError = String(localized: "本机数据未能保存，之前的数据已保留。请检查可用空间，或从备份恢复。",
                               bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            return false
        }
    }

    func dismissSaveError() {
        saveError = nil
    }

    private func reloadWidgetTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    @discardableResult
    func add(_ day: Day) -> Bool {
        saveError = nil
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
        saveError = nil
        guard loadError == nil, let i = days.firstIndex(where: { $0.id == day.id }) else { return false }
        days[i] = normalized(day)
        return saveError == nil
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
            saveError = String(localized: "本机数据未能保存，之前的数据已保留。请检查可用空间，或从备份恢复。",
                               bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            return
        }
        days.removeAll { $0.id == id }
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

    func permanentlyDeleteDay(id: String) {
        guard loadError == nil else { return }
        deletedDays.removeAll { $0.id == id }
        persistDeletedDays()
    }

    @discardableResult
    private func persistDeletedDays() -> Bool {
        guard let data = try? (photoFiles?.encoder() ?? JSONEncoder()).encode(deletedDays) else { return false }
        defaults.set(data, forKey: deletedKey)
        return true
    }

    /// Recently deleted days and replaced sync versions stay recoverable for 30 days.
    static let retention: TimeInterval = 30 * 24 * 60 * 60

    private static func unexpired(_ entries: [DeletedDay], now: Date = .now) -> [DeletedDay] {
        entries.filter { now.timeIntervalSince($0.deletedAt) < retention }
    }

    private static func unexpired(_ entries: [SyncConflict], now: Date = .now) -> [SyncConflict] {
        entries.filter { now.timeIntervalSince($0.createdAt) < retention }
    }

    var hasRecoveryBackup: Bool { defaults.data(forKey: recoveryKey) != nil }
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

    func exportOriginalData() throws -> Data {
        let keys = Set([storageKey, SharedStorage.legacyDaysKey, categoriesKey, deletedKey, conflictsKey, pendingRestoreKey,
                    recoveryKey, migrationKey, "unreadableData.v1"])
        var original = Dictionary(uniqueKeysWithValues: keys.compactMap { key in
            defaults.data(forKey: key).map { (key, $0) }
        })
        if let photoFiles { original.merge(try photoFiles.originalFiles()) { _, current in current } }
        return try JSONEncoder().encode(original)
    }

    func restoreBackup(_ backup: DayBackup) throws {
        try restoreBackup(backup, encoded: backup.encoded())
    }

    private func restoreBackup(_ backup: DayBackup, encoded: Data?) throws {
        try backup.validate()
        if loadError == nil {
            do {
                try keepRecoveryBackup()
            } catch {
                // Damaged photo files must not prevent an explicit repair or lose their original bytes.
                defaults.set(try exportOriginalData(), forKey: "unreadableData.v1")
            }
        } else {
            defaults.set(try exportOriginalData(), forKey: "unreadableData.v1")
        }
        let data = try encoded ?? localBackupData(backup, repairCorruptFiles: true)
        try applyBackup(backup, encoded: data, repairCorruptFiles: true)
        loadError = nil
        saveError = nil
        if cloudSyncEnabled {
            CloudLibrarySync.shared.updateLocal(days: days, categories: categories)
        } else if cloudSyncRequested {
            enableCloudSync()
        }
    }

    func restorePreviousBackup() throws {
        guard let data = defaults.data(forKey: recoveryKey) else { throw DayBackup.BackupError.unreadable }
        try restoreBackup(decodeLocalBackup(data), encoded: nil)
    }

    private func keepRecoveryBackup() throws {
        defaults.set(try localBackupData(currentBackup), forKey: recoveryKey)
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

    private func applyBackup(_ backup: DayBackup, encoded: Data, repairCorruptFiles: Bool = false) throws {
        // All fallible photo writes finish before a replayable journal is published.
        let values = try encodedBackupValues(backup, repairCorruptFiles: repairCorruptFiles)
        defaults.set(encoded, forKey: pendingRestoreKey)
        for (key, data) in values { defaults.set(data, forKey: key) }
        isRestoring = true
        categories = Self.normalizedCategories(backup.categories)
        days = backup.days
        deletedDays = backup.deletedDays
        syncConflicts = backup.syncConflicts
        isRestoring = false
        defaults.removeObject(forKey: pendingRestoreKey)
        saveError = nil
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
    }

    /// Nearest upcoming (future or today) within `within` days.
    func nearestUpcoming(within: Int = 100, today: Date = Today.date) -> Day? {
        days
            .compactMap { day -> (Day, Int)? in
                let info = DayInfo.compute(day, today: today)
                return (info.isPast || info.days > within) ? nil : (day, info.days)
            }
            .min { $0.1 < $1.1 }?
            .0
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
        guard let settings else { return }
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
            syncPreparationError = nil
            cloudSyncEnabled = true
            CloudLibrarySync.shared.start(days: days, categories: categories) { [weak self] update in
                guard let self else { throw DayBackup.BackupError.unreadable }
                try self.applyCloudUpdate(update)
            }
        } catch {
            syncPreparationError = String(localized: "迁移前备份未完成，同步尚未开启；本机日子仍可使用。\(error.localizedDescription)",
                                          bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
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

    func updateCategory(_ category: CategoryDefinition) {
        guard loadError == nil else { return }
        guard let index = categories.firstIndex(where: { $0.id == category.id }),
              !categories[index].isSystem else { return }
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
        guard days.contains(where: { $0.categoryID == category.id && $0.categoryLabel != label }) else {
            categories = updatedCategories
            return
        }
        let updatedDays = days.map { day in
            guard day.categoryID == category.id else { return day }
            var updated = day
            updated.categoryLabel = label
            return updated
        }
        commitCategoryChange(days: updatedDays, categories: updatedCategories)
    }

    func deleteCategory(id: String, migrateTo targetID: String) {
        guard loadError == nil else { return }
        guard let category = categories.first(where: { $0.id == id }),
              !category.isSystem,
              categories.contains(where: { $0.id == targetID && $0.id != id }) else { return }

        let target = self.category(for: targetID)
        let updatedCategories = categories.filter { $0.id != id }
        let updatedDays = days.map { day in
            guard day.categoryID == id else { return day }
            var updated = day
            updated.categoryID = target.id
            updated.categoryLabel = target.name
            updated.category = DayCategory(rawValue: target.id) ?? .life
            return updated
        }
        commitCategoryChange(days: updatedDays, categories: updatedCategories)
    }

    private func commitCategoryChange(days: [Day], categories: [CategoryDefinition]) {
        do {
            let backup = DayBackup(days: days, categories: categories, deletedDays: deletedDays,
                                   syncConflicts: syncConflicts)
            let encoded = try localBackupData(backup)
            try applyBackup(backup, encoded: encoded)
            saveError = nil
            if cloudSyncEnabled { CloudLibrarySync.shared.updateLocal(days: days, categories: categories) }
        } catch {
            saveError = String(localized: "分类更改未能保存，之前的数据已保留。请检查可用空间，或从备份恢复。",
                               bundle: AppLocalization.bundle, locale: AppLocalization.locale)
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
        let legacy = ICloudSyncStore.shared
        legacy.refresh()
        let remoteDays: ICloudSyncStore.RemoteValue<[Day]>? = legacy.remoteValue(for: ICloudSyncStore.Key.days)
        let remoteCategories: ICloudSyncStore.RemoteValue<[CategoryDefinition]>? = legacy.remoteValue(for: ICloudSyncStore.Key.categories)
        return try importLegacyData(days: remoteDays?.value ?? [], categories: remoteCategories?.value ?? [])
    }

    @discardableResult
    func importLegacyData(days legacyDays: [Day], categories legacyCategories: [CategoryDefinition]) throws -> Int {
        guard loadError == nil else { throw DayBackup.BackupError.unreadable }
        try DayBackup(days: legacyDays, categories: legacyCategories, deletedDays: []).validate()
        let seenDays = Set(defaults.stringArray(forKey: legacyDayIDsKey) ?? [])
            .union(days.map(\.id)).union(deletedDays.map(\.id))
        let seenCategories = Set(defaults.stringArray(forKey: legacyCategoryIDsKey) ?? []).union(categories.map(\.id))
        let additions = legacyDays.filter { !seenDays.contains($0.id) }
        let categoryAdditions = legacyCategories.filter { !seenCategories.contains($0.id) }
        if !additions.isEmpty || !categoryAdditions.isEmpty {
            let backup = DayBackup(days: days + additions, categories: categories + categoryAdditions,
                                   deletedDays: deletedDays, syncConflicts: syncConflicts)
            let encoded = try localBackupData(backup)
            try keepMigrationBackup()
            try keepRecoveryBackup()
            try applyBackup(backup, encoded: encoded)
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
        defaults.set(recoveryData, forKey: recoveryKey)
        try applyBackup(backup, encoded: encoded)
    }
}
