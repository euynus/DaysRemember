import WidgetKit

struct DaysEntry: TimelineEntry {
    var date: Date
    var day: Day?
    var selectionMissing: Bool = false
    /// The day's category colour, custom categories included.
    var colorToken: CategoryColorToken? = nil
}
