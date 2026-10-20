import SwiftUI

extension EnvironmentValues {
    @Entry var currentDay: Date = CNDate.calendar.startOfDay(for: Today.date)
}
