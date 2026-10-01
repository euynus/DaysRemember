import WidgetKit
import SwiftUI
import UIKit

@main
struct DaysRememberWidgetBundle: WidgetBundle {
    var body: some Widget {
        DaysRememberWidget()
    }
}

struct DaysRememberWidget: Widget {
    let kind: String = "DaysRememberWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DaysProvider()) { entry in
            DaysWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Theme.bg
                }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("时光 · 即将到来")
        .description("把最近一个重要的日子放到主屏。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Timeline

struct DaysEntry: TimelineEntry {
    var date: Date
    var day: Day?
    /// True when the store holds days but none are upcoming — lets the empty view
    /// distinguish "no days yet" from "nothing coming up".
    var hasAnyDays: Bool = false
}

struct DaysProvider: TimelineProvider {
    func placeholder(in context: Context) -> DaysEntry {
        DaysEntry(date: Date(), day: SampleData.days.first, hasAnyDays: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (DaysEntry) -> Void) {
        completion(makeEntry(asOf: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DaysEntry>) -> Void) {
        let now = Date()
        let entry = makeEntry(asOf: now)
        // Refresh at the next midnight so the countdown ticks down.
        let nextMidnight = CNDate.calendar.nextDate(after: now,
                                                    matching: DateComponents(hour: 0, minute: 0),
                                                    matchingPolicy: .strict) ?? now.addingTimeInterval(60 * 60 * 6)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func makeEntry(asOf today: Date) -> DaysEntry {
        let raw = SharedStorage.defaults.data(forKey: "days.v1")
        let days = raw.flatMap { try? JSONDecoder().decode([Day].self, from: $0) } ?? SampleData.days
        let nearest = days
            .compactMap { day -> (Day, Int)? in
                let info = DayInfo.compute(day, today: today)
                return (info.isPast || info.days > 365) ? nil : (day, info.days)
            }
            .min { $0.1 < $1.1 }?
            .0
        return DaysEntry(date: today, day: nearest, hasAnyDays: !days.isEmpty)
    }
}

// MARK: - Entry view

struct DaysWidgetEntryView: View {
    let entry: DaysEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let day = entry.day {
            DayWidgetCard(day: day, size: cardSize, today: entry.date)
                .widgetURL(URL(string: "daysremember://day/\(day.id)"))
        } else {
            VStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.title)
                    .foregroundStyle(Theme.accent)
                Text(entry.hasAnyDays ? "暂无即将到来的日子" : "还没有日子")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.ink2)
            }
        }
    }

    private var cardSize: DayWidgetCard.Size {
        switch family {
        case .systemMedium: return .medium
        case .systemLarge: return .large
        default: return .small
        }
    }
}
