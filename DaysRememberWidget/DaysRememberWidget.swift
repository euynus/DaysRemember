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
                    // Cool paper canvas with a faint top bloom, matching the app.
                    ZStack {
                        Theme.bg
                        RadialGradient(colors: [Color.white.opacity(0.5), .clear],
                                       center: .top, startRadius: 0, endRadius: 240)
                    }
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
            Group {
                switch family {
                case .systemSmall: WidgetSmall(day: day)
                case .systemMedium: WidgetMedium(day: day)
                case .systemLarge: WidgetLarge(day: day)
                default: WidgetSmall(day: day)
                }
            }
            // Tapping the widget opens that specific day's detail.
            .widgetURL(URL(string: "daysremember://day/\(day.id)"))
        } else {
            WidgetEmpty(hasAnyDays: entry.hasAnyDays)
        }
    }
}

private func countdownLabel(_ info: DayInfo) -> String {
    if info.isToday { return "今天" }
    return info.isPast ? "天前" : "天后"
}

// MARK: - Small — a compact polaroid

private struct WidgetSmall: View {
    let day: Day
    var body: some View {
        let info = DayInfo.compute(day)
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                WidgetPhoto(day: day, scrim: false)
                    .frame(maxWidth: .infinity)
                    .frame(height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Sticker(name: stickerFor(day), size: 26, rotate: 8)
                    .padding(5)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(day.title)
                    .font(Theme.sans(12, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(info.days)")
                        .font(Theme.sans(30, weight: .heavy)).monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text(countdownLabel(info))
                        .font(Theme.sans(11, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
        .padding(6)
    }
}

// MARK: - Medium — text + photo polaroid

private struct WidgetMedium: View {
    let day: Day
    var body: some View {
        let info = DayInfo.compute(day)
        let nc = noteColorFor(day.id)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("即将到来")
                    .font(Theme.sans(10, weight: .bold)).tracking(1.4)
                    .foregroundStyle(Theme.catTravel)
                Text(day.title)
                    .font(Theme.sans(17, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.75)
                    .padding(.top, 2)
                Spacer(minLength: 6)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(info.days)")
                        .font(Theme.sans(42, weight: .heavy)).monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text(countdownLabel(info))
                        .font(Theme.sans(13, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
                Text(enDate(info.displayDate))
                    .font(Theme.hand(20))
                    .foregroundStyle(Theme.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack(alignment: .topTrailing) {
                WidgetPhoto(day: day, scrim: false)
                    .frame(width: 116, height: 116)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Sticker(name: stickerFor(day), size: 28, rotate: 8)
                    .offset(x: 6, y: -8)
            }
            .padding(7)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
            .overlay(alignment: .bottomLeading) {
                if let years = info.anniversaryNumber, day.recurring {
                    StickyNote(color: nc.paper, ink: nc.ink, rotate: -6, size: .s) {
                        Text("\(years)年").font(Theme.handCN(16))
                    }
                    .offset(x: -10, y: 8)
                }
            }
        }
        .padding(14)
    }
}

// MARK: - Large — full polaroid

private struct WidgetLarge: View {
    let day: Day
    var body: some View {
        let info = DayInfo.compute(day)
        let nc = noteColorFor(day.id)
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                WidgetPhoto(day: day, scrim: false)
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Sticker(name: stickerFor(day), size: 40, rotate: 8).padding(8)
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(day.title)
                        .font(Theme.sans(20, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(enDate(info.displayDate))
                        .font(Theme.hand(22)).foregroundStyle(Theme.ink2)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(info.days)")
                            .font(Theme.sans(52, weight: .heavy)).monospacedDigit()
                            .foregroundStyle(day.category.color)
                        Text(countdownLabel(info))
                            .font(Theme.sans(14, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.top, 2)
                }
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.top, 10)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
        .overlay(alignment: .topLeading) {
            StickyNote(color: nc.paper, ink: nc.ink, rotate: 6, clip: true, size: .s) {
                VStack(spacing: 0) {
                    Text("\(info.days)").font(Theme.sans(20, weight: .heavy)).monospacedDigit()
                    Text(countdownLabel(info)).font(Theme.handCN(13))
                }
            }
            .offset(x: 8, y: 2)
        }
        .padding(10)
    }
}

// MARK: - Empty

private struct WidgetEmpty: View {
    let hasAnyDays: Bool
    var body: some View {
        VStack(spacing: 8) {
            Sticker(name: .star, size: 40, rotate: -8)
            Text("时光")
                .font(Theme.sans(18, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text(hasAnyDays ? "暂无即将到来的日子" : "还没有日子")
                .font(Theme.sans(12, weight: .medium))
                .foregroundStyle(Theme.muted)
        }
    }
}

// MARK: - Photo (self-contained: gradient + grain, or user image)

private struct WidgetPhoto: View {
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
                    colors: [.black.opacity(0.05), .black.opacity(0.55)],
                    startPoint: UnitPoint(x: 0.5, y: 0.3), endPoint: .bottom
                )
            }
        }
        .clipped()
    }

    private func focusedImage(_ image: UIImage, in container: CGSize) -> some View {
        let size = fillSize(image: image.size, in: container)
        let xOffset = (container.width - size.width) * CGFloat(min(1, max(0, day.coverFocusX)))
        let yOffset = (container.height - size.height) * CGFloat(min(1, max(0, day.coverFocusY)))
        return Image(uiImage: image).resizable()
            .frame(width: size.width, height: size.height)
            .offset(x: xOffset, y: yOffset)
    }

    private func fillSize(image: CGSize, in container: CGSize) -> CGSize {
        guard image.width > 0, image.height > 0, container.width > 0, container.height > 0 else { return container }
        let imageAspect = image.width / image.height
        let containerAspect = container.width / container.height
        if imageAspect > containerAspect {
            return CGSize(width: container.height * imageAspect, height: container.height)
        }
        return CGSize(width: container.width, height: container.width / imageAspect)
    }
}
