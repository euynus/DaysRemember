import SwiftUI

/// Shared by WidgetKit and the in-app gallery so previews use the real layout.
struct DayWidgetCard: View {
    enum Size { case small, medium, large }
    let day: Day
    let size: Size
    var today: Date = Today.date

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
        .background(Theme.card)
        // A widget has fixed physical bounds, unlike the surrounding app controls.
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    private var photo: some View {
        // WidgetKit archives the source bitmap, not just the displayed frame.
        var tile = PhotoTile(day: day, flat: true, cornerRadius: 2)
        tile.maximumPixelSize = size == .small ? 512 : 720
        return tile
    }

    private var eyebrow: some View {
        Text(info.isToday ? "就是今天" : info.isPast ? "时光记忆" : "即将到来")
            .font(Theme.sans(11, weight: .semibold))
            .foregroundStyle(Theme.accent)
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
            Text(info.isToday ? "今天" : "\(info.days)")
                .font(info.isToday ? Theme.sans(24) : Theme.number(size == .small ? 34 : 52))
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if !info.isToday {
                Text(info.isPast ? "天前" : "天后")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.ink2)
            }
        }
    }

    private var date: some View {
        Text(CNDate.short(info.displayDate))
            .font(Theme.sans(11))
            .foregroundStyle(Theme.ink2)
    }
}
