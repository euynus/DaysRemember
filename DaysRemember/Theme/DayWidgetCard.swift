import SwiftUI
import WidgetKit

/// Shared by WidgetKit and the in-app gallery so previews use the real layout.
struct DayWidgetCard: View {
    enum Size { case small, medium, large }
    let day: Day
    let size: Size
    var today: Date = Today.date
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var info: DayInfo { DayInfo.compute(day, today: today) }

    var body: some View {
        Group {
            switch size {
            case .small:
                VStack(alignment: .leading, spacing: 8) {
                    photo
                        .frame(height: 46)
                    title
                    countdown
                }
            case .medium:
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        eyebrow
                        title
                        Spacer(minLength: 0)
                        countdown
                        date
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    photo
                        .frame(width: 106)
                }
            case .large:
                VStack(alignment: .leading, spacing: 14) {
                    HStack { eyebrow; Spacer(); date }
                    photo
                    title
                    countdown
                }
            }
        }
        .padding(size == .small ? 12 : 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Tinted, clear and StandBy modes remove the container background and draw the rest in one
        // tint by opacity, so an opaque card of its own would be a solid block there.
        .background(renderingMode == .fullColor ? Theme.card : Color.clear)
        // A widget has fixed physical bounds, unlike the surrounding app controls.
        .dynamicTypeSize(...DynamicTypeSize.large)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var photo: some View {
        // WidgetKit archives the source bitmap, not just the displayed frame.
        var tile = PhotoTile(day: day, flat: true, cornerRadius: 2)
        tile.maximumPixelSize = size == .small ? 512 : 720
        return tile
    }

    private var eyebrow: some View {
        Text(info.isToday ? String(localized: "就是今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
             : info.isPast ? String(localized: "时光记忆", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "即将到来", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            .font(Theme.sans(11, weight: .semibold))
            .foregroundStyle(Theme.accent)
            .widgetAccentable()
    }

    private var title: some View {
        Text(day.title)
            .font(Theme.sans(size == .small ? 13 : 17, weight: .medium))
            .foregroundStyle(Theme.ink)
            .lineLimit(size == .medium ? 2 : 1)
            .minimumScaleFactor(0.7)
    }

    private var countdown: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(info.isToday ? String(localized: "今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : "\(info.days)")
                .font(info.isToday ? Theme.sans(24) : Theme.number(size == .small ? 34 : 52))
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
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
        Text(CNDate.short(info.displayDate))
            .font(Theme.sans(11))
            .foregroundStyle(Theme.ink2)
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
                .foregroundStyle(Theme.accent)
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
