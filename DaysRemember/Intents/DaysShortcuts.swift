import AppIntents

/// The phrases Siri and Spotlight offer without any setup; translated in AppShortcuts.xcstrings.
struct DaysShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: DaysUntilIntent(), phrases: [
            "\(.applicationName)里\(\.$day)还有几天",
            "用\(.applicationName)看\(\.$day)还有几天",
        ], shortTitle: LocalizedStringResource("intent.daysUntil.short", defaultValue: "还有几天"),
           systemImageName: "calendar.badge.clock")
        AppShortcut(intent: NewDayIntent(), phrases: [
            "用\(.applicationName)新建日子",
            "在\(.applicationName)里记一个日子",
        ], shortTitle: LocalizedStringResource("intent.newDay.title", defaultValue: "新建日子"),
           systemImageName: "calendar.badge.plus")
        AppShortcut(intent: OpenDayIntent(), phrases: [
            "在\(.applicationName)里打开\(\.$target)",
        ], shortTitle: LocalizedStringResource("intent.openDay.title", defaultValue: "打开日子"),
           systemImageName: "calendar")
    }
}
