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
            save()
            rescheduleNotifications()
            reloadWidgetTimelines()
        }
    }
    var categories: [CategoryDefinition] {
        didSet {
            guard !isRestoring else { return }
            saveCategories()
        }
    }
    private(set) var deletedDays: [DeletedDay] = []
    private(set) var loadError: String?
    private(set) var syncPreparationError: String?

    private let storageKey = "days.v1"
    private let categoriesKey = "categories.v1"
    private let deletedKey = "deletedDays.v1"
    private let recoveryKey = "recoveryBackup.v1"
    private let migrationKey = "preCloudKitBackup.v1"
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

    init(defaults: UserDefaults = SharedStorage.defaults) {
        self.defaults = defaults
        self.days = []
        self.categories = CategoryDefinition.system
        isRestoring = true
        defer { isRestoring = false }
        do {
            // Replay an interrupted restore before exposing any partially restored data.
            if let pending = defaults.data(forKey: pendingRestoreKey) {
                let backup = try DayBackup.decode(pending)
                try writeBackup(backup)
                defaults.removeObject(forKey: pendingRestoreKey)
            }
            if let data = defaults.data(forKey: storageKey) {
                let decoded = try JSONDecoder().decode([Day].self, from: data)
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
            if let data = defaults.data(forKey: deletedKey) {
                self.deletedDays = try JSONDecoder().decode([DeletedDay].self, from: data)
                    .filter { entry in !days.contains(where: { $0.id == entry.id }) }
            }
            try DayBackup(days: days, categories: categories, deletedDays: deletedDays).validate()
        } catch {
            loadError = "本机数据未能完整读取，原始数据已保留。请先导出原始数据，或从备份恢复。"
        }
    }

    func save() {
        persist(days, storageKey: storageKey)
    }

    func saveCategories() {
        persist(categories, storageKey: categoriesKey)
    }

    private func persist<Value: Encodable>(_ value: Value, storageKey: String) {
        guard loadError == nil else { return }
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: storageKey)

        if cloudSyncEnabled {
            CloudLibrarySync.shared.updateLocal(days: days, categories: categories)
        }
    }

    private func reloadWidgetTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    func add(_ day: Day) {
        guard loadError == nil, !days.contains(where: { $0.id == day.id }) else { return }
        // Restore the active copy before removing its recoverable deleted copy.
        days.insert(normalized(day), at: 0)
        deletedDays.removeAll { $0.id == day.id }
        persistDeletedDays()
    }
    func update(_ day: Day) {
        guard loadError == nil else { return }
        if let i = days.firstIndex(where: { $0.id == day.id }) { days[i] = normalized(day) }
    }
    func delete(_ day: Day) {
        guard loadError == nil, let current = days.first(where: { $0.id == day.id }) else { return }
        let id = day.id
        deletedDays.removeAll { $0.id == id }
        deletedDays.insert(DeletedDay(day: current, deletedAt: .now), at: 0)
        persistDeletedDays()
        days.removeAll { $0.id == id }
        Task { await NotificationManager.shared.cancel(dayId: id) }
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

    private func persistDeletedDays() {
        guard let data = try? JSONEncoder().encode(deletedDays) else { return }
        defaults.set(data, forKey: deletedKey)
    }

    var hasRecoveryBackup: Bool { defaults.data(forKey: recoveryKey) != nil }
    var hasMigrationBackup: Bool { defaults.data(forKey: migrationKey) != nil }

    func exportMigrationBackup() throws -> Data {
        guard let data = defaults.data(forKey: migrationKey) else { throw DayBackup.BackupError.unreadable }
        return data
    }

    func exportBackup() throws -> Data {
        guard loadError == nil else { throw DayBackup.BackupError.unreadable }
        return try DayBackup(days: days, categories: categories, deletedDays: deletedDays).encoded()
    }

    func exportOriginalData() throws -> Data {
        let keys = [storageKey, categoriesKey, deletedKey, pendingRestoreKey, recoveryKey, migrationKey, "unreadableData.v1"]
        let original = Dictionary(uniqueKeysWithValues: keys.compactMap { key in
            defaults.data(forKey: key).map { (key, $0) }
        })
        return try JSONEncoder().encode(original)
    }

    func restoreBackup(_ backup: DayBackup) throws {
        let data = try backup.encoded()
        if loadError == nil {
            try keepRecoveryBackup()
        } else {
            defaults.set(try exportOriginalData(), forKey: "unreadableData.v1")
        }
        try applyBackup(backup, encoded: data)
        loadError = nil
        if cloudSyncEnabled {
            CloudLibrarySync.shared.updateLocal(days: days, categories: categories)
        } else if cloudSyncRequested {
            enableCloudSync()
        }
    }

    func restorePreviousBackup() throws {
        guard let data = defaults.data(forKey: recoveryKey) else { throw DayBackup.BackupError.unreadable }
        try restoreBackup(DayBackup.decode(data))
    }

    private func keepRecoveryBackup() throws {
        defaults.set(try exportBackup(), forKey: recoveryKey)
    }

    private func keepMigrationBackup() throws {
        if !hasMigrationBackup { defaults.set(try exportBackup(), forKey: migrationKey) }
    }

    private func applyBackup(_ backup: DayBackup, encoded: Data) throws {
        defaults.set(encoded, forKey: pendingRestoreKey)
        try writeBackup(backup)
        isRestoring = true
        categories = Self.normalizedCategories(backup.categories)
        days = backup.days
        deletedDays = backup.deletedDays
        isRestoring = false
        defaults.removeObject(forKey: pendingRestoreKey)
        rescheduleNotifications()
        reloadWidgetTimelines()
    }

    private func writeBackup(_ backup: DayBackup) throws {
        let encoder = JSONEncoder()
        let daysData = try encoder.encode(backup.days)
        let categoriesData = try encoder.encode(backup.categories)
        let deletedData = try encoder.encode(backup.deletedDays)
        defaults.set(daysData, forKey: storageKey)
        defaults.set(categoriesData, forKey: categoriesKey)
        defaults.set(deletedData, forKey: deletedKey)
    }

    /// Nearest upcoming (future or today) within `within` days.
    func nearestUpcoming(within: Int = 100) -> Day? {
        days
            .compactMap { day -> (Day, Int)? in
                let info = DayInfo.compute(day)
                return (info.isPast || info.days > within) ? nil : (day, info.days)
            }
            .min { $0.1 < $1.1 }?
            .0
    }

    func resetToSamples() {
        guard loadError == nil else { return }
        deletedDays = []
        persistDeletedDays()
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
            syncPreparationError = "迁移前备份未完成，同步尚未开启；本机日子仍可使用。\(error.localizedDescription)"
        }
    }

    func category(for id: String) -> CategoryDefinition {
        categories.first(where: { $0.id == id }) ?? Self.fallbackCategory
    }

    func category(for day: Day) -> CategoryDefinition {
        category(for: day.categoryID)
    }

    func days(in categoryID: String?) -> [Day] {
        guard let categoryID else { return sortedDays(days) }
        // Filter before sort — sort cost grows N log N, so trimming first is cheaper.
        return sortedDays(days.filter { $0.categoryID == categoryID })
    }

    func sortedDays(_ source: [Day]) -> [Day] {
        // Decorate-sort-undecorate: compute DayInfo once per day instead of on every
        // comparator call. With N days the sort issues ~N log N comparisons; without
        // memoizing we'd hit DayInfo.compute (which can do a multi-year lunar walk for
        // recurring lunar days) ~2N log N times per sort.
        source
            .map { ($0, DayInfo.compute($0)) }
            .sorted { lhs, rhs in
                if lhs.0.pinned != rhs.0.pinned { return lhs.0.pinned && !rhs.0.pinned }
                if lhs.1.isPast != rhs.1.isPast { return !lhs.1.isPast }
                return lhs.1.days < rhs.1.days
            }
            .map(\.0)
    }

    @discardableResult
    func addCategory(name: String, icon: String, colorToken: CategoryColorToken) -> CategoryDefinition {
        guard loadError == nil else { return Self.fallbackCategory }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = CategoryDefinition(
            id: "custom.\(UUID().uuidString)",
            name: cleanName.isEmpty ? "新分类" : cleanName,
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
        categories[index] = CategoryDefinition(
            id: category.id,
            name: cleanName.isEmpty ? categories[index].name : cleanName,
            icon: cleanIcon.isEmpty ? categories[index].icon : cleanIcon,
            colorToken: category.colorToken,
            isSystem: false
        )
        let label = categories[index].name
        guard days.contains(where: { $0.categoryID == category.id && $0.categoryLabel != label }) else { return }
        days = days.map { day in
            guard day.categoryID == category.id else { return day }
            var updated = day
            updated.categoryLabel = label
            return updated
        }
    }

    func deleteCategory(id: String, migrateTo targetID: String) {
        guard loadError == nil else { return }
        guard let category = categories.first(where: { $0.id == id }),
              !category.isSystem,
              categories.contains(where: { $0.id == targetID && $0.id != id }) else { return }

        let target = self.category(for: targetID)
        categories.removeAll { $0.id == id }
        days = days.map { day in
            guard day.categoryID == id else { return day }
            var updated = day
            updated.categoryID = target.id
            updated.categoryLabel = target.name
            updated.category = DayCategory(rawValue: target.id) ?? .life
            return updated
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
            let backup = DayBackup(days: days + additions, categories: categories + categoryAdditions, deletedDays: deletedDays)
            let encoded = try backup.encoded()
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
        let backup = DayBackup(days: nextDays, categories: nextCategories, deletedDays: nextDeleted)
        let encoded = try backup.encoded()
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
                                 deletedDays: deletedDays.filter { entry in !recoveryDays.contains(where: { $0.id == entry.id }) })
        defaults.set(try recovery.encoded(), forKey: recoveryKey)
        try applyBackup(backup, encoded: encoded)
    }
}

@MainActor
@Observable
final class AppSettings {
    // Stored, UserDefaults-backed (replaces @AppStorage, which @Observable can't
    // observe). Same keys & standard store as before so existing settings carry over.
    var hasOnboarded: Bool { didSet { persist(hasOnboarded, "hasOnboarded"); scheduleCloudPush() } }
    var notifPre7: Bool { didSet { persist(notifPre7, "notif.pre7"); scheduleCloudPush() } }
    var notifPre3: Bool { didSet { persist(notifPre3, "notif.pre3"); scheduleCloudPush() } }
    var notifPre1: Bool { didSet { persist(notifPre1, "notif.pre1"); scheduleCloudPush() } }
    var notifDay0: Bool { didSet { persist(notifDay0, "notif.day0"); scheduleCloudPush() } }
    var memoryEnabled: Bool { didSet { persist(memoryEnabled, "notif.memory"); scheduleCloudPush() } }
    var momentsEnabled: Bool { didSet { persist(momentsEnabled, "notif.moments"); scheduleCloudPush() } }
    var quietHours: Bool { didSet { persist(quietHours, "notif.quiet"); scheduleCloudPush() } }
    var notificationHour: Int { didSet { persist(notificationHour, "notif.hour"); scheduleCloudPush() } }
    var notificationMinute: Int { didSet { persist(notificationMinute, "notif.minute"); scheduleCloudPush() } }

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let cloud = ICloudSyncStore.shared
    @ObservationIgnored private var cloudSyncEnabled = false
    @ObservationIgnored private var cloudChangeToken: UUID?
    @ObservationIgnored private var pushTask: Task<Void, Never>?
    @ObservationIgnored private var isApplyingCloudChange = false
    @ObservationIgnored private var onCloudSettingsApplied: (() -> Void)?

    init() {
        let d = UserDefaults.standard
        hasOnboarded = d.object(forKey: "hasOnboarded") as? Bool ?? false
        notifPre7 = d.object(forKey: "notif.pre7") as? Bool ?? true
        notifPre3 = d.object(forKey: "notif.pre3") as? Bool ?? true
        notifPre1 = d.object(forKey: "notif.pre1") as? Bool ?? false
        notifDay0 = d.object(forKey: "notif.day0") as? Bool ?? true
        memoryEnabled = d.object(forKey: "notif.memory") as? Bool ?? false
        momentsEnabled = d.object(forKey: "notif.moments") as? Bool ?? false
        quietHours = d.object(forKey: "notif.quiet") as? Bool ?? true
        notificationHour = d.object(forKey: "notif.hour") as? Int ?? 9
        notificationMinute = d.object(forKey: "notif.minute") as? Int ?? 0
    }

    private func persist(_ value: Bool, _ key: String) { defaults.set(value, forKey: key) }
    private func persist(_ value: Int, _ key: String) { defaults.set(value, forKey: key) }

    func enableCloudSync(onRemoteApply: @escaping () -> Void = {}) {
        onCloudSettingsApplied = onRemoteApply
        guard !cloudSyncEnabled else { return }
        cloudSyncEnabled = true
        cloudChangeToken = cloud.addChangeHandler { [weak self] changedKeys in
            guard changedKeys == nil || changedKeys?.contains(ICloudSyncStore.Key.settings) == true else { return }
            self?.pullSettingsIfNewer()
        }
        reconcileSettingsWithCloud()
    }

    /// Debounced iCloud push, triggered from each setting's didSet (replaces the old
    /// Combine objectWillChange.debounce). Coalesces rapid toggles into one KVS write.
    private func scheduleCloudPush() {
        guard !isApplyingCloudChange else { return }
        let updatedAt = Date.now.timeIntervalSinceReferenceDate
        cloud.noteLocalWrite(for: ICloudSyncStore.Key.settings, updatedAt: updatedAt)
        guard cloudSyncEnabled else { return }
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }
            self.pushSettingsToCloud(updatedAt: updatedAt)
        }
    }

    private var snapshot: AppSettingsSnapshot {
        AppSettingsSnapshot(settings: self)
    }

    private func reconcileSettingsWithCloud() {
        cloud.reconcile(snapshot, for: ICloudSyncStore.Key.settings, pull: pullSettingsIfNewer)
    }

    @discardableResult
    private func pullSettingsIfNewer() -> Bool {
        guard let remote: ICloudSyncStore.RemoteValue<AppSettingsSnapshot> = cloud.remoteValue(for: ICloudSyncStore.Key.settings) else {
            return false
        }
        return applyRemoteSettingsIfNewer(remote)
    }

    @discardableResult
    func applyRemoteSettingsIfNewer(_ remote: ICloudSyncStore.RemoteValue<AppSettingsSnapshot>) -> Bool {
        guard remote.updatedAt > cloud.localTimestamp(for: ICloudSyncStore.Key.settings) + 0.001 else {
            return false
        }

        pushTask?.cancel()
        pushTask = nil
        isApplyingCloudChange = true
        apply(remote.value)
        cloud.noteLocalWrite(for: ICloudSyncStore.Key.settings, updatedAt: remote.updatedAt)
        isApplyingCloudChange = false
        onCloudSettingsApplied?()
        return true
    }

    private func pushSettingsToCloud(updatedAt: TimeInterval) {
        cloud.push(snapshot, for: ICloudSyncStore.Key.settings, updatedAt: updatedAt)
    }

    private func apply(_ snapshot: AppSettingsSnapshot) {
        hasOnboarded = snapshot.hasOnboarded
        notifPre7 = snapshot.notifPre7
        notifPre3 = snapshot.notifPre3
        notifPre1 = snapshot.notifPre1
        notifDay0 = snapshot.notifDay0
        memoryEnabled = snapshot.memoryEnabled
        momentsEnabled = snapshot.momentsEnabled
        quietHours = snapshot.quietHours
        notificationHour = min(23, max(0, snapshot.notificationHour))
        notificationMinute = min(59, max(0, snapshot.notificationMinute))
    }
}

struct AppSettingsSnapshot: Codable, Equatable {
    var hasOnboarded: Bool
    var notifPre7: Bool
    var notifPre3: Bool
    var notifPre1: Bool
    var notifDay0: Bool
    var memoryEnabled: Bool
    var momentsEnabled: Bool
    var quietHours: Bool
    var notificationHour: Int
    var notificationMinute: Int

    @MainActor
    init(settings: AppSettings) {
        hasOnboarded = settings.hasOnboarded
        notifPre7 = settings.notifPre7
        notifPre3 = settings.notifPre3
        notifPre1 = settings.notifPre1
        notifDay0 = settings.notifDay0
        memoryEnabled = settings.memoryEnabled
        momentsEnabled = settings.momentsEnabled
        quietHours = settings.quietHours
        notificationHour = settings.notificationHour
        notificationMinute = settings.notificationMinute
    }
}
