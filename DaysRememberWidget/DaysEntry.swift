import WidgetKit

struct DaysEntry: TimelineEntry {
    var date: Date
    var day: Day?
    var selectionMissing: Bool = false
    /// The day's category colour, custom categories included.
    var colorToken: CategoryColorToken? = nil

    /// The entry's moment on the app calendar, which countdowns count from.
    var today: Date { CNDate.appTime(date) }
}
