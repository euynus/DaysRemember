import SwiftUI

private struct CurrentDayKey: EnvironmentKey {
    static var defaultValue: Date { CNDate.calendar.startOfDay(for: Today.date) }
}

extension EnvironmentValues {
    var currentDay: Date {
        get { self[CurrentDayKey.self] }
        set { self[CurrentDayKey.self] = newValue }
    }
}
