import WidgetKit
import SwiftUI

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
        .description("选择一个重要日子，不选时显示置顶或最近的日子。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
