import SwiftUI

struct CalendarMonthView: View {
    @Environment(\.currentDay) private var today
    @Environment(DayStore.self) var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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

    private var daysInMonth: Int {
        let cal = CNDate.calendar
        var c = DateComponents(); c.year = year; c.month = month + 2; c.day = 0
        return cal.component(.day, from: cal.date(from: c) ?? Date())
    }

    /// Leading blank cells before the 1st, counted from the user's first weekday.
    private func leadingBlanks(weekStart: Int) -> Int {
        let cal = CNDate.calendar
        var c = DateComponents(); c.year = year; c.month = month + 1; c.day = 1
        let dt = cal.date(from: c) ?? Date()
        return (cal.component(.weekday, from: dt) - weekStart + 7) % 7
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
            NavHeader(title: String(localized: "日历", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    monthHeader
                    calendarCard(eventsByDay: eventsByDay)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    SectionHeader(String(localized: "本月日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                    if eventsByDay.isEmpty {
                        Text("本月没有记录的日子")
                            .font(Theme.sans(15))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(eventsByDay.keys.sorted(), id: \.self) { dayNumber in
                            ForEach(eventsByDay[dayNumber] ?? []) { day in
                                monthRow(day, dayNumber: dayNumber)
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
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
    }

    // MARK: - Month header

    private var monthHeader: some View {
        HStack(alignment: .bottom) {
            // Tapping the title jumps back to the current month (preserves the old
            // "今天" jump without a separate control).
            Button(action: showCurrentMonth) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(CNDate.year(monthDate))
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.muted)
                    Text(CNDate.month(monthDate))
                        .font(Theme.sans(32, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "\(CNDate.year(monthDate)) \(CNDate.month(monthDate))，回到本月", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                if !isShowingCurrentMonth {
                    Button("今天", action: showCurrentMonth)
                        .font(Theme.sans(14, weight: .medium))
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(Theme.accent)
                        .accessibilityIdentifier("calendar.today")
                }
                FAB(systemName: "chevron.left", size: 38, iconSize: 15) { showMonth(offset: -1) }
                    .accessibilityLabel("上个月")
                FAB(systemName: "chevron.right", size: 38, iconSize: 15) { showMonth(offset: 1) }
                    .accessibilityLabel("下个月")
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    // MARK: - Calendar card

    private func calendarCard(eventsByDay: [Int: [Day]]) -> some View {
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
            LazyVGrid(columns: cols, spacing: 1) {
                ForEach(0..<42, id: \.self) { i in
                    let inMonth = i >= firstWeekday && i < firstWeekday + dayCount
                    let d = i - firstWeekday + 1
                    if inMonth {
                        let events = eventsByDay[d] ?? []
                        cellView(d: d, events: events, isToday: isCurrentMonth && d == todayDay)
                    } else {
                        Color.clear.aspectRatio(0.85, contentMode: .fit)
                    }
                }
            }
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) { RowDivider() }
        .overlay(alignment: .bottom) { RowDivider() }
        .contentShape(Rectangle())
        // Horizontal swipes change month; vertical drags still scroll the page.
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                let dx = value.translation.width
                guard abs(dx) > 60, abs(dx) > abs(value.translation.height) * 2 else { return }
                showMonth(offset: dx < 0 ? 1 : -1)
            }
        )
    }

    @ViewBuilder
    private func cellView(d: Int, events: [Day], isToday: Bool) -> some View {
        let hasEvents = !events.isEmpty
        let dotColor = events.first.map { store.category(for: $0).colorToken.color } ?? Theme.muted
        let cal = CNDate.calendar
        let cellDate = cal.date(from: DateComponents(year: year, month: month + 1, day: d)) ?? today
        let term = SolarTerms.name(for: cellDate) ?? SolarTerms.lunarHoliday(for: cellDate)
        // Chinese layouts show the lunar day (the month name on 初一); English shows terms only.
        let lunar = AppLocalization.isEnglish ? nil : Lunar.supportedLunarDate(for: cellDate).map { l in
            l.day == 1 ? Lunar.monthCN(l.month, isLeap: l.isLeap) : Lunar.dayCN(l.day)
        }
        let dateLabel = isToday ? String(localized: "今天，\(CNDate.full(cellDate))", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : CNDate.full(cellDate)
        let lunarLabel = AppLocalization.isEnglish ? dateLabel
            : String(localized: "\(dateLabel)，\(Lunar.fmt(cellDate))", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        let cellLabel = term.map { String(localized: "\(lunarLabel)，\($0)", bundle: AppLocalization.bundle, locale: AppLocalization.locale) } ?? lunarLabel

        let cell = VStack(spacing: 1) {
            Text(verbatim: String(d))
                .font(Theme.sans(15, weight: isToday ? .semibold : .regular))
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
            Circle()
                .fill(isToday ? Theme.accent : (hasEvents ? Theme.bg2 : .clear))
        }
        // The whole cell is the target, not just its digits.
        .contentShape(Rectangle())

        if hasEvents {
            Button {
                if events.count == 1, let first = events.first {
                    onOpen(first)
                } else {
                    selectedDay = CalendarDaySelection(date: cellDate)
                }
            } label: { cell }
                .buttonStyle(PressScale(scale: 0.92))
                .accessibilityLabel(String(localized: "\(cellLabel)，\(events.count) 个日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
        } else {
            Button { newDayDate = CalendarDaySelection(date: cellDate) } label: { cell }
                .buttonStyle(PressScale(scale: 0.92))
                .accessibilityLabel(cellLabel)
                .accessibilityHint("新建这一天的日子")
        }
    }

    // MARK: - This-month list

    private func monthRow(_ day: Day, dayNumber: Int) -> some View {
        let metadata = subtitle(for: day, label: store.category(for: day).displayName)
        let date = CNDate.calendar.date(from: DateComponents(year: year, month: month + 1, day: dayNumber)) ?? today
        return Button { onOpen(day) } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(CNDate.short(date))
                        .font(Theme.sans(12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                    Text(verbatim: day.title)
                        .font(Theme.sans(16, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Text(verbatim: metadata)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.ink2)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                if !dynamicTypeSize.isAccessibilitySize {
                    PhotoTile(day: day, flat: true, cornerRadius: 8, maximumPixelSize: 256,
                              decodesAsynchronously: true)
                        .frame(width: 56, height: 62)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableTileStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(CNDate.short(date))，\(day.title)，\(metadata)", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
        .accessibilityHint("查看日子详情")
        .accessibilityInputLabels([day.title])
    }

    private func subtitle(for day: Day, label: String) -> String {
        var parts = [label]
        if day.recurring { parts.append(String(localized: "每年", bundle: AppLocalization.bundle, locale: AppLocalization.locale)) }
        if day.lunar { parts.append(String(localized: "农历", bundle: AppLocalization.bundle, locale: AppLocalization.locale)) }
        return parts.joined(separator: " · ")
    }
}
