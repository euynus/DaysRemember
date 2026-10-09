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
    var selectionMissing: Bool = false
}

struct DaysProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DaysEntry {
        DaysEntry(date: Date(), day: SampleData.days.first)
    }

    func snapshot(for configuration: SelectWidgetDay, in context: Context) async -> DaysEntry {
        var photos = PhotoLoader(library: SharedStorage.loadLibrary(), family: context.family)
        let entry = makeEntry(configuration: configuration, photos: &photos, asOf: Date())
        return context.isPreview && configuration.day == nil && entry.day == nil
            ? placeholder(in: context) : entry
    }

    func timeline(for configuration: SelectWidgetDay, in context: Context) async -> Timeline<DaysEntry> {
        let now = Date()
        var photos = PhotoLoader(library: SharedStorage.loadLibrary(), family: context.family)
        let entries = ([now] + CNDate.dayStarts(after: now, count: 7)).map {
            makeEntry(configuration: configuration, photos: &photos, asOf: $0)
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func makeEntry(configuration: SelectWidgetDay, photos: inout PhotoLoader, asOf today: Date) -> DaysEntry {
        let days = photos.library.days
        let day = WidgetDay.resolve(in: days, selectedID: configuration.day?.id, today: today)
        return DaysEntry(date: today, day: day.map { photos.load($0) },
                         selectionMissing: configuration.day != nil && day == nil)
    }

    /// Reads each displayed photo once per timeline; Lock Screen layouts never show photos.
    private struct PhotoLoader {
        let library: SharedStorage.Library
        let showsPhotos: Bool
        private var loaded: [String: Day] = [:]

        init(library: SharedStorage.Library, family: WidgetFamily) {
            self.library = library
            showsPhotos = [.systemSmall, .systemMedium, .systemLarge].contains(family)
        }

        mutating func load(_ day: Day) -> Day {
            guard showsPhotos else { return day }
            if let cached = loaded[day.id] { return cached }
            let withPhoto = library.withPhoto(day)
            loaded[day.id] = withPhoto
            return withPhoto
        }
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
                                   selectionMissing: entry.selectionMissing)
            } else if let day = entry.day {
                DayWidgetCard(day: day, size: cardSize, today: entry.date)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.title)
                        .foregroundStyle(Theme.accent)
                    Text(entry.selectionMissing
                         ? String(localized: "日子已删除", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                         : String(localized: "还没有日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.ink2)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .environment(\.locale, AppLocalization.locale)
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
