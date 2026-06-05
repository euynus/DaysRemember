import SwiftUI

// The days inside one category — scrapbook rows matching the calendar's month
// list: a date number + weekday, a tilted polaroid thumbnail, the title with a
// category/recurrence meta line, and a handwritten countdown accent.
struct CategoryDaysListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DayStore.self) private var store
    let title: String
    let days: [Day]
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: title) { dismiss() }
            ScrollView(.vertical, showsIndicators: false) {
                if days.isEmpty {
                    Text("这个分类下还没有日子")
                        .font(Theme.handCN(22))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else {
                    VStack(spacing: 12) {
                        ForEach(days) { day in
                            dayRow(day)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func dayRow(_ day: Day) -> some View {
        let info = DayInfo.compute(day)
        let category = store.category(for: day)
        let tint = category.colorToken.color
        return Button { onOpen(day) } label: {
            HStack(spacing: 14) {
                VStack(spacing: 3) {
                    Text("\(CNDate.calendar.component(.day, from: info.displayDate))")
                        .font(Theme.sans(22, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                    Text(weekdayShort(info.displayDate))
                        .font(Theme.sans(10, weight: .bold))
                        .foregroundStyle(Theme.muted)
                }
                .frame(width: 44)

                PhotoTile(day: day, flat: true, cornerRadius: 9)
                    .frame(width: 46, height: 38)
                    .polaroidCard(rotation: -3, padding: 4)

                VStack(alignment: .leading, spacing: 1) {
                    Text(day.title)
                        .font(Theme.sans(15, weight: .bold))
                        .tracking(-0.2)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(metaLine(day))
                        .font(Theme.sans(12, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)

                Text(accent(info))
                    .font(Theme.hand(20))
                    .foregroundStyle(Theme.ink2)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white)
            )
            .shadow(color: Color(hex: 0x15171C).opacity(0.05), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(PressScale())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(day.title)，"
            + (info.isToday ? "就是今天" : "\(info.labelShort) \(info.days) 天")
        )
    }

    private func metaLine(_ day: Day) -> String {
        var parts = [day.categoryLabel]
        if day.recurring { parts.append("每年") }
        if day.lunar { parts.append("农历") }
        return parts.joined(separator: " · ")
    }

    private func accent(_ info: DayInfo) -> String {
        if info.isToday { return "Today" }
        return info.isPast ? "+\(info.days)" : "\(info.days)d"
    }

    /// "星期四" → "周四", to match the calendar list's compact weekday label.
    private func weekdayShort(_ date: Date) -> String {
        CNDate.weekday(date).replacingOccurrences(of: "星期", with: "周")
    }
}
