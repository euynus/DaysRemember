import SwiftUI
import WidgetKit

/// The next few days at a glance, pinned days first.
struct DaysListWidget: Widget {
    static let kind = "DaysListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DaysListProvider()) { entry in
            DaysListWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Theme.bg
                }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("时光 · 日子列表")
        .description("一眼浏览接下来的多个重要日子，置顶事项优先排列。")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct DaysListWidgetView: View {
    let entry: DaysListEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        DayListWidgetCard(days: entry.days, large: family == .systemLarge, today: entry.today,
                          colorTokens: entry.colorTokens)
            .environment(\.locale, AppLocalization.locale)
            .widgetURL(URL(string: "daysremember://home"))
    }
}
