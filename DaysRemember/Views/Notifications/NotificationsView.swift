import SwiftUI
import UIKit

struct NotificationsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: DayStore
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

    private var reminderSummary: String {
        [
            settings.notifPre7 ? "7天" : nil,
            settings.notifPre3 ? "3天" : nil,
            settings.notifPre1 ? "1天" : nil,
            settings.notifDay0 ? "当天" : nil
        ]
        .compactMap { $0 }
        .joined(separator: "、")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header.padding(.bottom, 18)
                    if permissionDenied { permissionBanner.padding(.bottom, 18) }
                    sampleCard.padding(.bottom, 22)
                    section("提前提醒") {
                        ToggleRow(label: "提前 7 天", on: reactiveBinding(\.notifPre7))
                        ToggleRow(label: "提前 3 天", on: reactiveBinding(\.notifPre3))
                        ToggleRow(label: "提前 1 天", on: reactiveBinding(\.notifPre1))
                        ToggleRow(label: "当天", on: reactiveBinding(\.notifDay0), isLast: true)
                    }
                    section("提醒时间") {
                        TimeRow(label: "每日提醒时间", time: reminderTime)
                        ValueRow(label: "重要日子提醒",
                                 value: reminderSummary.isEmpty ? "未开启" : reminderSummary,
                                 isLast: true)
                    }
                    section("勿扰") {
                        ToggleRow(label: "夜间勿扰", sub: "22:00 — 8:00 静音",
                                  on: reactiveBinding(\.quietHours), isLast: true)
                    }
                    quote
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .task { permissionDenied = await NotificationManager.shared.currentStatus() == .denied }
    }

    /// Shown when the user has denied notification permission — the reminder toggles
    /// below would otherwise be silently inert.
    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.rose)
            VStack(alignment: .leading, spacing: 2) {
                Text("通知权限已关闭")
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("开启后才能收到日子提醒")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(Theme.sans(13, weight: .semibold))
            .foregroundStyle(Theme.terracotta)
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Theme.roseSoft)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.rose.opacity(0.2), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint("打开系统设置以开启通知")
    }

    private var topBar: some View {
        HStack {
            Color.clear.frame(width: 18, height: 18)
            Spacer()
            Text("提醒").font(Theme.serif(17, weight: .semibold))
            Spacer()
            Color.clear.frame(width: 18, height: 18)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 8)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("不会忘记的提醒")
                .font(Theme.serif(26, weight: .semibold))
            Text("提前几天告诉你，让重要的日子从容到来。")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.muted)
                .lineSpacing(13 * 0.6)
        }
        .padding(.top, 10)
        .padding(.horizontal, 4)
    }

    /// HH:mm of the configured daily reminder time, e.g. "9:00".
    private var sampleTime: String {
        String(format: "%d:%02d", settings.notificationHour, settings.notificationMinute)
    }

    private var sampleCard: some View {
        // Preview the next real reminder the user would actually receive, so the
        // mock matches their data and chosen time instead of a fixed example.
        let day = store.nearestUpcoming(within: 3650)
        let info = day.map { DayInfo.compute($0) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7).fill(Theme.terracotta)
                    Text("时")
                        .font(Theme.serif(14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 28, height: 28)
                Text("时光")
                    .font(Theme.sans(12, weight: .semibold))
                Spacer()
                Text(sampleTime).font(Theme.sans(11)).foregroundStyle(Theme.muted)
            }
            Text(sampleTitleLine(day: day, info: info))
                .font(Theme.serif(14, weight: .semibold))
            Text(sampleSubtitle(day: day, info: info))
                .font(Theme.sans(12))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(12 * 0.5)
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
    }

    private func sampleTitleLine(day: Day?, info: DayInfo?) -> String {
        guard let day, let info else { return "还没有即将到来的日子" }
        if info.isToday { return "今天是「\(day.title)」" }
        return "「\(day.title)」还有 \(info.days) 天"
    }

    private func sampleSubtitle(day: Day?, info: DayInfo?) -> String {
        guard let day, let info else { return "添加一个日子，提醒就会出现在这里。" }
        let date = CNDate.short(info.displayDate)
        return day.location.isEmpty ? date : "\(day.location) · \(date)"
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title).padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.bottom, 18)
    }

    private var quote: some View {
        Text("\u{201C}每一个被记得的日子，都是一份温柔的提醒。\u{201D}")
            .font(Theme.serif(12).italic())
            .lineSpacing(12 * 0.6)
            .foregroundStyle(Theme.ink2)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.terracottaSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.top, 12)
    }
}
