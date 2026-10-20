import SwiftUI

/// The month and year, which return to this month when tapped, and the month arrows.
struct CalendarMonthHeader: View {
    let monthDate: Date
    let isShowingCurrentMonth: Bool
    var onShowMonth: (_ offset: Int) -> Void = { _ in }
    var onShowCurrentMonth: () -> Void = {}

    var body: some View {
        HStack(alignment: .bottom) {
            // Tapping the title jumps back to the current month (preserves the old
            // "今天" jump without a separate control).
            Button(action: onShowCurrentMonth) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(CNDate.year(monthDate))
                        .font(Theme.sans(13, weight: .bold))
                        .foregroundStyle(Theme.muted)
                    Text(CNDate.month(monthDate))
                        .font(Theme.sans(30, weight: .heavy, relativeTo: .largeTitle))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "\(CNDate.year(monthDate)) \(CNDate.month(monthDate))，回到本月", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                FAB(systemName: "chevron.left", size: 40, iconSize: 15) { onShowMonth(-1) }
                    .accessibilityLabel("上个月")
                if !isShowingCurrentMonth {
                    Button(action: onShowCurrentMonth) {
                        Text("今天")
                            .font(Theme.sans(14, weight: .heavy))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 40)
                            .background(Theme.ink, in: Capsule())
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(PressScale(scale: 0.94))
                    .accessibilityIdentifier("calendar.today")
                }
                FAB(systemName: "chevron.right", size: 40, iconSize: 15) { onShowMonth(1) }
                    .accessibilityLabel("下个月")
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.bottom, 10)
    }
}
