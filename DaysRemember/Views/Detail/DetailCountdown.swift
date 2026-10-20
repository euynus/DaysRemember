import SwiftUI

/// The big count, which a tap moves through days, weeks, months and hours, and its unit chips.
struct DetailCountdown: View {
    @Environment(\.currentDay) private var today
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let day: Day
    let info: DayInfo
    /// Owned by the detail, which goes back to days when another day opens.
    @Binding var unit: CountdownUnit

    var body: some View {
        let countdownLabel = info.isToday ? String(localized: "就是今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : info.isPast ? String(localized: "\(info.days) 天前", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : String(localized: "\(info.days) 天后", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        let other = info.isPast ? day.date : info.displayDate
        let breakdown = CountdownBreakdown.make(unit, between: today, and: other)
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                guard !info.isToday else { return }
                let all = CountdownUnit.allCases
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                    unit = all[(all.firstIndex(of: unit)! + 1) % all.count]
                }
            } label: {
                Group {
                    if info.isToday {
                        Text("今天")
                            .numberFont(64)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                    } else if dynamicTypeSize.isAccessibilitySize {
                        // The number gets a line of its own, so a long count shrinks to fit the width
                        // instead of being cut off beside its label and unit.
                        VStack(alignment: .leading, spacing: 2) {
                            CountLabel(info: info)
                            countNumber(breakdown)
                                .lineLimit(1)
                                .minimumScaleFactor(0.2)
                            Text(unitText(breakdown))
                                .font(Theme.sans(18, weight: .heavy))
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            CountLabel(info: info)
                            countNumber(breakdown)
                            Text(unitText(breakdown))
                                .font(Theme.sans(18, weight: .heavy))
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(Theme.ink)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(countdownLabel)
            .accessibilityValue(info.isToday ? "" : "\(breakdown.value.formatted(.number.locale(AppLocalization.locale))) \(unitText(breakdown))")
            .accessibilityHint(info.isToday ? "" : String(localized: "轻点切换单位", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            .accessibilityIdentifier("detail.countdown")
            if !info.isToday { unitPicker }
        }
        .padding(.horizontal, 4)
    }

    private func countNumber(_ breakdown: CountdownBreakdown) -> some View {
        Text(breakdown.value, format: .number)
            .numberFont(breakdown.value >= 1_000 ? 84 : 108)
            .monospacedDigit()
            .contentTransition(.numericText())
    }

    private var unitPicker: some View {
        HStack(spacing: 6) {
            if !dynamicTypeSize.isAccessibilitySize {
                Text("轻点数字切换")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.muted)
            }
            ForEach(CountdownUnit.allCases, id: \.self) { value in
                Button { unit = value } label: {
                    Text(unitName(value))
                        .font(Theme.sans(12, weight: value == unit ? .heavy : .medium))
                        .foregroundStyle(value == unit ? Color.white : Theme.ink2)
                        .padding(.horizontal, 10)
                        // The pill itself is at least 44pt wide, so the gaps between chips stay even.
                        .frame(minWidth: 44, minHeight: 26)
                        .background(value == unit ? Theme.ink : Theme.bg2, in: Capsule())
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(value == unit ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        // Fixed chips, like the editor's action bar, stop growing at XXXL.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func unitName(_ unit: CountdownUnit) -> String {
        switch unit {
        case .days: return String(localized: "detail.unit.days", defaultValue: "天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .weeks: return String(localized: "detail.unit.weeks", defaultValue: "周", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .months: return String(localized: "detail.unit.months", defaultValue: "月", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .hours: return String(localized: "detail.unit.hours", defaultValue: "小时", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
    }

    /// The unit after the big number, with leftover days for weeks and months.
    private func unitText(_ breakdown: CountdownBreakdown) -> String {
        let rest = breakdown.remainderDays ?? 0
        switch unit {
        case .days:
            return String(localized: "countdown.days", defaultValue: "\(breakdown.value)天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .weeks:
            return rest == 0 ? String(localized: "detail.weeksOnly", defaultValue: "周", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                : String(localized: "周 \(rest) 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .months:
            return rest == 0 ? String(localized: "detail.monthsOnly", defaultValue: "个月", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                : String(localized: "个月 \(rest) 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .hours:
            return String(localized: "detail.hoursUnit", defaultValue: "小时", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
    }
}
