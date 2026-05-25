import WidgetKit
import SwiftUI
import UIKit

@main
struct DaysRememberWidgetBundle: WidgetBundle {
    var body: some Widget {
        DaysRememberWidget()
    }
}

struct DaysRememberWidget: Widget {
    let kind: String = "DaysRememberWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DaysProvider()) { entry in
            DaysWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Theme.bg
                }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("时光 · 即将到来")
        .description("把最近一个重要的日子放到主屏。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Timeline

struct DaysEntry: TimelineEntry {
    var date: Date
    var day: Day?
    /// True when the store holds days but none are upcoming — lets the empty view
    /// distinguish "no days yet" from "nothing coming up".
    var hasAnyDays: Bool = false
}

struct DaysProvider: TimelineProvider {
    func placeholder(in context: Context) -> DaysEntry {
        DaysEntry(date: Date(), day: SampleData.days.first, hasAnyDays: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (DaysEntry) -> Void) {
        completion(makeEntry(asOf: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DaysEntry>) -> Void) {
        let now = Date()
        let entry = makeEntry(asOf: now)
        // Refresh at the next midnight so the countdown ticks down.
        let nextMidnight = CNDate.calendar.nextDate(after: now,
                                                    matching: DateComponents(hour: 0, minute: 0),
                                                    matchingPolicy: .strict) ?? now.addingTimeInterval(60 * 60 * 6)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func makeEntry(asOf today: Date) -> DaysEntry {
        let raw = SharedStorage.defaults.data(forKey: "days.v1")
        let days = raw.flatMap { try? JSONDecoder().decode([Day].self, from: $0) } ?? SampleData.days
        let nearest = days
            .compactMap { day -> (Day, Int)? in
                let info = DayInfo.compute(day, today: today)
                return (info.isPast || info.days > 365) ? nil : (day, info.days)
            }
            .min { $0.1 < $1.1 }?
            .0
        return DaysEntry(date: today, day: nearest, hasAnyDays: !days.isEmpty)
    }
}

// MARK: - Entry view

struct DaysWidgetEntryView: View {
    let entry: DaysEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let day = entry.day {
            switch family {
            case .systemSmall: WidgetSmall(day: day)
            case .systemMedium: WidgetMedium(day: day)
            case .systemLarge: WidgetLarge(day: day)
            default: WidgetSmall(day: day)
            }
        } else {
            ZStack {
                LinearGradient(
                    colors: [Theme.card, Theme.terracottaSoft],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 6) {
                    Text("时光")
                        .font(Theme.serif(20, weight: .semibold))
                        .foregroundStyle(Theme.terracotta)
                    Text(entry.hasAnyDays ? "暂无即将到来的日子" : "还没有日子")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
    }
}

private struct WidgetSmall: View {
    let day: Day
    var body: some View {
        let info = DayInfo.compute(day)
        ZStack {
            WidgetPhotoTile(day: day, scrim: true)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("时光")
                        .font(Theme.sans(10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(Color.white.opacity(0.82))
                    Spacer()
                    Circle()
                        .fill(Color.white.opacity(0.76))
                        .frame(width: 6, height: 6)
                }

                Spacer(minLength: 4)

                Text(day.title)
                    .font(Theme.sans(12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(info.days)")
                        .font(Theme.serif(46, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.75)
                    Text(label(info))
                        .font(Theme.sans(11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.82))
                        .lineLimit(1)
                }
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct WidgetMedium: View {
    let day: Day
    var body: some View {
        let info = DayInfo.compute(day)
        HStack(spacing: 14) {
            VStack(alignment: .leading) {
                Text("即将到来")
                    .font(Theme.sans(10, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.terracotta)
                Text(day.title)
                    .font(Theme.serif(18, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.top, 3)

                Spacer(minLength: 8)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(info.days)")
                        .font(Theme.serif(42, weight: .medium))
                        .foregroundStyle(Theme.terracotta)
                        .monospacedDigit()
                    Text(label(info))
                        .font(Theme.sans(12, weight: .medium))
                        .foregroundStyle(Theme.muted)
                }
                Text(CNDate.short(info.displayDate))
                    .font(Theme.sans(11, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            WidgetPhotoTile(day: day, scrim: false)
                .frame(width: 104, height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.65), lineWidth: 1)
                )
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Theme.card, Theme.terracottaSoft],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct WidgetLarge: View {
    let day: Day
    var body: some View {
        let info = DayInfo.compute(day)
        ZStack(alignment: .bottomLeading) {
            WidgetPhotoTile(day: day, scrim: true)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(day.categoryLabel)
                        .font(Theme.sans(10, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(Color.white.opacity(0.78))
                    Spacer()
                }

                Spacer()

                Text(day.title)
                    .font(Theme.serif(24, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(info.days)")
                        .font(Theme.serif(72, weight: .medium))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .minimumScaleFactor(0.8)
                    Text(label(info))
                        .font(Theme.sans(13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.82))
                }
                .padding(.top, 4)
                Text(CNDate.short(info.displayDate))
                    .font(Theme.sans(12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .padding(.top, 2)
            }
            .padding(20)
        }
    }
}

private func label(_ info: DayInfo) -> String {
    if info.isToday { return "就是今天" }
    return info.isPast ? "已过 · 天" : "天后"
}

private struct WidgetPhotoTile: View {
    let day: Day
    var scrim: Bool = false

    var body: some View {
        ZStack {
            if let data = day.photoData, let image = UIImage(data: data) {
                GeometryReader { geo in
                    focusedImage(image, in: geo.size)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                        .clipped()
                }
            } else {
                day.photo.background()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if scrim {
                LinearGradient(
                    colors: [.black.opacity(0.08), .black.opacity(0.22), .black.opacity(0.72)],
                    startPoint: UnitPoint(x: 0.5, y: 0.15),
                    endPoint: .bottom
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .clipped()
    }

    private func focusedImage(_ image: UIImage, in container: CGSize) -> some View {
        let size = fillSize(image: image.size, in: container)
        let xOffset = (container.width - size.width) * CGFloat(min(1, max(0, day.coverFocusX)))
        let yOffset = (container.height - size.height) * CGFloat(min(1, max(0, day.coverFocusY)))

        return Image(uiImage: image)
            .resizable()
            .frame(width: size.width, height: size.height)
            .offset(x: xOffset, y: yOffset)
    }

    private func fillSize(image: CGSize, in container: CGSize) -> CGSize {
        guard image.width > 0, image.height > 0,
              container.width > 0, container.height > 0 else {
            return container
        }
        let imageAspect = image.width / image.height
        let containerAspect = container.width / container.height
        if imageAspect > containerAspect {
            return CGSize(width: container.height * imageAspect, height: container.height)
        }
        return CGSize(width: container.width, height: container.width / imageAspect)
    }
}
