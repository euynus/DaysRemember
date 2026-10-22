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
                        Text("每日问候由系统重复，占用 1 个名额。")
                    }
                    Text("公历与农历最多预排未来 \(NotificationManager.planningYears) 年，按时间保留最早 \(NotificationManager.pendingLimit) 条（含每日问候）；日子较多时范围会缩短。农历日期限于 1900–2100 年。")
                    Text("iOS 通常会在后台续排提醒；很久不打开 App 时，打开一次一定能补上。单日「不提醒」也不参与年度回忆。")
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
