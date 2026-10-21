import SwiftUI

@MainActor
struct NotificationsView: View {
    @Environment(AppSettings.self) var settings
    @Environment(DayStore.self) var store
    @Environment(\.scenePhase) private var scenePhase
    private let manager = NotificationManager.shared
    /// False when pushed from 我的, which shows the system navigation bar instead.
    var showsHeader = true

    /// Toggle binding that re-syncs scheduled notifications whenever flipped.
    private func reactiveBinding(_ key: ReferenceWritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: key] },
            set: { newValue in
                settings[keyPath: key] = newValue
                Task { await reschedule(requestPermission: newValue) }
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
                                                                  minute: settings.notificationMinute)
                var components = DateComponents()
                components.calendar = CNDate.calendar
                components.year = 2000
                components.month = 1
                components.day = 1
                components.hour = time.hour
                components.minute = time.minute
                return CNDate.calendar.date(from: components) ?? Date.now
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
                return CNDate.calendar.date(from: components) ?? Date.now
            },
            set: { newValue in
                settings.greetingHour = CNDate.calendar.component(.hour, from: newValue)
                settings.greetingMinute = CNDate.calendar.component(.minute, from: newValue)
                store.rescheduleNotifications()
            }
        )
    }

    private var greetingTimeText: String {
        CNDate.time(hour: settings.greetingHour, minute: settings.greetingMinute)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsHeader {
                NavHeader(title: String(localized: "提醒", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if manager.authorizationStatus == .denied { NotificationPermissionBanner().padding(.bottom, 18) }
                    ReminderPreviewCard(onEnable: { Task { await reschedule(requestPermission: true) } })
                        .padding(.bottom, 26)
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

                    ReminderScheduleSummary().padding(.top, 18)
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

    // MARK: - Greeting time row

    private var greetingTimeRow: some View {
        HStack(spacing: 14) {
            Text("问候时间")
                .font(Theme.sans(15))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            DatePicker("问候时间", selection: greetingTime, displayedComponents: .hourAndMinute)
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
                Text("提醒时间")
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("当天、提前提醒与年度回忆")
                    .font(Theme.sans(12, weight: .medium))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            DatePicker("提醒时间", selection: reminderTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .environment(\.calendar, CNDate.calendar)
                .environment(\.timeZone, CNDate.calendar.timeZone)
                .environment(\.locale, AppLocalization.locale)
                .tint(Theme.accent)
        }
        .cardRow()
    }
}
