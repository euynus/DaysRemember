import SwiftUI
import UIKit

struct NotificationsView: View {
    @Environment(AppSettings.self) var settings
    @Environment(DayStore.self) var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var permissionDenied = false

    /// Toggle binding that re-syncs scheduled notifications whenever flipped.
    private func reactiveBinding(_ key: ReferenceWritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: key] },
            set: { newValue in
                settings[keyPath: key] = newValue
                store.rescheduleNotifications()
            }
        )
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.calendar = CNDate.calendar
                components.year = 2000
                components.month = 1
                components.day = 1
                components.hour = settings.notificationHour
                components.minute = settings.notificationMinute
                return CNDate.calendar.date(from: components) ?? Date()
            },
            set: { newValue in
                settings.notificationHour = CNDate.calendar.component(.hour, from: newValue)
                settings.notificationMinute = CNDate.calendar.component(.minute, from: newValue)
                store.rescheduleNotifications()
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if permissionDenied { permissionBanner.padding(.bottom, 18) }
                    previewCard.padding(.bottom, 26)

                    SectionHeader("提前提醒").padding(.bottom, 10)
                    CardList {
                        ToggleCell(label: "提前 7 天", isOn: reactiveBinding(\.notifPre7))
                        RowDivider()
                        ToggleCell(label: "提前 3 天", isOn: reactiveBinding(\.notifPre3))
                        RowDivider()
                        ToggleCell(label: "提前 1 天", isOn: reactiveBinding(\.notifPre1))
                        RowDivider()
                        ToggleCell(label: "当天提醒", isOn: reactiveBinding(\.notifDay0))
                    }
                    .padding(.bottom, 22)

                    SectionHeader("每日 & 智能").padding(.bottom, 10)
                    CardList {
                        ToggleCell(label: "每日晨间问候", sub: "每天 08:00",
                                   isOn: reactiveBinding(\.momentsEnabled))
                        RowDivider()
                        ToggleCell(label: "时光回忆", sub: "一年前的今天",
                                   isOn: reactiveBinding(\.memoryEnabled))
                        RowDivider()
                        timeRow
                    }
                    .padding(.bottom, 22)

                    SectionHeader("勿扰").padding(.bottom, 10)
                    CardList {
                        ToggleCell(label: "夜间勿扰", sub: "22:00 — 08:00 静音",
                                   isOn: reactiveBinding(\.quietHours))
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .task { await refreshPermission() }
        // Re-check after the user returns from Settings (the .task won't re-run while
        // the view stays "appeared"), so the banner clears once they enable it.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refreshPermission() } }
        }
    }

    private func refreshPermission() async {
        permissionDenied = await NotificationManager.shared.currentStatus() == .denied
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("温柔地提醒你")
                .font(Theme.sans(30, weight: .heavy))
                .tracking(-0.9)
                .foregroundStyle(Theme.ink)
            Text("不吵你，只在那些重要的日子，轻轻敲一下。")
                .font(Theme.sans(14, weight: .medium))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(14 * 0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 56)
        .padding(.bottom, 2)
    }

    // MARK: - Preview notification card

    /// Preview the next real reminder the user would actually receive, so the
    /// mock matches their data and chosen time instead of a fixed example.
    private var previewCard: some View {
        let day = store.nearestUpcoming(within: 3650)
        let info = day.map { DayInfo.compute($0) }
        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.ink)
                        Text("时")
                            .font(Theme.sans(13, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 28, height: 28)
                    Text("时光 · Days Remember")
                        .font(Theme.sans(12, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 8)
                    Text(sampleTimeDate, format: .dateTime.hour().minute())
                        .font(Theme.sans(11, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
                Text(previewTitle(day: day, info: info))
                    .font(Theme.sans(14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(previewNote(day: day))
                    .font(Theme.handCN(18))
                    .foregroundStyle(Theme.ink2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            .shadow(color: Color(hex: 0x15171C).opacity(0.06), radius: 2, x: 0, y: 1)
            .shadow(color: Color(hex: 0x15171C).opacity(0.08), radius: 24, x: 0, y: 10)
            .rotationEffect(.degrees(-0.6))

            Paperclip().offset(x: 30, y: -10)
        }
        .overlay(alignment: .topTrailing) {
            Sticker(name: .heart, size: 34, rotate: 12).offset(x: -14, y: -6)
        }
        // Leave headroom for the clipped paperclip / sticker that overhang the top.
        .padding(.top, 6)
    }

    private var sampleTimeDate: Date {
        var components = DateComponents()
        components.hour = settings.notificationHour
        components.minute = settings.notificationMinute
        return CNDate.calendar.date(from: components) ?? .now
    }

    private func previewTitle(day: Day?, info: DayInfo?) -> String {
        guard let day, let info else { return "添加一个日子，提醒就会出现在这里" }
        if info.isToday { return "今天就是「\(day.title)」" }
        return "再 \(info.days) 天就是「\(day.title)」"
    }

    private func previewNote(day: Day?) -> String {
        guard let day else { return "那些值得记住的日子，都会轻轻提醒你。" }
        if !day.note.isEmpty { return day.note }
        let date = CNDate.short(DayInfo.compute(day).displayDate)
        return day.location.isEmpty ? date : "\(day.location) · \(date)"
    }

    // MARK: - Daily reminder time row

    /// Keeps the configurable notification time (notificationHour/Minute) — surfaced
    /// as a compact time picker so this scrapbook layout doesn't drop the feature.
    private var timeRow: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("每日提醒时间")
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("当天与提前提醒的推送时间")
                    .font(Theme.sans(12, weight: .medium))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            DatePicker("", selection: reminderTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(Theme.catWork)
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
                .foregroundStyle(Theme.catLove)
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
