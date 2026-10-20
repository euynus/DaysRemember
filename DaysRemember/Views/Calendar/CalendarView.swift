import SwiftUI

struct CalendarMonthView: View {
    @Environment(\.currentDay) private var today
    @Environment(DayStore.self) var store
    @Environment(DeepLinkRouter.self) private var router
    @State private var month: Int
    @State private var year: Int
    @State private var selectedDay: CalendarDaySelection?
    @State private var newDayDate: CalendarDaySelection?
    var onOpen: (Day) -> Void

    init(onOpen: @escaping (Day) -> Void = { _ in }) {
        let cal = CNDate.calendar
        let today = Today.date
        _month = State(initialValue: cal.component(.month, from: today) - 1) // 0-indexed
        _year = State(initialValue: cal.component(.year, from: today))
        self.onOpen = onOpen
    }

    private var monthDate: Date {
        CNDate.calendar.date(from: DateComponents(year: year, month: month + 1, day: 1)) ?? today
    }

    private var isShowingCurrentMonth: Bool {
        let cal = CNDate.calendar
        return cal.component(.year, from: today) == year && cal.component(.month, from: today) - 1 == month
    }

    private func showMonth(offset: Int) {
        let total = year * 12 + month + offset
        year = total / 12
        month = total % 12
    }

    private func showCurrentMonth() {
        let cal = CNDate.calendar
        year = cal.component(.year, from: today)
        month = cal.component(.month, from: today) - 1
    }

    /// O(N) build keyed by day-of-month for the visible month. Called once per body
    /// re-eval and threaded through `grid` / `monthList` so neither has to recompute.
    private func computeEventsByDay() -> [Int: [Day]] {
        var map: [Int: [Day]] = [:]
        let cal = CNDate.calendar
        for d in store.days {
            for occurrence in DayInfo.occurrences(of: d, inGregorianYear: year) {
                guard cal.component(.month, from: occurrence) - 1 == month else { continue }
                let dayNumber = cal.component(.day, from: occurrence)
                map[dayNumber, default: []].append(d)
            }
        }
        return map
    }

    var body: some View {
        let eventsByDay = computeEventsByDay()
        return VStack(spacing: 0) {
            CalendarMonthHeader(monthDate: monthDate, isShowingCurrentMonth: isShowingCurrentMonth,
                                onShowMonth: { showMonth(offset: $0) }, onShowCurrentMonth: showCurrentMonth)
                .padding(.horizontal, 20)
                .padding(.top, 12)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    CalendarMonthGrid(year: year, month: month, eventsByDay: eventsByDay,
                                      onShowMonth: { showMonth(offset: $0) },
                                      onOpenCell: { events, date in openCell(events: events, date: date) })
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    Text("本月日子")
                        .font(Theme.sans(17, weight: .heavy, relativeTo: .headline))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                        .accessibilityAddTraits(.isHeader)
                    if eventsByDay.isEmpty {
                        Text("本月没有记录的日子")
                            .font(Theme.sans(15))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    } else {
                        ForEach(Self.monthEntries(eventsByDay)) { entry in
                            CalendarMonthRow(day: entry.day, year: year, month: month, dayNumber: entry.dayNumber,
                                             onOpen: onOpen)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .sensoryFeedback(.selection, trigger: year * 12 + month)
        .onChange(of: today) { old, new in
            let calendar = CNDate.calendar
            if year == calendar.component(.year, from: old),
               month == calendar.component(.month, from: old) - 1 {
                year = calendar.component(.year, from: new)
                month = calendar.component(.month, from: new) - 1
            }
        }
        .sheet(item: $selectedDay) { selection in
            CalendarEventPicker(selection: selection, onOpen: onOpen)
        }
        .sheet(item: $newDayDate) { selection in
            DayEditorView(date: selection.date).environment(store)
        }
        // A new day's draft stays open; the day picker would cover the linked day.
        .onChange(of: router.linkOpenCount) { selectedDay = nil }
    }

    /// One day opens directly; several open the day's list; none starts a new day.
    private func openCell(events: [Day], date: Date) {
        if events.count == 1, let first = events.first {
            onOpen(first)
        } else if events.isEmpty {
            newDayDate = CalendarDaySelection(date: date)
        } else {
            selectedDay = CalendarDaySelection(date: date)
        }
    }

    // MARK: - This-month list

    private struct MonthEntry: Identifiable {
        let dayNumber: Int
        let day: Day
        // A day recurs at most once in a Gregorian month.
        var id: String { day.id }
    }

    /// The month's days in date order, flat, so each list row is one element.
    private static func monthEntries(_ eventsByDay: [Int: [Day]]) -> [MonthEntry] {
        eventsByDay.keys.sorted().flatMap { dayNumber in
            (eventsByDay[dayNumber] ?? []).map { MonthEntry(dayNumber: dayNumber, day: $0) }
        }
    }
}
