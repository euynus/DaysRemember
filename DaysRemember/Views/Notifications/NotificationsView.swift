import SwiftUI
import UIKit

@MainActor
struct NotificationsView: View {
    @Environment(AppSettings.self) var settings
    @Environment(DayStore.self) var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let manager = NotificationManager.shared

    /// Toggle binding that re-syncs scheduled notifications whenever flipped.
    private func reactiveBinding(_ key: ReferenceWritableKeyPath<AppSettings, Bool>,
                                 requestsPermission: Bool = true) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: key] },
            set: { newValue in
                settings[keyPath: key] = newValue
                Task { await reschedule(requestPermission: newValue && requestsPermission) }
            }
        )
    }

    private func reschedule(requestPermission: Bool = false) async {
        if requestPermission { await manager.requestAuthorization() }
        store.rescheduleNotifications()
        await manager.refresh()
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                let time = NotificationManager.notificationTime(hour: settings.notificationHour,
                                                                  minute: settings.notificationMinute, quietHours: false)
                var components = DateComponents()
                components.calendar = CNDate.calendar
                components.year = 2000
                components.month = 1
                components.day = 1
                components.hour = time.hour
                components.minute = time.minute
                return CNDate.calendar.date(from: components) ?? Date()
            },
            set: { newValue in
                settings.notificationHour = CNDate.calendar.component(.hour, from: newValue)
                settings.notificationMinute = CNDate.calendar.component(.minute, from: newValue)
                store.rescheduleNotifications()
            }
        )
    }

    private var greetingTime: Binding<Date> {
        Binding(
            get: {
                let components = DateComponents(calendar: CNDate.calendar, year: 2000, month: 1, day: 1,
                                                 hour: settings.greetingHour, minute: settings.greetingMinute)
                return CNDate.calendar.date(from: components) ?? Date()
            },
            set: { newValue in
                settings.greetingHour = CNDate.calendar.component(.hour, from: newValue)
                settings.greetingMinute = CNDate.calendar.component(.minute, from: newValue)
                store.rescheduleNotifications()
            }
        )
    }

    private var greetingTimeText: String {
        String(format: "%02d:%02d", settings.greetingHour, settings.greetingMinute)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavHeader(title: String(localized: "提醒", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if manager.authorizationStatus == .denied { permissionBanner.padding(.bottom, 18) }
                    previewCard.padding(.bottom, 26)
                    if let error = manager.lastError {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(error).font(Theme.sans(13)).foregroundStyle(Theme.danger)
                            Button("重试", systemImage: "arrow.clockwise") {
                                Task { await reschedule(requestPermission: true) }
                            }
                            .tint(Theme.accent)
                        }
                        .padding(.bottom, 18)
                    }

                    SectionHeader(String(localized: "提前提醒", bundle: AppLocalization.bundle, locale: AppLocalization.locale)).padding(.bottom, 10)
                    CardList {
                        ToggleCell(label: String(localized: "提前 7 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale), isOn: reactiveBinding(\.notifPre7))
                        RowDivider()
                        ToggleCell(label: String(localized: "提前 3 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale), isOn: reactiveBinding(\.notifPre3))
                        RowDivider()
                        ToggleCell(label: String(localized: "提前 1 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale), isOn: reactiveBinding(\.notifPre1))
                        RowDivider()
                        ToggleCell(label: String(localized: "当天提醒", bundle: AppLocalization.bundle, locale: AppLocalization.locale), isOn: reactiveBinding(\.notifDay0))
                    }
                    .padding(.bottom, 22)

                    SectionHeader(String(localized: "问候与回忆", bundle: AppLocalization.bundle, locale: AppLocalization.locale)).padding(.bottom, 10)
                    CardList {
                        ToggleCell(label: String(localized: "每日问候", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                                   sub: String(localized: "每天 \(greetingTimeText)", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                                   isOn: reactiveBinding(\.momentsEnabled))
                        if settings.momentsEnabled {
                            RowDivider()
                            greetingTimeRow
                        }
                        RowDivider()
                        ToggleCell(label: String(localized: "时光回忆", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                                   sub: String(localized: "过往日子的年度回忆，遵循公历或农历", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                                   isOn: reactiveBinding(\.memoryEnabled))
                        RowDivider()
                        timeRow
                    }
                    .padding(.bottom, 22)

                    SectionHeader(String(localized: "勿扰", bundle: AppLocalization.bundle, locale: AppLocalization.locale)).padding(.bottom, 10)
                    CardList {
                        ToggleCell(label: String(localized: "夜间勿扰", bundle: AppLocalization.bundle, locale: AppLocalization.locale), sub: quietHoursDescription,
                                   isOn: reactiveBinding(\.quietHours, requestsPermission: false))
                    }
                    coverageSummary.padding(.top, 18)
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .task { await manager.refresh() }
        // Re-check after the user returns from Settings (the .task won't re-run while
        // the view stays "appeared"), so the banner clears once they enable it.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await reschedule() }
            }
        }
    }

    private var previewCard: some View {
        let next = NotificationManager.canDeliver(manager.authorizationStatus) ? manager.pendingReminders.first : nil
        let day = next?.dayID.flatMap { id in store.days.first { $0.id == id } }
        return HStack(alignment: .top, spacing: 18) {
            if let day, !dynamicTypeSize.isAccessibilitySize {
                PhotoTile(day: day, flat: true, cornerRadius: 3)
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
                        Task { await reschedule(requestPermission: true) }
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

    private var quietHoursDescription: String {
        let minute = min(59, max(0, settings.notificationMinute))
        let morning = minute == 0 ? "08:00" : "08:\(minute < 10 ? "0" : "")\(minute)"
        return String(localized: "22:00 起顺延次日 \(morning)；08:00 前顺延当日 \(morning)", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    /// The count stays visible; system scheduling limits sit behind a disclosure.
    private var coverageSummary: some View {
        let dated = manager.pendingReminders.filter { !$0.repeats }
        return VStack(alignment: .leading, spacing: 8) {
            if NotificationManager.canDeliver(manager.authorizationStatus) {
                Text("系统已安排 \(manager.pendingReminders.count) 条提醒")
                if let last = dated.last {
                    Text("其中 \(dated.count) 条日期提醒，最晚至 \(CNDate.full(last.date))")
                }
            }
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    if manager.pendingReminders.contains(where: \.repeats) {
                        Text("每日问候由系统重复，占用 1 个名额。")
                    }
                    Text("公历与农历最多预排未来 \(NotificationManager.planningYears) 年，按时间保留最早 \(NotificationManager.pendingLimit) 条（含每日问候）；日子较多时范围会缩短。农历日期限于 1900–2100 年。")
                    Text("请定期打开应用更新排程；长期不打开，日期提醒到期后不会自动续排。单日“不提醒”也不参与年度回忆。")
                }
                .padding(.top, 6)
            } label: {
                Text("关于提醒排程")
                    .font(Theme.sans(13, weight: .medium))
                    .foregroundStyle(Theme.ink2)
            }
            .tint(Theme.ink2)
        }
        .font(Theme.sans(12))
        .foregroundStyle(Theme.ink2)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Greeting time row

    private var greetingTimeRow: some View {
        HStack(spacing: 14) {
            Text("问候时间（北京时间）")
                .font(Theme.sans(15))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            DatePicker("问候时间（北京时间）", selection: greetingTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .environment(\.calendar, CNDate.calendar)
                .environment(\.timeZone, CNDate.calendar.timeZone)
                .environment(\.locale, AppLocalization.locale)
                .tint(Theme.accent)
                .accessibilityIdentifier("greetingTimePicker")
        }
        .cardRow()
    }

    // MARK: - Daily reminder time row

    private var timeRow: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("提醒时间（北京时间）")
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("当天、提前提醒与年度回忆")
                    .font(Theme.sans(12, weight: .medium))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            DatePicker("提醒时间（北京时间）", selection: reminderTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .environment(\.calendar, CNDate.calendar)
                .environment(\.timeZone, CNDate.calendar.timeZone)
                .environment(\.locale, AppLocalization.locale)
                .tint(Theme.accent)
        }
        .cardRow()
    }

    // MARK: - Permission banner

    /// Shown when the user has denied notification permission — the reminder toggles
    /// below would otherwise be silently inert.
    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text("通知权限已关闭")
                    .font(Theme.sans(14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("开启后才能收到日子提醒")
                    .font(Theme.sans(12, weight: .medium))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(Theme.sans(14, weight: .bold))
            .foregroundStyle(Theme.ink)
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.notePink))
        .accessibilityElement(children: .combine)
        .accessibilityHint("打开系统设置以开启通知")
    }
}
