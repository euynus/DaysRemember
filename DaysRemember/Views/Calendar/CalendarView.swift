import SwiftUI

struct CalendarMonthView: View {
    @EnvironmentObject var store: DayStore
    @State private var month: Int
    @State private var year: Int
    var onOpen: (Day) -> Void

    init(onOpen: @escaping (Day) -> Void = { _ in }) {
        let cal = CNDate.calendar
        let today = Today.date
        _month = State(initialValue: cal.component(.month, from: today) - 1) // 0-indexed
        _year = State(initialValue: cal.component(.year, from: today))
        self.onOpen = onOpen
    }

    private static let monthNames = ["一","二","三","四","五","六","七","八","九","十","十一","十二"]
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

    private var eventsByDay: [Int: [Day]] {
        var map: [Int: [Day]] = [:]
        let cal = CNDate.calendar
        for d in store.days {
            let dt = d.date
            let dm = cal.component(.month, from: dt) - 1
            let dy = cal.component(.year, from: dt)
            let dd = cal.component(.day, from: dt)
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

    var body: some View {
        VStack(spacing: 0) {
            navBar
            monthSwitcher
            weekdayRow
            ScrollView(.vertical, showsIndicators: false) {
                grid
                if !eventsByDay.isEmpty {
                    SectionLabel(text: "本月日子")
                        .padding(.top, 22)
                        .padding(.bottom, 12)
                        .padding(.leading, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    monthList
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 96)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
    }

    private var navBar: some View {
        HStack {
            Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.ink).opacity(0)
            Spacer()
            Text("日历").font(Theme.serif(17, weight: .semibold))
            Spacer()
            Button("今天") {
                let cal = CNDate.calendar; let today = Today.date
                year = cal.component(.year, from: today)
                month = cal.component(.month, from: today) - 1
            }
            .font(Theme.sans(14, weight: .medium))
            .foregroundStyle(Theme.terracotta)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 8)
    }

    private var monthSwitcher: some View {
        HStack {
            Button {
                if month == 0 { month = 11; year -= 1 } else { month -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 36, height: 36)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(spacing: 2) {
                Text(verbatim: "\(year) 年 \(Self.monthNames[month])月")
                    .font(Theme.serif(28, weight: .semibold))
                Text(seasonLabel)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Button {
                if month == 11 { month = 0; year += 1 } else { month += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 36, height: 36)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var seasonLabel: String {
        let m = month + 1
        let season = (m >= 3 && m <= 5) ? "春"
            : (m >= 6 && m <= 8) ? "夏"
            : (m >= 9 && m <= 11) ? "秋" : "冬"
        return "\(Self.monthNames[month])月 · \(season)"
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Self.weekdayCN, id: \.self) { d in
                Text(d)
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private var grid: some View {
        let cal = CNDate.calendar
        let today = Today.date
        let isCurrentMonth = (cal.component(.year, from: today) == year)
            && (cal.component(.month, from: today) - 1 == month)
        let todayDay = cal.component(.day, from: today)

        let cells: [Int] = Array(0..<firstDow).map { _ in 0 } + Array(1...daysInMonth)
        let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return LazyVGrid(columns: cols, spacing: 4) {
            ForEach(cells.indices, id: \.self) { i in
                let d = cells[i]
                if d == 0 {
                    Color.clear.aspectRatio(1, contentMode: .fit)
                } else {
                    let events = eventsByDay[d] ?? []
                    let isToday = isCurrentMonth && d == todayDay
                    cellView(d: d, events: events, isToday: isToday)
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(d: Int, events: [Day], isToday: Bool) -> some View {
        let hasEvents = !events.isEmpty
        let cell = VStack(spacing: 2) {
            Text("\(d)")
                .font(Theme.sans(13, weight: isToday ? .semibold : .medium))
                .monospacedDigit()
                .foregroundStyle(isToday ? .white : (hasEvents ? Theme.ink : Theme.ink2))
            if hasEvents {
                HStack(spacing: 2) {
                    ForEach(0..<min(events.count, 3), id: \.self) { _ in
                        Circle()
                            .fill(isToday ? Color.white : Theme.terracotta)
                            .frame(width: 3, height: 3)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isToday ? Theme.terracotta : (hasEvents ? Theme.card : .clear))
        }
        .overlay {
            if hasEvents && !isToday {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.5)
            }
        }

        if hasEvents, let first = events.first {
            Button { onOpen(first) } label: { cell }
                .buttonStyle(.plain)
        } else {
            cell
        }
    }

    private var monthList: some View {
        VStack(spacing: 8) {
            ForEach(eventsByDay.keys.sorted(), id: \.self) { day in
                if let evts = eventsByDay[day] {
                    ForEach(evts, id: \.id) { e in
                        Button { onOpen(e) } label: {
                            HStack(spacing: 12) {
                                Text("\(day)")
                                    .font(Theme.serif(18, weight: .semibold))
                                    .foregroundStyle(Theme.terracotta)
                                    .monospacedDigit()
                                    .frame(width: 38)
                                PhotoTile(day: e, flat: true, cornerRadius: 10)
                                    .frame(width: 36, height: 36)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(e.title).font(Theme.sans(13, weight: .medium))
                                    Text(e.categoryLabel).font(Theme.sans(11)).foregroundStyle(Theme.muted)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Theme.hairline, lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
