import SwiftUI
import WidgetKit

/// Shared by WidgetKit and the in-app gallery so previews use the real layout.
struct DayWidgetCard: View {
    enum Size { case small, medium, large }
    let day: Day
    let size: Size
    var today: Date = Today.date
    /// The day's category colour; nil resolves it from the system categories alone.
    var colorToken: CategoryColorToken? = nil
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var info: DayInfo { DayInfo.compute(day, today: today) }

    var body: some View {
        Group {
            switch size {
            case .small:
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 4) {
                        date
                        Spacer(minLength: 0)
                        cover
                            .frame(width: 58, height: 58)
                    }
                    Spacer(minLength: 2)
                    countdown
                    title
                }
            case .medium:
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        eyebrow
                        title
                        Spacer(minLength: 0)
                        countdown
                        date
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    cover
                        .frame(width: 112)
                }
            case .large:
                VStack(alignment: .leading, spacing: 12) {
                    HStack { eyebrow; Spacer(); date }
                    cover
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    title
                    countdown
                }
            }
        }
        .padding(size == .small ? 14 : 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Tinted, clear and StandBy modes remove the container background and draw the rest in one
        // tint by opacity, so an opaque card of its own would be a solid block there.
        .background(renderingMode == .fullColor ? palette.tint : Color.clear)
        // A widget has fixed physical bounds, unlike the surrounding app controls.
        .dynamicTypeSize(...DynamicTypeSize.large)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    /// The card's pastel and the colour drawn on it; count-up days are lavender.
    private var palette: (tint: Color, ink: Color) {
        if info.isPast { return (Theme.memory, Theme.memoryInk) }
        let token = colorToken ?? CategoryDefinition.colorToken(for: day, in: CategoryDefinition.system)
        return (token.soft, token.color)
    }

    /// A photo keeps its own tile; a preset is the flat illustration on the pastel.
    @ViewBuilder
    private var cover: some View {
        if day.photoData != nil {
            photo
        } else {
            Image(day.photo.flatAssetName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var photo: some View {
        // WidgetKit archives the source bitmap, not just the displayed frame.
        var tile = PhotoTile(day: day, flat: true, cornerRadius: 14)
        tile.maximumPixelSize = size == .small ? 512 : 720
        return tile
    }

    private var eyebrow: some View {
        Text(info.isToday ? String(localized: "就是今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
             : info.isPast ? String(localized: "时光记忆", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "即将到来", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            .font(Theme.sans(11, weight: .heavy))
            .foregroundStyle(palette.ink)
            .widgetAccentable()
    }

    private var title: some View {
        Text(day.title)
            .font(Theme.sans(size == .small ? 14 : 17, weight: .heavy))
            .foregroundStyle(Theme.ink)
            .lineLimit(size == .medium ? 2 : 1)
            .minimumScaleFactor(0.7)
    }

    private var countdown: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(info.isToday ? String(localized: "今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : info.days.formatted(.number.locale(AppLocalization.locale)))
                .font(Theme.number(info.isToday ? 26 : size == .small ? 42 : 52))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                // Takes the accent tint, as it takes the accent colour in full colour.
                .widgetAccentable()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if !info.isToday {
                Text(info.isPast
                     ? String(localized: "widget.daysAgoUnit", defaultValue: "天前", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                     : String(localized: "widget.daysLeftUnit", defaultValue: "天后", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private var date: some View {
        Text(CNDate.short(info.isPast ? day.date : info.displayDate))
            .font(Theme.sans(11, weight: .bold))
            .foregroundStyle(palette.ink)
    }

    private var accessibilitySummary: String {
        let info = self.info
        let countdown = info.isToday ? String(localized: "就是今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : info.isPast ? String(localized: "\(info.days)天前", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "\(info.days)天后", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        return String(localized: "\(day.title)，\(countdown)，\(CNDate.full(info.displayDate))", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }
}

/// A Home Screen widget with no day to show: none yet, or its chosen day was deleted.
struct DayWidgetEmptyState: View {
    let selectionMissing: Bool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.title)
                .foregroundStyle(Theme.ink2)
            Text(selectionMissing
                 ? String(localized: "日子已删除", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                 : String(localized: "还没有日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                .font(Theme.sans(13))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
        }
        // A widget has fixed physical bounds, as for the card.
        .dynamicTypeSize(...DynamicTypeSize.large)
    }
}
