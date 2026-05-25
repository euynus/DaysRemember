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
            save()
            rescheduleNotifications()
            reloadWidgetTimelines()
        }
    }
    var categories: [CategoryDefinition] {
        didSet {
            saveCategories()
        }
    }

    private let storageKey = "days.v1"
    private let categoriesKey = "categories.v1"
    private let cloud = ICloudSyncStore.shared
    private var cloudSyncEnabled = false
    private var cloudChangeToken: UUID?
    /// Non-nil while a remote envelope is being written into `days`/`categories`. Acts
    /// as both the "skip the push-back" guard and the source of the timestamp to mirror.
    private var cloudApplyContext: (key: String, updatedAt: TimeInterval)?
    /// Debounce/serialize handle for `NotificationManager.sync`.
    private var rescheduleTask: Task<Void, Never>?
    /// Set after init so we can wire the notification scheduler without a circular dependency.
    var settings: AppSettings? {
        didSet { rescheduleNotifications() }
    }

    init() {
        if let data = SharedStorage.defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Day].self, from: data) {
            self.days = decoded
        } else {
            self.days = SampleData.days
        }

        if let data = SharedStorage.defaults.data(forKey: categoriesKey),
           let decoded = try? JSONDecoder().decode([CategoryDefinition].self, from: data) {
            self.categories = Self.normalizedCategories(decoded)
        } else {
            self.categories = CategoryDefinition.system
        }
    }

    func save() {
        persist(days, storageKey: storageKey, cloudKey: ICloudSyncStore.Key.days)
    }

    func saveCategories() {
        persist(categories, storageKey: categoriesKey, cloudKey: ICloudSyncStore.Key.categories)
    }

    /// Encode `value` to shared `UserDefaults` under `storageKey`. When this run is the
    /// `didSet` echo of an in-flight cloud apply, mirror the remote timestamp; otherwise
    /// record a fresh local write and (if enabled) push the new value to KVS.
    private func persist<Value: Codable>(_ value: Value, storageKey: String, cloudKey: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        SharedStorage.defaults.set(data, forKey: storageKey)

        if let context = cloudApplyContext {
            if context.key == cloudKey {
                cloud.noteLocalWrite(for: cloudKey, updatedAt: context.updatedAt)
            }
            return
        }

        let updatedAt = Date().timeIntervalSinceReferenceDate
        cloud.noteLocalWrite(for: cloudKey, updatedAt: updatedAt)
        if cloudSyncEnabled {
            cloud.push(value, for: cloudKey, updatedAt: updatedAt)
        }
    }

    private func reloadWidgetTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    func add(_ day: Day) { days.insert(normalized(day), at: 0) }
    func update(_ day: Day) {
        if let i = days.firstIndex(where: { $0.id == day.id }) { days[i] = normalized(day) }
    }
    func delete(_ day: Day) {
        let id = day.id
        days.removeAll { $0.id == id }
        Task { await NotificationManager.shared.cancel(dayId: id) }
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
        guard !cloudSyncEnabled else { return }
        cloudSyncEnabled = true
        cloudChangeToken = cloud.addChangeHandler { [weak self] changedKeys in
            self?.handleCloudChange(changedKeys)
        }
        reconcileWithCloud()
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
        days = days.map { day in
            guard day.categoryID == category.id else { return day }
            var updated = day
            updated.categoryLabel = categories[index].name
            return updated
        }
    }

    func deleteCategory(id: String, migrateTo targetID: String) {
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
        let definition = category(for: day.categoryID)
        var updated = day
        updated.categoryID = definition.id
        updated.categoryLabel = definition.name
        updated.category = DayCategory(rawValue: definition.id) ?? .life
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

    private func handleCloudChange(_ changedKeys: Set<String>?) {
        if changedKeys == nil || changedKeys?.contains(ICloudSyncStore.Key.categories) == true {
            pullCategoriesIfNewer()
        }
        if changedKeys == nil || changedKeys?.contains(ICloudSyncStore.Key.days) == true {
            pullDaysIfNewer()
        }
    }

    private func reconcileWithCloud() {
        reconcileCategoriesWithCloud()
        reconcileDaysWithCloud()
    }

    private func reconcileDaysWithCloud() {
        cloud.reconcile(days, for: ICloudSyncStore.Key.days, pull: pullDaysIfNewer)
    }

    private func reconcileCategoriesWithCloud() {
        cloud.reconcile(categories, for: ICloudSyncStore.Key.categories, pull: pullCategoriesIfNewer)
    }

    @discardableResult
    private func pullDaysIfNewer() -> Bool {
        pullIfNewer(cloudKey: ICloudSyncStore.Key.days) { (remote: [Day]) in
            days = remote.map(normalized)
        }
    }

    @discardableResult
    private func pullCategoriesIfNewer() -> Bool {
        pullIfNewer(cloudKey: ICloudSyncStore.Key.categories) { (remote: [CategoryDefinition]) in
            categories = Self.normalizedCategories(remote)
            days = days.map(normalized)
        }
    }

    /// Apply the remote value through `apply` if its timestamp beats the local mirror.
    /// `apply` runs inside `applyCloudChange` so the resulting `didSet`s skip pushing back.
    @discardableResult
    private func pullIfNewer<Value: Codable>(cloudKey: String, apply: (Value) -> Void) -> Bool {
        guard let remote: ICloudSyncStore.RemoteValue<Value> = cloud.remoteValue(for: cloudKey),
              remote.updatedAt > cloud.localTimestamp(for: cloudKey) + 0.001 else {
            return false
        }
        applyCloudChange(key: cloudKey, updatedAt: remote.updatedAt) {
            apply(remote.value)
        }
        return true
    }

    private func applyCloudChange(key: String, updatedAt: TimeInterval, _ changes: () -> Void) {
        cloudApplyContext = (key, updatedAt)
        defer { cloudApplyContext = nil }
        changes()
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
        memoryEnabled = d.object(forKey: "notif.memory") as? Bool ?? true
        momentsEnabled = d.object(forKey: "notif.moments") as? Bool ?? true
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
        guard cloudSyncEnabled, !isApplyingCloudChange else { return }
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }
            self.pushSettingsToCloud()
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
        guard let remote: ICloudSyncStore.RemoteValue<AppSettingsSnapshot> = cloud.remoteValue(for: ICloudSyncStore.Key.settings),
              remote.updatedAt > cloud.localTimestamp(for: ICloudSyncStore.Key.settings) + 0.001 else {
            return false
        }

        isApplyingCloudChange = true
        apply(remote.value)
        cloud.noteLocalWrite(for: ICloudSyncStore.Key.settings, updatedAt: remote.updatedAt)
        isApplyingCloudChange = false
        onCloudSettingsApplied?()
        return true
    }

    private func pushSettingsToCloud(updatedAt: TimeInterval = Date.now.timeIntervalSinceReferenceDate) {
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
