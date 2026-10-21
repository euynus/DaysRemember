import SwiftUI
import WidgetKit

struct DaysWidgetEntryView: View {
    let entry: DaysEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if let accessoryStyle {
                DayAccessoryWidget(day: entry.day, style: accessoryStyle, today: entry.today,
                                   selectionMissing: entry.selectionMissing)
            } else if let day = entry.day {
                DayWidgetCard(day: day, size: cardSize, today: entry.today, colorToken: entry.colorToken)
            } else {
                DayWidgetEmptyState(selectionMissing: entry.selectionMissing)
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
