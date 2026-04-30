import Foundation
import UserNotifications
import UIKit

/// Manages local notifications for upcoming days.
///
/// Identifier scheme: `dr.day.<dayId>.pre.<offsetDays>` — lets us cancel a single day's
/// pending requests without disturbing others, and re-sync everything on settings change.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    /// Reminder time of day (defaults to 09:00 — matches the prototype's static "上午 9:00" setting).
    private let triggerHour = 9
    private let triggerMinute = 0

    /// Quiet hours bounds — notifications are pushed past the upper bound when they fall inside.
    private let quietStart = 22
    private let quietEnd = 8

    enum AuthorizationResult { case granted, denied, deferred }

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
    /// Safe to call from the main actor; performs the actual scheduling on a detached task.
    func sync(days: [Day], settings: AppSettings) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let stale = pending
            .filter { $0.identifier.hasPrefix("dr.day.") }
            .map(\.identifier)
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        let offsets: [Int] = [
            (settings.notifPre7 ? 7 : nil),
            (settings.notifPre3 ? 3 : nil),
            (settings.notifPre1 ? 1 : nil),
            (settings.notifDay0 ? 0 : nil),
        ].compactMap { $0 }

        guard !offsets.isEmpty else { return }

        let cal = CNDate.calendar
        let now = Date()
        for day in days {
            let info = DayInfo.compute(day)
            // For non-recurring past days there's nothing left to remind about.
            if info.isPast && !day.recurring { continue }

            for offset in offsets {
                guard let baseDay = cal.date(byAdding: .day, value: -offset, to: info.displayDate) else { continue }
                var hour = triggerHour
                if settings.quietHours && (hour >= quietStart || hour < quietEnd) {
                    hour = quietEnd
                }
                guard let trigger = cal.date(bySettingHour: hour, minute: triggerMinute, second: 0,
                                             of: baseDay) else { continue }
                if trigger <= now { continue }

                let content = UNMutableNotificationContent()
                content.title = "时光"
                content.body = body(for: day, offset: offset)
                content.sound = .default
                content.threadIdentifier = "dr.day.\(day.id)"

                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: trigger)
                let request = UNNotificationRequest(
                    identifier: "dr.day.\(day.id).pre.\(offset)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                )
                try? await center.add(request)
            }
        }
    }

    /// Remove pending requests for a specific day (used on delete).
    func cancel(dayId: String) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let toRemove = pending
            .filter { $0.identifier.hasPrefix("dr.day.\(dayId).") }
            .map(\.identifier)
        if !toRemove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: toRemove)
        }
    }

    private func body(for day: Day, offset: Int) -> String {
        switch offset {
        case 0:
            return "今天是「\(day.title)」"
        case 1:
            return "「\(day.title)」就是明天"
        default:
            return "「\(day.title)」还有 \(offset) 天"
        }
    }
}
