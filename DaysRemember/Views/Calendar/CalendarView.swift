import SwiftUI

// Scrapbook month calendar — port of screens/Calendar.jsx. A white calendar card
// over the paper canvas, today filled ink, marked days dotted in their category
// color, then a "本月日子" list of mini-polaroid scrapbook rows.
struct CalendarMonthView: View {
    @Environment(DayStore.self) var store
    @State private var month: Int
    @State private var year: Int
    @State private var selectedEvents: [Day] = []
    @State private var selectedDayTitle = ""
    var onOpen: (Day) -> Void

    init(onOpen: @escaping (Day) -> Void = { _ in }) {
        let cal = CNDate.calendar
        let today = Today.date
        _month = State(initialValue: cal.component(.month, from: today) - 1) // 0-indexed
        _year = State(initialValue: cal.component(.year, from: today))
        self.onOpen = onOpen
    }

    private static let monthCN = ["一","二","三","四","五","六","七","八","九","十","十一","十二"]
    private static let monthEN = ["January","February","March","April","May","June",
                                  "July","August","September","October","November","December"]
    private static let weekdayCN = ["日","一","二","三","四","五","六"]

    private var daysInMonth: Int {
        let cal = CNDate.calendar
        var c = DateComponents(); c.year = year; c.month = month + 2; c.day = 0
        return cal.component(.day, from: cal.date(from: c) ?? Date())
    }

    private var firstDow: Int {
        let cal = CNDate.calendar
        var c = DateComponents(); c.year = year; c.month = month + 1; c.day = 1
        let dt = cal.date(from: c) ?? Date()
        return cal.component(.weekday, from: dt) - 1
    }

    /// O(N) build keyed by day-of-month for the visible month. Called once per body
    /// re-eval and threaded through `grid` / `monthList` so neither has to recompute.
    private func computeEventsByDay() -> [Int: [Day]] {
        var map: [Int: [Day]] = [:]
        let cal = CNDate.calendar
        for d in store.days {
            // Resolve the anniversary in the visible year. Lunar-recurring days drift
            // through the solar calendar — the original solar date is in 1962 etc.,
            // so we have to walk lunar→solar in `year` to know where it actually lands.
            let anniversary = anniversaryDate(for: d)
            let dm = cal.component(.month, from: anniversary) - 1
            let dy = cal.component(.year, from: anniversary)
            let dd = cal.component(.day, from: anniversary)
            if d.recurring {
                if dm == month {
                    map[dd, default: []].append(d)
                }
            } else if dm == month && dy == year {
                map[dd, default: []].append(d)
            }
        }
        return map
    }

    private func anniversaryDate(for day: Day) -> Date {
        guard day.recurring && day.lunar else { return day.date }
        let lunar = Lunar.solarToLunar(day.date)
        return Lunar.lunarToSolar(year: year, month: lunar.month,
                                  day: lunar.day, isLeap: lunar.isLeap)
    }

    var body: some View {
        let eventsByDay = computeEventsByDay()
        let monthDays = eventsByDay.keys.sorted().flatMap { eventsByDay[$0] ?? [] }
        return VStack(spacing: 0) {
            NavHeader(title: "日历")
            monthHeader
            calendarCard(eventsByDay: eventsByDay)
                .padding(.horizontal, 22)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("本月日子")
                    if monthDays.isEmpty {
                        Text("本月没有记录的日子")
                            .font(Theme.handCN(20))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(monthDays) { day in
                            monthRow(day)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .sensoryFeedback(.selection, trigger: year * 12 + month)
        .sheet(isPresented: Binding(
            get: { !selectedEvents.isEmpty },
            set: { if !$0 { selectedEvents = [] } }
        )) {
            CalendarEventPicker(title: selectedDayTitle, events: selectedEvents) { day in
                selectedEvents = []
                onOpen(day)
            }
        }
    }

    // MARK: - Month header

    private var monthHeader: some View {
        HStack(alignment: .bottom) {
            // Tapping the title jumps back to the current month (preserves the old
            // "今天" jump without a separate control).
            Button {
                let cal = CNDate.calendar; let today = Today.date
                year = cal.component(.year, from: today)
                month = cal.component(.month, from: today) - 1
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "\(Self.monthCN[month])月")
                        .font(Theme.sans(32, weight: .heavy))
                        .tracking(-0.9)
                        .foregroundStyle(Theme.ink)
                    Text(verbatim: "\(Self.monthEN[month]) \(year)")
                        .font(Theme.hand(24))
                        .foregroundStyle(Theme.catTravel)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(year)年\(Self.monthCN[month])月，回到本月")
            Spacer()
            HStack(spacing: 8) {
                FAB(systemName: "chevron.left", size: 38, iconSize: 15) {
                    if month == 0 { month = 11; year -= 1 } else { month -= 1 }
                }
                .accessibilityLabel("上个月")
                FAB(systemName: "chevron.right", size: 38, iconSize: 15) {
                    if month == 11 { month = 0; year += 1 } else { month += 1 }
                }
                .accessibilityLabel("下个月")
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    // MARK: - Calendar card

    private func calendarCard(eventsByDay: [Int: [Day]]) -> some View {
        let cal = CNDate.calendar
        let today = Today.date
        let isCurrentMonth = (cal.component(.year, from: today) == year)
            && (cal.component(.month, from: today) - 1 == month)
        let todayDay = cal.component(.day, from: today)
        let cols = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Self.weekdayCN, id: \.self) { d in
                    Text(d)
                        .font(Theme.sans(11, weight: .bold))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                }
            }
            LazyVGrid(columns: cols, spacing: 1) {
                ForEach(0..<42, id: \.self) { i in
                    let inMonth = i >= firstDow && i < firstDow + daysInMonth
                    let d = i - firstDow + 1
                    if inMonth {
                        let events = eventsByDay[d] ?? []
                        cellView(d: d, events: events, isToday: isCurrentMonth && d == todayDay)
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding(EdgeInsets(top: 14, leading: 12, bottom: 12, trailing: 12))
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white))
        .floatShadow()
    }

    @ViewBuilder
    private func cellView(d: Int, events: [Day], isToday: Bool) -> some View {
        let hasEvents = !events.isEmpty
        let dotColor = events.first.map { store.category(for: $0).colorToken.color } ?? Theme.muted
        let cal = CNDate.calendar
        let cellDate = cal.date(from: DateComponents(year: year, month: month + 1, day: d)) ?? Today.date
        let term = SolarTerms.name(for: cellDate) ?? SolarTerms.lunarHoliday(for: cellDate)

        let cell = VStack(spacing: 1) {
            Text("\(d)")
                .font(Theme.sans(14, weight: isToday ? .heavy : .semibold))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color.white : Theme.ink)
            if let term {
                Text(term)
                    .font(Theme.sans(7.5, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(isToday ? Color.white.opacity(0.8) : Theme.catTravel)
            }
            if hasEvents {
                Circle()
                    .fill(isToday ? Color.white : dotColor)
                    .frame(width: 5, height: 5)
                    .padding(.top, 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isToday ? Theme.ink : (hasEvents ? Theme.bg : .clear))
        }

        if hasEvents {
            Button {
                if events.count == 1, let first = events.first {
                    onOpen(first)
                } else {
                    selectedDayTitle = "\(year)年\(Self.monthCN[month])月\(d)日"
                    selectedEvents = events
                }
            } label: { cell }
                .buttonStyle(PressScale(scale: 0.92))
                .accessibilityLabel("\(isToday ? "今天，" : "")\(d)日，\(events.count) 个日子")
        } else {
            cell.accessibilityLabel(isToday ? "今天，\(d)日" : "\(d)日")
        }
    }

    // MARK: - This-month list

    private func monthRow(_ day: Day) -> some View {
        let info = DayInfo.compute(day)
        let cat = store.category(for: day)
        let cal = CNDate.calendar
        let dayNum = cal.component(.day, from: info.displayDate)
        let countdown = info.isToday ? "Today" : (info.isPast ? "+\(info.days)" : "\(info.days)d")

        return Button { onOpen(day) } label: {
            HStack(spacing: 14) {
                VStack(spacing: 3) {
                    Text("\(dayNum)")
                        .font(Theme.sans(22, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(cat.colorToken.color)
                    Text(CNDate.weekday(info.displayDate).replacingOccurrences(of: "星期", with: "周"))
                        .font(Theme.sans(10, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
                .frame(width: 44)

                VStack(spacing: 0) {
                    PhotoTile(day: day, flat: true, cornerRadius: 6)
                        .frame(width: 38, height: 38)
                }
                .polaroidCard(rotation: -3, padding: 4)
                .frame(width: 46)

                VStack(alignment: .leading, spacing: 1) {
                    Text(day.title)
                        .font(Theme.sans(15, weight: .bold))
                        .tracking(-0.1)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(subtitle(for: day, label: cat.name))
                        .font(Theme.sans(12, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(countdown)
                    .font(Theme.hand(20))
                    .foregroundStyle(Theme.ink2)
            }
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 14))
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            .shadow(color: Color(hex: 0x15171C).opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PressScale())
    }

    private func subtitle(for day: Day, label: String) -> String {
        var parts = [label]
        if day.recurring { parts.append("每年") }
        if day.lunar { parts.append("农历") }
        return parts.joined(separator: " · ")
    }
}

// Multi-event day picker (a single calendar cell can carry several days).
private struct CalendarEventPicker: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let events: [Day]
    var onOpen: (Day) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") { dismiss() }
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .buttonStyle(.plain)
                Spacer()
                Text(title).font(Theme.sans(16, weight: .bold))
                Spacer()
                Color.clear.frame(width: 36, height: 32)
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 12)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(events) { event in
                        Button {
                            onOpen(event)
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                VStack(spacing: 0) {
                                    PhotoTile(day: event, flat: true, cornerRadius: 6)
                                        .frame(width: 38, height: 38)
                                }
                                .polaroidCard(rotation: -3, padding: 4)
                                .frame(width: 46)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(Theme.sans(15, weight: .bold))
                                        .foregroundStyle(Theme.ink)
                                    Text(event.categoryLabel)
                                        .font(Theme.sans(12, weight: .medium))
                                        .foregroundStyle(Theme.muted)
                                }
                                Spacer()
                            }
                            .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 14))
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
                            .shadow(color: Color(hex: 0x15171C).opacity(0.05), radius: 2, x: 0, y: 1)
                        }
                        .buttonStyle(PressScale())
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
        .background(Theme.bg)
        .presentationDetents([.medium, .large])
    }
}
