import SwiftUI

/// The rounded count and its unit, or 今天.
struct CountValue: View {
    let info: DayInfo
    let size: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            if info.isToday {
                Text("今天")
                    .numberFont(size * 0.62)
            } else {
                Text(info.days, format: .number)
                    .numberFont(size)
                    .monospacedDigit()
                Text(String(localized: "countdown.days", defaultValue: "\(info.days)天", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                    .font(Theme.sans(14, weight: .bold))
            }
        }
        .foregroundStyle(Theme.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}
