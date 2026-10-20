import SwiftUI

/// One day of the month grid: its number, lunar day or solar term, and a dot for its days.
struct CalendarDayCell: View {
    @Environment(\.currentDay) private var today
    @Environment(DayStore.self) private var store
    let year: Int
    /// 0-indexed.
    let month: Int
    let dayNumber: Int
    let events: [Day]
    let isToday: Bool
    var onOpen: (_ events: [Day], _ date: Date) -> Void = { _, _ in }

    var body: some View {
        let d = dayNumber
        let hasEvents = !events.isEmpty
        let eventCategory = events.first.map { store.category(for: $0) }
        let dotColor = eventCategory?.tintInk ?? Theme.muted
        let cal = CNDate.calendar
        let cellDate = cal.date(from: DateComponents(year: year, month: month + 1, day: d)) ?? today
        let marks = SolarTerms.marks(for: cellDate)
        let term = marks.first
        // Chinese layouts show the lunar day (the month name on 初一); English shows terms only.
        let lunar = AppLocalization.isEnglish ? nil : Lunar.supportedLunarDate(for: cellDate).map { l in
            l.day == 1 ? Lunar.monthCN(l.month, isLeap: l.isLeap) : Lunar.dayCN(l.day)
        }
        let dateLabel = isToday ? String(localized: "今天，\(CNDate.full(cellDate))", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : CNDate.full(cellDate)
        let lunarLabel = AppLocalization.isEnglish ? dateLabel
            : String(localized: "\(dateLabel)，\(Lunar.fmt(cellDate))", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        let cellLabel = marks.reduce(lunarLabel) { String(localized: "\($0)，\($1)", bundle: AppLocalization.bundle, locale: AppLocalization.locale) }

        let cell = VStack(spacing: 1) {
            Text(verbatim: String(d))
                .numberFont(17, weight: .bold)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isToday ? Color.white : Theme.ink)
            if let second = term ?? lunar {
                Text(verbatim: second)
                    .font(Theme.sans(9, weight: .medium))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isToday ? Color.white.opacity(0.8) : term != nil ? Theme.solarTerm : Theme.muted)
                    .padding(.horizontal, 2)
            }
            if hasEvents {
                Circle()
                    .fill(isToday ? Color.white : dotColor)
                    .frame(width: 5, height: 5)
                    .padding(.top, 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(0.85, contentMode: .fit)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isToday ? Theme.ink : (eventCategory?.tint ?? .clear))
                .padding(.horizontal, 2)
        }
        // The whole cell is the target, not just its digits.
        .contentShape(Rectangle())

        return Button { onOpen(events, cellDate) } label: { cell }
            .buttonStyle(PressScale(scale: 0.92))
            .accessibilityLabel(hasEvents
                ? String(localized: "\(cellLabel)，\(events.count) 个日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                : cellLabel)
            .accessibilityHint(hasEvents ? Text(verbatim: "") : Text("新建这一天的日子"))
    }
}
