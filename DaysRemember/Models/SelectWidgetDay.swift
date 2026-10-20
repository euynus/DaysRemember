import AppIntents

struct SelectWidgetDay: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "选择日子"
    static let description = IntentDescription("不选择时，自动显示最近的日子。")

    @Parameter(title: LocalizedStringResource("widget.day", defaultValue: "日子"))
    var day: WidgetDay?
}
