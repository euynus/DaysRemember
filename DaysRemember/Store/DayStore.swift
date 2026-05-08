import Foundation
import Combine
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class DayStore: ObservableObject {
    @Published var days: [Day] {
        didSet {
            save()
            rescheduleNotifications()
            reloadWidgetTimelines()
        }
    }
    @Published var categories: [CategoryDefinition] {
        didSet {
            saveCategories()
        }
    }

    private let storageKey = "days.v1"
    private let categoriesKey = "categories.v1"
    private let cloud = ICloudSyncStore.shared
    private var cloudSyncEnabled = false
    private var cloudChangeToken: UUID?
    private var isApplyingCloudChange = false
    private var cloudApplyContext: (key: String, updatedAt: TimeInterval)?
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
        guard let data = try? JSONEncoder().encode(days) else { return }
        SharedStorage.defaults.set(data, forKey: storageKey)
        guard !isApplyingCloudChange else {
            if cloudApplyContext?.key == ICloudSyncStore.Key.days,
               let updatedAt = cloudApplyContext?.updatedAt {
                cloud.noteLocalWrite(for: ICloudSyncStore.Key.days, updatedAt: updatedAt)
            }
            return
        }
        let updatedAt = Date().timeIntervalSinceReferenceDate
        cloud.noteLocalWrite(for: ICloudSyncStore.Key.days, updatedAt: updatedAt)
        if cloudSyncEnabled {
            pushDaysToCloud(updatedAt: updatedAt)
        }
    }

    func saveCategories() {
        guard let data = try? JSONEncoder().encode(categories) else { return }
        SharedStorage.defaults.set(data, forKey: categoriesKey)
        guard !isApplyingCloudChange else {
            if cloudApplyContext?.key == ICloudSyncStore.Key.categories,
               let updatedAt = cloudApplyContext?.updatedAt {
                cloud.noteLocalWrite(for: ICloudSyncStore.Key.categories, updatedAt: updatedAt)
            }
            return
        }
        let updatedAt = Date().timeIntervalSinceReferenceDate
        cloud.noteLocalWrite(for: ICloudSyncStore.Key.categories, updatedAt: updatedAt)
        if cloudSyncEnabled {
            pushCategoriesToCloud(updatedAt: updatedAt)
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
            .map { ($0, DayInfo.compute($0)) }
            .filter { !$0.1.isPast && $0.1.days <= within }
            .sorted { $0.1.days < $1.1.days }
            .first?.0
    }

    func resetToSamples() {
        categories = CategoryDefinition.system
        days = SampleData.days
    }

    func rescheduleNotifications() {
        guard let settings else { return }
        let snapshot = days
        Task { await NotificationManager.shared.sync(days: snapshot, settings: settings) }
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
        let source = sortedDays(days)
        guard let categoryID else { return source }
        return source.filter { $0.categoryID == categoryID }
    }

    func sortedDays(_ source: [Day]) -> [Day] {
        source.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned && !rhs.pinned }
            let left = DayInfo.compute(lhs)
            let right = DayInfo.compute(rhs)
            if left.isPast != right.isPast { return !left.isPast }
            return left.days < right.days
        }
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
        if pullDaysIfNewer() { return }
        guard let remote: ICloudSyncStore.RemoteValue<[Day]> = cloud.remoteValue(for: ICloudSyncStore.Key.days) else {
            pushDaysToCloud()
            return
        }
        let localTimestamp = cloud.localTimestamp(for: ICloudSyncStore.Key.days)
        if localTimestamp > remote.updatedAt + 0.001 {
            pushDaysToCloud(updatedAt: localTimestamp)
        }
    }

    private func reconcileCategoriesWithCloud() {
        if pullCategoriesIfNewer() { return }
        guard let remote: ICloudSyncStore.RemoteValue<[CategoryDefinition]> = cloud.remoteValue(for: ICloudSyncStore.Key.categories) else {
            pushCategoriesToCloud()
            return
        }
        let localTimestamp = cloud.localTimestamp(for: ICloudSyncStore.Key.categories)
        if localTimestamp > remote.updatedAt + 0.001 {
            pushCategoriesToCloud(updatedAt: localTimestamp)
        }
    }

    @discardableResult
    private func pullDaysIfNewer() -> Bool {
        guard let remote: ICloudSyncStore.RemoteValue<[Day]> = cloud.remoteValue(for: ICloudSyncStore.Key.days),
              remote.updatedAt > cloud.localTimestamp(for: ICloudSyncStore.Key.days) + 0.001 else {
            return false
        }

        applyCloudChange(key: ICloudSyncStore.Key.days, updatedAt: remote.updatedAt) {
            days = remote.value.map(normalized)
        }
        return true
    }

    @discardableResult
    private func pullCategoriesIfNewer() -> Bool {
        guard let remote: ICloudSyncStore.RemoteValue<[CategoryDefinition]> = cloud.remoteValue(for: ICloudSyncStore.Key.categories),
              remote.updatedAt > cloud.localTimestamp(for: ICloudSyncStore.Key.categories) + 0.001 else {
            return false
        }

        applyCloudChange(key: ICloudSyncStore.Key.categories, updatedAt: remote.updatedAt) {
            categories = Self.normalizedCategories(remote.value)
            days = days.map(normalized)
        }
        return true
    }

    private func pushDaysToCloud(updatedAt: TimeInterval = Date().timeIntervalSinceReferenceDate) {
        cloud.push(days, for: ICloudSyncStore.Key.days, updatedAt: updatedAt)
    }

    private func pushCategoriesToCloud(updatedAt: TimeInterval = Date().timeIntervalSinceReferenceDate) {
        cloud.push(categories, for: ICloudSyncStore.Key.categories, updatedAt: updatedAt)
    }

    private func applyCloudChange(key: String, updatedAt: TimeInterval, _ changes: () -> Void) {
        isApplyingCloudChange = true
        cloudApplyContext = (key, updatedAt)
        changes()
        cloudApplyContext = nil
        isApplyingCloudChange = false
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("hasOnboarded") var hasOnboarded: Bool = false
    @AppStorage("notif.pre7") var notifPre7: Bool = true
    @AppStorage("notif.pre3") var notifPre3: Bool = true
    @AppStorage("notif.pre1") var notifPre1: Bool = false
    @AppStorage("notif.day0") var notifDay0: Bool = true
    @AppStorage("notif.memory") var memoryEnabled: Bool = true
    @AppStorage("notif.moments") var momentsEnabled: Bool = true
    @AppStorage("notif.quiet") var quietHours: Bool = true
    @AppStorage("notif.hour") var notificationHour: Int = 9
    @AppStorage("notif.minute") var notificationMinute: Int = 0

    private let cloud = ICloudSyncStore.shared
    private var cloudSyncEnabled = false
    private var cloudChangeToken: UUID?
    private var settingsCancellable: AnyCancellable?
    private var isApplyingCloudChange = false
    private var onCloudSettingsApplied: (() -> Void)?

    func enableCloudSync(onRemoteApply: @escaping () -> Void = {}) {
        onCloudSettingsApplied = onRemoteApply
        guard !cloudSyncEnabled else { return }
        cloudSyncEnabled = true
        cloudChangeToken = cloud.addChangeHandler { [weak self] changedKeys in
            guard changedKeys == nil || changedKeys?.contains(ICloudSyncStore.Key.settings) == true else { return }
            self?.pullSettingsIfNewer()
        }
        settingsCancellable = objectWillChange.sink { [weak self] _ in
            guard let self, self.cloudSyncEnabled, !self.isApplyingCloudChange else { return }
            Task { @MainActor [weak self] in
                await Task.yield()
                guard let self, self.cloudSyncEnabled, !self.isApplyingCloudChange else { return }
                self.pushSettingsToCloud()
            }
        }
        reconcileSettingsWithCloud()
    }

    private var snapshot: AppSettingsSnapshot {
        AppSettingsSnapshot(settings: self)
    }

    private func reconcileSettingsWithCloud() {
        if pullSettingsIfNewer() { return }
        guard let remote: ICloudSyncStore.RemoteValue<AppSettingsSnapshot> = cloud.remoteValue(for: ICloudSyncStore.Key.settings) else {
            pushSettingsToCloud()
            return
        }
        let localTimestamp = cloud.localTimestamp(for: ICloudSyncStore.Key.settings)
        if localTimestamp > remote.updatedAt + 0.001 {
            pushSettingsToCloud(updatedAt: localTimestamp)
        }
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

    private func pushSettingsToCloud(updatedAt: TimeInterval = Date().timeIntervalSinceReferenceDate) {
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
