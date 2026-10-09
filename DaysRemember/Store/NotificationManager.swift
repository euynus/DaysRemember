import Foundation
import UserNotifications
import Observation
import OSLog

/// Bridges a tapped reminder (or widget link) to SwiftUI navigation: `RootTabView`
/// observes `dayID`, opens that day's detail, and clears it.
@MainActor
@Observable
final class DeepLinkRouter {
    var dayID: String?
}

/// UNUserNotificationCenter delegate — routes a tapped reminder to its day, and lets
/// reminders surface as a banner while the app is in the foreground.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let router: DeepLinkRouter
    init(router: DeepLinkRouter) { self.router = router; super.init() }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        await NotificationManager.shared.refresh()
        return [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard let id = response.notification.request.content.userInfo["dayID"] as? String else { return }
        await MainActor.run { router.dayID = id }
    }
}

@MainActor
@Observable
final class NotificationManager {
    static let shared = NotificationManager()
    nonisolated static let pendingLimit = 64
    nonisolated static let planningYears = 5
    private static let logger = Logger(subsystem: "com.shiguang.daysremember", category: "Notifications")

    private(set) var authorizationStatus: UNAuthorizationStatus?
    private(set) var pendingReminders: [PendingReminder] = []
    private(set) var lastError: String?
    @ObservationIgnored private var mutationTask: Task<Void, Never>?

    /// Strong ref to the delegate — `UNUserNotificationCenter.delegate` is weak.
    @ObservationIgnored private var notificationDelegate: NotificationDelegate?

    /// Install the tap-routing / foreground-presentation delegate. Call once at launch.
    func configureDelegate(router: DeepLinkRouter) {
        let delegate = NotificationDelegate(router: router)
        notificationDelegate = delegate
        UNUserNotificationCenter.current().delegate = delegate
    }

    enum AuthorizationResult { case granted, denied, deferred }

    /// Read-only current authorization status (does not prompt). Used to surface a
    /// "notifications are off" banner so the reminder toggles aren't silently inert.
    func currentStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> AuthorizationResult {
        let center = UNUserNotificationCenter.current()
        let current = await center.notificationSettings()
        switch current.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                lastError = nil
                return granted ? .granted : .denied
            } catch {
                lastError = String(localized: "无法请求通知权限：\(error.localizedDescription)", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                Self.logger.error("Authorization failed: \(error.localizedDescription, privacy: .public)")
                return .deferred
            }
        @unknown default:
            return .deferred
        }
    }

    // UN adds can finish after task cancellation. Keep the whole mutation in order,
    // including deletes, rather than allowing a cancelled add to resurrect a reminder.
    func enqueueMutation(_ operation: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        let previous = mutationTask
        let task = Task {
            await previous?.value
            await operation()
        }
        mutationTask = task
        return task
    }

    func sync(days: [Day], settings: AppSettings) async {
        guard !Task.isCancelled else { return }
        let snapshot = AppSettingsSnapshot(settings: settings)
        await enqueueMutation { await self.replaceSchedule(days: days, settings: snapshot) }.value
    }

    private func replaceSchedule(days: [Day], settings: AppSettingsSnapshot) async {
        let center = UNUserNotificationCenter.current()
        let status = await currentStatus()
        let pending = await center.pendingNotificationRequests()
        let otherCount = pending.filter { !$0.identifier.hasPrefix("dr.") }.count
        let plan = Self.canDeliver(status)
            ? Self.plan(days: days, settings: settings, now: Date(), capacity: Self.pendingLimit - otherCount)
            : []
        let wanted = Set(plan.map(\.id))
        let stale = pending
            .filter { $0.identifier.hasPrefix("dr.") && !wanted.contains($0.identifier) }
            .map(\.identifier)
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        if Self.canDeliver(status) { lastError = nil }
        var failed = Set<String>()
        for item in plan {
            do {
                // Adding an existing identifier replaces it without a remove/add gap.
                try await center.add(item.request)
            } catch {
                failed.insert(item.id)
                Self.logger.error("Scheduling \(item.id, privacy: .private) failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        await readPending()
        let actual = Set(pendingReminders.map(\.id))
        failed.formUnion(plan.filter { $0.date > Date() && !actual.contains($0.id) }.map(\.id))
        failed.formUnion(actual.subtracting(wanted))
        if !failed.isEmpty {
            lastError = String(localized: "有 \(failed.count) 条提醒未能更新，请重试；页面仅显示系统已安排的提醒。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
    }

    /// Read system state without requesting permission or scheduling anything.
    func refresh() async {
        await enqueueMutation { await self.readPending() }.value
    }

    private func readPending() async {
        let status = await currentStatus()
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        authorizationStatus = status
        pendingReminders = Self.scheduledReminders(from: requests)
    }

    nonisolated static func canDeliver(_ status: UNAuthorizationStatus?) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    struct PendingReminder: Identifiable {
        let request: UNNotificationRequest
        let date: Date
        var id: String { request.identifier }
        var dayID: String? { request.content.userInfo["dayID"] as? String }
        var repeats: Bool { request.trigger?.repeats == true }
    }

    nonisolated static func scheduledReminders(from requests: [UNNotificationRequest]) -> [PendingReminder] {
        requests.compactMap { request -> PendingReminder? in
            guard request.identifier.hasPrefix("dr."),
                  let trigger = request.trigger as? UNCalendarNotificationTrigger,
                  let date = trigger.nextTriggerDate() else { return nil }
            return PendingReminder(request: request, date: date)
        }.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
    }

    func offsets(for day: Day, settings: AppSettings) -> [Int] {
        Self.offsets(for: day, settings: AppSettingsSnapshot(settings: settings))
    }

    nonisolated private static func offsets(for day: Day, settings: AppSettingsSnapshot) -> [Int] {
        if let dayOffsets = day.reminderOffsets {
            return Set(dayOffsets.filter { $0 >= 0 }).sorted(by: >)
        }

        return [
            (settings.notifPre7 ? 7 : nil),
            (settings.notifPre3 ? 3 : nil),
            (settings.notifPre1 ? 1 : nil),
            (settings.notifDay0 ? 0 : nil),
        ].compactMap { $0 }
    }

    /// Remove pending requests for a specific day (used on delete).
    func cancel(dayId: String) async {
        await enqueueMutation {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            let ids = pending.filter {
                $0.identifier.hasPrefix("dr.") && $0.content.userInfo["dayID"] as? String == dayId
            }.map(\.identifier)
            if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
            await self.readPending()
            if self.pendingReminders.contains(where: { $0.dayID == dayId }) {
                self.lastError = String(localized: "日子提醒未能取消，请重试。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            }
        }.value
    }

    struct PlannedReminder: Identifiable {
        let id: String
        let date: Date
        let title: String
        let body: String
        let dayID: String?
        var repeats = false

        var request: UNNotificationRequest {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.threadIdentifier = dayID.map { "dr.day.\($0)" } ?? "dr.daily"
            if let dayID { content.userInfo = ["dayID": dayID] }
            let calendar = CNDate.calendar
            let fields: Set<Calendar.Component> = repeats ? [.hour, .minute] : [.year, .month, .day, .hour, .minute]
            var components = calendar.dateComponents(fields, from: date)
            components.calendar = calendar
            components.timeZone = calendar.timeZone
            components.second = 0
            return UNNotificationRequest(identifier: id, content: content,
                                         trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats))
        }
    }

    /// Finite, deterministic planning; never depends on the DEBUG display clock.
    nonisolated static func plan(days: [Day], settings: AppSettingsSnapshot, now: Date,
                                 capacity: Int = pendingLimit) -> [PlannedReminder] {
        let calendar = CNDate.calendar
        guard capacity > 0,
              let end = calendar.date(byAdding: .year, value: planningYears, to: now) else { return [] }
        let firstYear = calendar.component(.year, from: now) - 1
        let lastYear = calendar.component(.year, from: end) + 1
        let lunarStart = Lunar.lunarToSolar(year: 1900, month: 1, day: 1)
        let lunarEnd = Lunar.lunarToSolar(year: 1900 + LunarTable.info.count, month: 1, day: 1)
        var candidates: [PlannedReminder] = []

        for day in days {
            guard day.reminderTime?.isValid ?? true else { continue }
            let hour = day.reminderTime?.hour ?? settings.notificationHour
            let minute = day.reminderTime?.minute ?? settings.notificationMinute
            // An explicit empty (or invalid-only) override also opts out of memories.
            if let override = day.reminderOffsets, !override.contains(where: { $0 >= 0 }) { continue }
            let offsets = offsets(for: day, settings: settings)
            let memory = settings.memoryEnabled && !day.recurring
                && calendar.startOfDay(for: day.date) < calendar.startOfDay(for: now)
            guard !offsets.isEmpty || memory else { continue }
            var annualDay = day
            annualDay.recurring = true
            let annualDates: [Date]
            if (day.recurring || memory) && (!day.lunar || (lunarStart..<lunarEnd).contains(day.date)) {
                annualDates = (firstYear...lastYear).flatMap { year in
                    DayInfo.occurrences(of: annualDay, inGregorianYear: year)
                }.filter { !day.lunar || (lunarStart..<lunarEnd).contains($0) }
            } else {
                annualDates = []
            }
            let dates = day.recurring ? annualDates : [calendar.startOfDay(for: day.date)]
            for date in dates where date >= calendar.startOfDay(for: day.date) {
                for offset in offsets {
                    guard let trigger = triggerDate(displayDate: date, offset: offset,
                                                    hour: hour, minute: minute, now: now), trigger <= end else { continue }
                    candidates.append(PlannedReminder(
                        id: "dr.day.\(day.id).pre.\(offset).\(Int(date.timeIntervalSince1970))", date: trigger,
                        title: String(localized: "时光", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                        body: body(for: day, offset: CNDate.daysBetween(trigger, date)), dayID: day.id))
                }
            }
            if memory {
                for date in annualDates where date > calendar.startOfDay(for: day.date) {
                    guard let trigger = triggerDate(displayDate: date, offset: 0,
                                                    hour: hour, minute: minute, now: now), trigger <= end else { continue }
                    candidates.append(PlannedReminder(
                        id: "dr.memory.\(day.id).\(Int(date.timeIntervalSince1970))", date: trigger,
                        title: String(localized: "时光回忆", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                        body: String(localized: "想起这一天 · 「\(day.title)」 · \(CNDate.full(date))", bundle: AppLocalization.bundle, locale: AppLocalization.locale), dayID: day.id))
                }
            }
        }
        let greetingHour = min(23, max(0, settings.greetingHour))
        if settings.momentsEnabled,
           let greeting = calendar.nextDate(after: now, matching: DateComponents(hour: greetingHour,
                                                                                 minute: min(59, max(0, settings.greetingMinute)),
                                                                                 second: 0),
                                            matchingPolicy: .nextTime) {
            // "早安" only suits a morning greeting.
            let body = (5..<12).contains(greetingHour)
                ? String(localized: "早安 · 今天也要好好生活，珍惜每一个值得记住的日子。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                : String(localized: "今天也要好好生活，珍惜每一个值得记住的日子。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            candidates.append(PlannedReminder(id: "dr.daily.greeting", date: greeting,
                                               title: String(localized: "时光", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                                               body: body, dayID: nil, repeats: true))
        }
        // ponytail: finite five-year window; reopening the app replenishes it, not a background recurrence engine.
        return Array(candidates.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
            .prefix(min(pendingLimit, capacity)))
    }

    nonisolated private static func body(for day: Day, offset: Int) -> String {
        let lead: String
        switch offset {
        case ...0:
            lead = String(localized: "今天是「\(day.title)」", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case 1:
            lead = String(localized: "「\(day.title)」就是明天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        default:
            lead = String(localized: "「\(day.title)」还有 \(offset) 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
        // Append the place when there is one, for a more contextual reminder
        // ("「蜜月旅行」还有 7 天 · 京都").
        let location = day.location.trimmingCharacters(in: .whitespacesAndNewlines)
        return location.isEmpty ? lead : String(localized: "\(lead) · \(location)", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    nonisolated static func triggerDate(displayDate: Date, offset: Int, hour: Int, minute: Int,
                                        now: Date, calendar: Calendar = CNDate.calendar) -> Date? {
        guard offset >= 0,
              let deliveryDay = calendar.date(byAdding: .day, value: -offset, to: displayDate) else {
            return nil
        }
        let time = notificationTime(hour: hour, minute: minute)
        guard let trigger = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0,
                                          of: deliveryDay) else {
            return nil
        }
        return trigger > now ? trigger : nil
    }

    /// Clamps a stored hour and minute into a valid time of day.
    nonisolated static func notificationTime(hour: Int, minute: Int) -> (hour: Int, minute: Int) {
        (min(23, max(0, hour)), min(59, max(0, minute)))
    }
}
