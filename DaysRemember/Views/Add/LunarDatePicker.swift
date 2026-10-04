import SwiftUI

/// Edits a Gregorian draft; the parent owns presentation, cancellation and confirmation.
struct LunarDatePicker: View {
    @Binding var selection: Date

    private var lunar: Lunar.LunarDate { Lunar.pickerDate(for: selection) }

    var body: some View {
        let current = lunar
        Form {
            Section("农历日期") {
                Picker("农历年", selection: yearBinding) {
                    ForEach(Lunar.supportedYears, id: \.self) { year in
                        Text("\(String(year))年").tag(year)
                    }
                }
                .accessibilityIdentifier("lunarYearPicker")

                Picker("农历月", selection: monthBinding) {
                    ForEach(Lunar.months(in: current.year), id: \.self) { month in
                        Text(Lunar.monthCN(month.number, isLeap: month.isLeap)).tag(month)
                    }
                }
                .accessibilityIdentifier("lunarMonthPicker")

                if let count = Lunar.dayCount(year: current.year, month: current.month,
                                              isLeap: current.isLeap) {
                    Picker("农历日", selection: dayBinding) {
                        ForEach(1...count, id: \.self) { day in
                            Text(Lunar.dayCN(day)).tag(day)
                        }
                    }
                    .accessibilityIdentifier("lunarDayPicker")
                }
            }

            Section {
                Text("公历 \(CNDate.full(selection))")
                    .accessibilityIdentifier("lunarSolarDate")
            } footer: {
                if Lunar.supportedLunarDate(for: selection) == nil {
                    Text("仅支持农历 1900 至 2100 年。")
                }
            }
        }
        .pickerStyle(.menu)
        .scrollContentBackground(.hidden)
    }

    private var yearBinding: Binding<Int> {
        Binding(get: { lunar.year }, set: { year in
            var proposed = lunar
            proposed.year = year
            update(proposed)
        })
    }

    private var monthBinding: Binding<Lunar.Month> {
        Binding(get: { Lunar.Month(number: lunar.month, isLeap: lunar.isLeap) }, set: { month in
            var proposed = lunar
            proposed.month = month.number
            proposed.isLeap = month.isLeap
            update(proposed)
        })
    }

    private var dayBinding: Binding<Int> {
        Binding(get: { lunar.day }, set: { day in
            var proposed = lunar
            proposed.day = day
            update(proposed)
        })
    }

    private func update(_ proposed: Lunar.LunarDate) {
        let clamped = Lunar.clamped(proposed)
        // Preserve the exact draft, including its time, when its lunar day is unchanged.
        guard clamped != Lunar.supportedLunarDate(for: selection),
              let date = Lunar.solarDate(for: clamped) else { return }
        selection = date
    }
}
