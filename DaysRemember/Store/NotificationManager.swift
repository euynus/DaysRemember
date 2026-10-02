import Foundation
import UserNotifications
import UIKit

/// Manages local notifications for upcoming days.
///
/// Identifier scheme: `dr.day.<dayId>.pre.<offsetDays>` — lets us cancel a single day's
/// pending requests without disturbing others, and re-sync everything on settings change.
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
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard let id = response.notification.request.content.userInfo["dayID"] as? String else { return }
        await MainActor.run { router.dayID = id }
    }
}

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    /// Strong ref to the delegate — `UNUserNotificationCenter.delegate` is weak.
    private var notificationDelegate: NotificationDelegate?

    /// Install the tap-routing / foreground-presentation delegate. Call once at launch.
    func configureDelegate(router: DeepLinkRouter) {
        let delegate = NotificationDelegate(router: router)
        notificationDelegate = delegate
        UNUserNotificationCenter.current().delegate = delegate
    }

    /// Quiet hours bounds — notifications are pushed past the upper bound when they fall inside.
    nonisolated private static let quietStart = 22
    nonisolated private static let quietEnd = 8

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
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                return granted ? .granted : .denied
            } catch {
                return .deferred
            }
        @unknown default:
            return .deferred
        }
    }

    /// Replace pending day reminders with a fresh schedule built from `days` and `settings`.
    /// Scheduling calls suspend without blocking the main actor.
    func sync(days: [Day], settings: AppSettings) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        // All of our requests are namespaced "dr." (per-day, daily greeting, memories) —
        // clear them all and rebuild from the current days + settings.
        let stale = pending
            .filter { $0.identifier.hasPrefix("dr.") }
            .map(\.identifier)
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        let cal = CNDate.calendar
        let now = Date()
        for day in days {
            let info = DayInfo.compute(day)
            // For non-recurring past days there's nothing left to remind about.
            if info.isPast && !day.recurring { continue }

            let offsets = offsets(for: day, settings: settings)
            guard !offsets.isEmpty else { continue }

            for offset in offsets {
                guard let trigger = Self.triggerDate(
                    displayDate: info.displayDate,
                    offset: offset,
                    hour: settings.notificationHour,
                    minute: settings.notificationMinute,
                    quietHours: settings.quietHours,
                    now: now,
                    calendar: cal
                ) else { continue }
                if trigger <= now { continue }

                let content = UNMutableNotificationContent()
                content.title = "时光"
                content.body = body(for: day, offset: offset)
                content.sound = .default
                content.threadIdentifier = "dr.day.\(day.id)"
                content.userInfo = ["dayID": day.id]  // lets a tap route to this day

                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: trigger)
                let request = UNNotificationRequest(
                    identifier: "dr.day.\(day.id).pre.\(offset)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                )
                try? await center.add(request)
            }
        }

        // 每日晨间问候 — one repeating 08:00 greeting.
        if settings.momentsEnabled {
            let content = UNMutableNotificationContent()
            content.title = "时光"
            content.body = "早安 · 今天也要好好生活，珍惜每一个值得记住的日子。"
            content.sound = .default
            content.threadIdentifier = "dr.daily"
            var comps = DateComponents()
            comps.hour = 8
            comps.minute = 0
            let request = UNNotificationRequest(
                identifier: "dr.daily.greeting",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            )
            try? await center.add(request)
        }

        // 时光回忆 · 一年前的今天 — yearly resurfacing of past one-off days. Recurring
        // days already get their own anniversary reminders above, so `isPast` (true only
        // for non-recurring days whose date has passed) is the right filter.
        if settings.memoryEnabled {
            let time = Self.notificationTime(hour: settings.notificationHour,
                                             minute: settings.notificationMinute,
                                             quietHours: settings.quietHours)
            for day in days where DayInfo.compute(day).isPast {
                let content = UNMutableNotificationContent()
                content.title = "时光回忆"
                content.body = "想起这一天 · 「\(day.title)」"
                content.sound = .default
                content.threadIdentifier = "dr.memory"
                content.userInfo = ["dayID": day.id]
                var comps = cal.dateComponents([.month, .day], from: day.date)
                comps.hour = time.hour
                comps.minute = time.minute
                let request = UNNotificationRequest(
                    identifier: "dr.memory.\(day.id)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                )
                try? await center.add(request)
            }
        }
    }

    func offsets(for day: Day, settings: AppSettings) -> [Int] {
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
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let toRemove = pending
            .filter { $0.identifier.hasPrefix("dr.day.\(dayId).") || $0.identifier == "dr.memory.\(dayId)" }
            .map(\.identifier)
        if !toRemove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: toRemove)
        }
    }

    private func body(for day: Day, offset: Int) -> String {
        let lead: String
        switch offset {
        case 0:
            lead = "今天是「\(day.title)」"
        case 1:
            lead = "「\(day.title)」就是明天"
        default:
            lead = "「\(day.title)」还有 \(offset) 天"
        }
        // Append the place when there is one, for a more contextual reminder
        // ("「蜜月旅行」还有 7 天 · 京都").
        let location = day.location.trimmingCharacters(in: .whitespacesAndNewlines)
        return location.isEmpty ? lead : "\(lead) · \(location)"
    }

    nonisolated static func triggerDate(displayDate: Date, offset: Int, hour: Int, minute: Int,
                                        quietHours: Bool, now: Date,
                                        calendar: Calendar = CNDate.calendar) -> Date? {
        guard let baseDay = calendar.date(byAdding: .day, value: -offset, to: displayDate) else {
            return nil
        }
        let time = notificationTime(hour: hour, minute: minute, quietHours: quietHours)
        guard let trigger = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0,
                                          of: baseDay) else {
            return nil
        }
        return trigger > now ? trigger : nil
    }

    nonisolated static func notificationTime(hour: Int, minute: Int, quietHours: Bool) -> (hour: Int, minute: Int) {
        let hour = min(23, max(0, hour))
        return (quietHours && (hour >= quietStart || hour < quietEnd) ? quietEnd : hour,
                min(59, max(0, minute)))
    }
}
