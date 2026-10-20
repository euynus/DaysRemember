enum AppTab: String, Hashable {
    case home, calendar, me

    /// `--tab` values, including the old categories and reminders tabs, which now live in 我的.
    init?(argument: String) {
        switch argument {
        case "categories", "notifications", "settings": self = .me
        default: self.init(rawValue: argument)
        }
    }
}
