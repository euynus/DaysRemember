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
        .configurationDisplayName("时光 · 即将到来")
        .description("把最近一个重要的日子放到主屏。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Timeline

struct DaysEntry: TimelineEntry {
    var date: Date
    var day: Day?
}

struct DaysProvider: TimelineProvider {
    func placeholder(in context: Context) -> DaysEntry {
        DaysEntry(date: Date(), day: SampleData.days.first)
    }

    func getSnapshot(in context: Context, completion: @escaping (DaysEntry) -> Void) {
        completion(DaysEntry(date: Date(), day: nearestUpcoming()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DaysEntry>) -> Void) {
        let now = Date()
        let entry = DaysEntry(date: now, day: nearestUpcoming(asOf: now))
        // Refresh at the next midnight so the countdown ticks down.
        let nextMidnight = CNDate.calendar.nextDate(after: now,
                                                    matching: DateComponents(hour: 0, minute: 0),
                                                    matchingPolicy: .strict) ?? now.addingTimeInterval(60 * 60 * 6)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func nearestUpcoming(asOf today: Date = Date()) -> Day? {
        let raw = SharedStorage.defaults.data(forKey: "days.v1")
        let days = raw.flatMap { try? JSONDecoder().decode([Day].self, from: $0) } ?? SampleData.days
        return days
            .map { ($0, DayInfo.compute($0, today: today)) }
            .filter { !$0.1.isPast && $0.1.days <= 365 }
            .sorted { $0.1.days < $1.1.days }
            .first?.0
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
            VStack(spacing: 6) {
                Text("时光")
                    .font(Theme.serif(20, weight: .semibold))
                    .foregroundStyle(Theme.terracotta)
                Text("还没有日子")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}

private struct WidgetSmall: View {
    let day: Day
    var body: some View {
        let info = DayInfo.compute(day)
        ZStack(alignment: .bottomLeading) {
            WidgetPhotoTile(day: day, scrim: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(day.title)
                    .font(Theme.sans(10))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
                Text("\(info.days)")
                    .font(Theme.serif(44, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(label(info))
                    .font(Theme.sans(10))
                    .foregroundStyle(Color.white.opacity(0.8))
            }
            .padding(14)
        }
    }
}

private struct WidgetMedium: View {
    let day: Day
    var body: some View {
        let info = DayInfo.compute(day)
        HStack(spacing: 0) {
            WidgetPhotoTile(day: day)
                .frame(width: 150)
            VStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("即将到来")
                        .font(Theme.sans(10))
                        .tracking(1.6)
                        .foregroundStyle(Theme.muted)
                    Text(day.title)
                        .font(Theme.serif(16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(info.days)")
                        .font(Theme.serif(38, weight: .medium))
                        .foregroundStyle(Theme.terracotta)
                        .monospacedDigit()
                    Text(label(info) + " · " + CNDate.short(info.displayDate))
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct WidgetLarge: View {
    let day: Day
    var body: some View {
        let info = DayInfo.compute(day)
        VStack(spacing: 0) {
            WidgetPhotoTile(day: day)
                .frame(maxHeight: .infinity)
                .frame(height: 160)
            VStack(alignment: .leading, spacing: 0) {
                Text("即将到来")
                    .font(Theme.sans(10))
                    .tracking(1.6)
                    .foregroundStyle(Theme.muted)
                Text(day.title)
                    .font(Theme.serif(18, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 4)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(info.days)")
                        .font(Theme.serif(56, weight: .medium))
                        .foregroundStyle(Theme.terracotta)
                        .monospacedDigit()
                    Text(label(info) + " · " + CNDate.short(info.displayDate))
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.top, 10)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                day.photo.background()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if scrim {
                LinearGradient(
                    colors: [.black.opacity(0), .black.opacity(0.55)],
                    startPoint: UnitPoint(x: 0.5, y: 0.35),
                    endPoint: .bottom
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .clipped()
    }
}
