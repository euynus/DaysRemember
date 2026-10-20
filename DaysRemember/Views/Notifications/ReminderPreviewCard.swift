import SwiftUI

/// The next reminder the system will deliver, or why there is none.
@MainActor
struct ReminderPreviewCard: View {
    @Environment(DayStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let manager = NotificationManager.shared
    /// Asks for permission, while it hasn't been decided, and reschedules.
    var onEnable: () -> Void = {}

    var body: some View {
        let next = NotificationManager.canDeliver(manager.authorizationStatus) ? manager.pendingReminders.first : nil
        let day = next?.dayID.flatMap { id in store.days.first { $0.id == id } }
        return HStack(alignment: .top, spacing: 18) {
            if let day, !dynamicTypeSize.isAccessibilitySize {
                PhotoTile(day: day, flat: true, cornerRadius: 3, maximumPixelSize: 320)
                    .frame(width: 80, height: 106)
            }
            VStack(alignment: .leading, spacing: 12) {
                if next != nil {
                    Label("下一次已安排提醒", systemImage: "bell.badge")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.accent)
                }
                Text(next?.request.content.body ?? emptyScheduleTitle)
                    .font(Theme.sans(19, weight: .medium))
                    .foregroundStyle(Theme.ink)
                if let next {
                    Text(next.date, format: reminderDateFormat)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.ink2)
                }
                if manager.authorizationStatus == .notDetermined {
                    Button("启用通知", systemImage: "bell") {
                        onEnable()
                    }
                    .tint(Theme.accent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .padding(.bottom, 22)
        .overlay(alignment: .bottom) { RowDivider() }
    }

    private var emptyScheduleTitle: String {
        guard let status = manager.authorizationStatus else { return String(localized: "正在读取系统提醒…", bundle: AppLocalization.bundle, locale: AppLocalization.locale) }
        if status == .notDetermined { return String(localized: "尚未授权通知", bundle: AppLocalization.bundle, locale: AppLocalization.locale) }
        if status == .denied { return String(localized: "通知权限已关闭", bundle: AppLocalization.bundle, locale: AppLocalization.locale) }
        return NotificationManager.canDeliver(status)
            ? String(localized: "暂未安排提醒", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "暂时无法确认通知权限", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    private var reminderDateFormat: Date.FormatStyle {
        Date.FormatStyle(date: .abbreviated, time: .shortened, locale: AppLocalization.locale,
                         calendar: CNDate.calendar, timeZone: CNDate.calendar.timeZone)
    }
}
