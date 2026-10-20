import SwiftUI

/// The dates around this one: past and next anniversaries, round numbers, or the days left.
struct DetailTimeline: View {
    @Environment(\.currentDay) private var today
    let day: Day
    let info: DayInfo
    let tint: Color
    let ink: Color

    private struct Node: Identifiable {
        // Dates never repeat within one timeline, and stay put across updates, unlike a fresh UUID.
        var id: Date { date }
        let title: String
        let date: Date
        let relative: String
    }

    var body: some View {
        let (title, nodes, progress) = timelineContent(day: day, info: info)
        if !nodes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(Theme.sans(15, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                if let progress {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressCapsule(fraction: progress.fraction, track: tint, fill: ink)
                        HStack {
                            Text(progress.leading)
                            Spacer(minLength: 8)
                            Text(progress.trailing)
                        }
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.muted)
                    }
                }
                VStack(spacing: 0) {
                    ForEach(nodes) { node in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(node.title)
                                    .font(Theme.sans(15, weight: .heavy))
                                    .foregroundStyle(Theme.ink)
                                Text(String(localized: "\(CNDate.full(node.date)) \(CNDate.weekday(node.date))", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                                    .font(Theme.sans(12))
                                    .foregroundStyle(Theme.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Text(node.relative)
                                .font(Theme.sans(13, weight: .heavy))
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Theme.bg, in: Capsule())
                        }
                        .padding(.vertical, 10)
                        .overlay(alignment: .top) { RowDivider() }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private struct Progress {
        let fraction: Double
        let leading: String
        let trailing: String
    }

    private func relative(_ date: Date) -> String {
        let n = CNDate.daysBetween(today, date)
        if n == 0 { return String(localized: "今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale) }
        return n > 0 ? String(localized: "\(n) 天后", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : String(localized: "\(-n) 天前", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    /// The note under 那一天 for a one-time day: how long ago it was, or 今天 on the day itself.
    nonisolated static func sinceTheDay(_ info: DayInfo) -> String {
        info.isToday ? String(localized: "今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : String(localized: "已过 \(info.days) 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    private func timelineContent(day: Day, info: DayInfo) -> (String, [Node], Progress?) {
        let cal = CNDate.calendar
        let todayStart = cal.startOfDay(for: today)
        if day.recurring {
            var nodes: [Node] = []
            if let elapsed = info.elapsedDays, elapsed > 0 {
                nodes.append(Node(title: String(localized: "那一天", bundle: AppLocalization.bundle, locale: AppLocalization.locale), date: day.date,
                                  relative: String(localized: "已过 \(elapsed) 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)))
            }
            let year = cal.component(.year, from: todayStart)
            let previous = ((year - 1)...year)
                .flatMap { DayInfo.occurrences(of: day, inGregorianYear: $0) }
                .filter { $0 < todayStart && $0 > cal.startOfDay(for: day.date) }
                .max()
            if let previous {
                nodes.append(Node(title: String(localized: "上一次", bundle: AppLocalization.bundle, locale: AppLocalization.locale), date: previous, relative: relative(previous)))
            }
            let nextTitle = info.anniversaryNumber.map { $0 > 0 ? String(localized: "第\($0)周年", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : nil } ?? nil
            nodes.append(Node(title: nextTitle ?? String(localized: "这一次", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                              date: info.displayDate, relative: relative(info.displayDate)))
            var progress: Progress?
            if let previous {
                let since = CNDate.daysBetween(previous, todayStart)
                let span = max(1, CNDate.daysBetween(previous, info.displayDate))
                progress = Progress(fraction: Double(since) / Double(span),
                                    leading: String(localized: "距上次 \(since) 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                                    trailing: nextTitle ?? "")
            }
            return (String(localized: "每一年", bundle: AppLocalization.bundle, locale: AppLocalization.locale), nodes, progress)
        }
        if info.isPast || info.isToday {
            guard let milestone = Milestone.next(after: day.date, today: today) else { return ("", [], nil) }
            let nodes = [
                Node(title: String(localized: "那一天", bundle: AppLocalization.bundle, locale: AppLocalization.locale), date: day.date,
                     relative: Self.sinceTheDay(info)),
                Node(title: milestone.title, date: milestone.date, relative: relative(milestone.date)),
            ]
            let progress = Progress(fraction: milestone.progress, leading: CNDate.full(day.date),
                                    trailing: DayCardText.milestone(milestone))
            return (String(localized: "整数纪念", bundle: AppLocalization.bundle, locale: AppLocalization.locale), nodes, progress)
        }
        // A one-time day ahead: the round numbers left on the way.
        let nodes = [100, 50, 30, 7]
            .filter { info.days > $0 }
            .compactMap { left -> Node? in
                guard let date = cal.date(byAdding: .day, value: -left, to: info.displayDate) else { return nil }
                return Node(title: String(localized: "还剩 \(left) 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                            date: date, relative: relative(date))
            }
        return (String(localized: "倒数节点", bundle: AppLocalization.bundle, locale: AppLocalization.locale), Array(nodes.prefix(3)), nil)
    }
}
