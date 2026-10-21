import AppIntents

/// Opens the app on a new day's editor, from Shortcuts, Siri, Spotlight or the Control Center
/// button. Shared with the widget extension, which offers the control.
struct NewDayIntent: AppIntent {
    static let title = LocalizedStringResource("intent.newDay.title", defaultValue: "新建日子")
    static let description = IntentDescription(LocalizedStringResource("intent.newDay.description",
                                                                       defaultValue: "打开「时光」，记下一个新的日子。"))
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        PendingLink.request(PendingLink.newDay)
        return .result()
    }
}
