import SwiftUI

/// How many days there are, ahead and behind; the total opens every day.
struct MeStats: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let total: Int
    let upcoming: Int
    let past: Int

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            NavigationLink(value: CategoryRoute.all) {
                statCard(total, label: String(localized: "个日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                         tint: Theme.card)
            }
            .buttonStyle(PressableTileStyle())
            .accessibilityIdentifier("me.allDays")
            statCard(upcoming, label: String(localized: "home.face.upcoming", defaultValue: "将至", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                     tint: Theme.noteYellow)
            statCard(past, label: String(localized: "home.face.past", defaultValue: "已过", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                     tint: Theme.memory)
        }
    }

    private func statCard(_ value: Int, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value, format: .number)
                .numberFont(36)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(Theme.sans(12))
                .foregroundStyle(Theme.ink2)
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .bottomLeading)
        .background(tint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
