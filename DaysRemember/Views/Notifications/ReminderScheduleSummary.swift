import SwiftUI

/// How many reminders the system holds; its scheduling limits sit behind a disclosure.
@MainActor
struct ReminderScheduleSummary: View {
    private let manager = NotificationManager.shared

    var body: some View {
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
                        Text("「每日问候」由系统每天自动重复，占用 1 条提醒名额。")
                    }
                    Text("受系统限制，每次最多可预先安排 \(NotificationManager.pendingLimit) 条近期提醒（涵盖未来 \(NotificationManager.planningYears) 年内的公历与 1900–2100 年农历日子）；日子较多时预排跨度会相应缩短。")
                    Text("日常使用或后台刷新时，系统会自动续排后续提醒；若很久未打开 App，打开一次即可自动补齐。设为「不提醒」的日子不会发送年度回忆。")
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
}
