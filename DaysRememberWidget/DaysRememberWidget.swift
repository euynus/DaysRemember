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
        AppIntentConfiguration(kind: kind, intent: SelectWidgetDay.self, provider: DaysProvider()) { entry in
            DaysWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Theme.bg
                }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("时光 · 重要日子")
        .description("选择一个重要日子，或自动显示最近的日子。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Timeline

struct DaysEntry: TimelineEntry {
    var date: Date
    var day: Day?
    /// True when the store holds days but none are upcoming — lets the empty view
    /// distinguish "no days yet" from "nothing coming up".
    var hasAnyDays: Bool = false
    var selectionMissing: Bool = false
}

struct DaysProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DaysEntry {
        DaysEntry(date: Date(), day: SampleData.days.first, hasAnyDays: true)
    }

    func snapshot(for configuration: SelectWidgetDay, in context: Context) async -> DaysEntry {
        let entry = makeEntry(configuration: configuration, days: SharedStorage.loadDays(), asOf: Date())
        return context.isPreview && configuration.day == nil && entry.day == nil
            ? placeholder(in: context) : entry
    }

    func timeline(for configuration: SelectWidgetDay, in context: Context) async -> Timeline<DaysEntry> {
        let now = Date()
        let days = SharedStorage.loadDays()
        let entries = ([now] + CNDate.dayStarts(after: now, count: 7)).map {
            makeEntry(configuration: configuration, days: days, asOf: $0)
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func makeEntry(configuration: SelectWidgetDay, days: [Day], asOf today: Date) -> DaysEntry {
        let day = WidgetDay.resolve(in: days, selectedID: configuration.day?.id, today: today)
        return DaysEntry(date: today, day: day, hasAnyDays: !days.isEmpty,
                         selectionMissing: configuration.day != nil && day == nil)
    }
}

// MARK: - Entry view

struct DaysWidgetEntryView: View {
    let entry: DaysEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if let accessoryStyle {
                DayAccessoryWidget(day: entry.day, style: accessoryStyle, today: entry.date,
                                   selectionMissing: entry.selectionMissing, hasAnyDays: entry.hasAnyDays)
            } else if let day = entry.day {
                DayWidgetCard(day: day, size: cardSize, today: entry.date)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.title)
                        .foregroundStyle(Theme.accent)
                    Text(entry.selectionMissing ? String(localized: "日子已删除")
                         : entry.hasAnyDays ? String(localized: "暂无即将到来的日子") : String(localized: "还没有日子"))
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.ink2)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .widgetURL(entry.day.flatMap { URL(string: "daysremember://day/\($0.id)") }
                   ?? URL(string: "daysremember://home"))
    }

    private var accessoryStyle: DayAccessoryWidget.Style? {
        switch family {
        case .accessoryCircular: return .circular
        case .accessoryRectangular: return .rectangular
        case .accessoryInline: return .inline
        default: return nil
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
