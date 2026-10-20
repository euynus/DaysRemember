import SwiftUI

/// The month's seven-column grid; a sideways swipe moves to the next or previous month.
struct CalendarMonthGrid: View {
    @Environment(\.currentDay) private var today
    let year: Int
    /// 0-indexed.
    let month: Int
    /// The month's days, by day of the month.
    let eventsByDay: [Int: [Day]]
    var onShowMonth: (_ offset: Int) -> Void = { _ in }
    var onOpenCell: (_ events: [Day], _ date: Date) -> Void = { _, _ in }

    var body: some View {
        let cal = CNDate.calendar
        let isCurrentMonth = (cal.component(.year, from: today) == year)
            && (cal.component(.month, from: today) - 1 == month)
        let todayDay = cal.component(.day, from: today)
        let weekStart = CNDate.firstWeekday()
        let firstWeekday = leadingBlanks(weekStart: weekStart)
        let dayCount = daysInMonth
        let cols = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)
        let symbols = CNDate.shortWeekdaySymbols
        let orderedSymbols = Array(symbols[(weekStart - 1)...] + symbols[..<(weekStart - 1)])

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(orderedSymbols, id: \.self) { d in
                    Text(d)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                }
            }
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(0..<42, id: \.self) { i in
                    let inMonth = i >= firstWeekday && i < firstWeekday + dayCount
                    let d = i - firstWeekday + 1
                    // One container per cell, so a lazy grid cell's identity doesn't depend on the branch.
                    ZStack {
                        if inMonth {
                            CalendarDayCell(year: year, month: month, dayNumber: d, events: eventsByDay[d] ?? [],
                                            isToday: isCurrentMonth && d == todayDay, onOpen: onOpenCell)
                        } else {
                            Color.clear.aspectRatio(0.85, contentMode: .fit)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .contentShape(Rectangle())
        // Horizontal swipes change month; vertical drags still scroll the page.
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                let dx = value.translation.width
                guard abs(dx) > 60, abs(dx) > abs(value.translation.height) * 2 else { return }
                onShowMonth(dx < 0 ? 1 : -1)
            }
        )
    }

    private var daysInMonth: Int {
        let cal = CNDate.calendar
        var c = DateComponents(); c.year = year; c.month = month + 2; c.day = 0
        return cal.component(.day, from: cal.date(from: c) ?? Date.now)
    }

    /// Leading blank cells before the 1st, counted from the user's first weekday.
    private func leadingBlanks(weekStart: Int) -> Int {
        let cal = CNDate.calendar
        var c = DateComponents(); c.year = year; c.month = month + 1; c.day = 1
        let dt = cal.date(from: c) ?? Date.now
        return (cal.component(.weekday, from: dt) - weekStart + 7) % 7
    }
}
