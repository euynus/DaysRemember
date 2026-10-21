import AppIntents

/// Opens a day's detail, from Shortcuts, Siri or Spotlight.
struct OpenDayIntent: OpenIntent {
    static let title = LocalizedStringResource("intent.openDay.title", defaultValue: "打开日子")
    static let description = IntentDescription(LocalizedStringResource("intent.openDay.description",
                                                                       defaultValue: "在「时光」里打开一个日子。"))

    @Parameter(title: LocalizedStringResource("widget.day", defaultValue: "日子"))
    var target: WidgetDay

    func perform() async throws -> some IntentResult {
        PendingLink.request(DeepLink.url(forDayID: target.id))
        return .result()
    }
}
