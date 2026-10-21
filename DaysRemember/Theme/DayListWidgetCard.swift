import SwiftUI
import WidgetKit

/// The days-list widget: the next few days, pinned first, each on its category's pastel. Shared
/// by WidgetKit and the in-app gallery so previews use the real layout.
struct DayListWidgetCard: View {
    let days: [Day]
    /// A large widget lists six days, a medium one three.
    let large: Bool
    var today: Date = Today.date
    /// Category colours by day ID, custom categories included; missing ones use the system's.
    var colorTokens: [String: CategoryColorToken] = [:]
    @Environment(\.widgetRenderingMode) private var renderingMode

    nonisolated static func capacity(large: Bool) -> Int { large ? 6 : 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: large ? 8 : 6) {
            if days.isEmpty {
                Text(String(localized: "还没有日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                    .font(Theme.sans(15, weight: .heavy))
                    .foregroundStyle(Theme.ink2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(days.prefix(Self.capacity(large: large))) { day in
                    Link(destination: URL(string: "daysremember://day/")!.appending(path: day.id)) { row(day) }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // A widget has fixed physical bounds, unlike the surrounding app controls.
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    private func row(_ day: Day) -> some View {
        let info = DayInfo.compute(day, today: today)
        let token = colorTokens[day.id] ?? CategoryDefinition.colorToken(for: day, in: CategoryDefinition.system)
        let tint = info.isPast ? Theme.memory : token.soft
        let ink = info.isPast ? Theme.memoryInk : token.color
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(day.title)
                    .font(Theme.sans(14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(CNDate.short(info.isPast ? day.date : info.displayDate))
                    .font(Theme.sans(11, weight: .bold))
                    .foregroundStyle(ink)
                    .widgetAccentable()
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(info.isToday ? String(localized: "今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                     : info.days.formatted(.number.locale(AppLocalization.locale)))
                    .font(Theme.number(info.isToday ? 17 : 24))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .widgetAccentable()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if !info.isToday {
                    Text(info.isPast
                         ? String(localized: "widget.daysAgoUnit", defaultValue: "天前", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                         : String(localized: "widget.daysLeftUnit", defaultValue: "天后", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                        .font(Theme.sans(10))
                        .foregroundStyle(Theme.ink2)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: large ? 46 : 38)
        // Tinted and clear Home Screens draw in one tint by opacity; a filled row would be a block.
        .background(renderingMode == .fullColor ? tint : Color.clear,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(day.title)，\(countdown(info))，\(CNDate.full(info.displayDate))",
                                   bundle: AppLocalization.bundle, locale: AppLocalization.locale))
    }

    private func countdown(_ info: DayInfo) -> String {
        info.isToday ? String(localized: "就是今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : info.isPast ? String(localized: "\(info.days)天前", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : String(localized: "\(info.days)天后", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }
}
