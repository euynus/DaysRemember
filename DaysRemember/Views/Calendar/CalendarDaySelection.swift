import Foundation

struct CalendarDaySelection: Identifiable {
    let date: Date

    var id: Date { date }

    init(date: Date) {
        self.date = CNDate.calendar.startOfDay(for: date)
    }

    func events(in days: [Day]) -> [Day] {
        let calendar = CNDate.calendar
        let year = calendar.component(.year, from: date)
        return days.filter { day in
            DayInfo.occurrences(of: day, inGregorianYear: year).contains(date)
        }
    }
}
