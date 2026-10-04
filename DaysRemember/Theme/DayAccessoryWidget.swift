import SwiftUI
import WidgetKit

/// Shared Lock Screen content; the widget host supplies its family and bounds.
struct DayAccessoryWidget: View {
    enum Style { case circular, rectangular, inline }

    let day: Day?
    let style: Style
    let today: Date
    var selectionMissing: Bool = false
    var hasAnyDays: Bool = false

    private var info: DayInfo? { day.map { DayInfo.compute($0, today: today) } }

    var body: some View {
        let info = self.info
        Group {
            switch style {
            case .circular:
                circular(info)
            case .rectangular:
                ViewThatFits(in: .vertical) {
                    rectangular(info, showsDate: true)
                    rectangular(info, showsDate: false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            case .inline:
                // Keep the count visible when the system truncates a long title.
                Label(inlineText(info), systemImage: "calendar")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(.primary)
        .symbolRenderingMode(.monochrome)
        // Match DayWidgetCard's text-size cap for fixed physical widget bounds.
        .dynamicTypeSize(...DynamicTypeSize.large)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private func circular(_ info: DayInfo?) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            if let day, let info {
                ViewThatFits(in: .vertical) {
                    circularCount(day: day, info: info, showsTitle: true)
                    circularCount(day: day, info: info, showsTitle: false)
                }
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 3) {
                    Image(systemName: "calendar")
                        .font(.title3)
                    Text(selectionMissing ? String(localized: "日子\n已删除")
                         : hasAnyDays ? String(localized: "暂无将至\n日子") : String(localized: "还没有\n日子"))
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .clipShape(Circle())
    }

    private func circularCount(day: Day, info: DayInfo, showsTitle: Bool) -> some View {
        VStack(spacing: 1) {
            if showsTitle {
                Text(day.title)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 3)
            }
            Text(info.isToday ? String(localized: "今天") : "\(info.days)")
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if !info.isToday {
                Text(info.isPast
                     ? String(localized: "widget.daysAgoUnit", defaultValue: "天前")
                     : String(localized: "widget.daysLeftUnit", defaultValue: "天后"))
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func rectangular(_ info: DayInfo?, showsDate: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let day, let info {
                Label(day.title, systemImage: "calendar")
                    .labelStyle(.titleAndIcon)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(info.isToday ? String(localized: "今天") : "\(info.days)")
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    if !info.isToday {
                        Text(info.isPast
                             ? String(localized: "widget.daysAgoUnit", defaultValue: "天前")
                             : String(localized: "widget.daysLeftUnit", defaultValue: "天后"))
                            .font(.caption)
                            .fixedSize()
                    }
                }
                if showsDate {
                    Text(CNDate.short(info.displayDate))
                        .font(.caption2)
                        .lineLimit(1)
                }
            } else {
                Label(emptyMessage, systemImage: "calendar")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var emptyMessage: String {
        selectionMissing ? String(localized: "日子已删除")
            : hasAnyDays ? String(localized: "暂无即将到来的日子") : String(localized: "还没有日子")
    }

    private func countdownText(_ info: DayInfo) -> String {
        info.isToday ? String(localized: "就是今天")
            : info.isPast ? String(localized: "\(info.days)天前") : String(localized: "\(info.days)天后")
    }

    private func inlineText(_ info: DayInfo?) -> String {
        guard let day, let info else { return emptyMessage }
        return String(localized: "\(countdownText(info)) · \(day.title)")
    }

    var accessibilitySummary: String {
        guard let day, let info else { return emptyMessage }
        return String(localized: "\(day.title)，\(countdownText(info))，\(CNDate.full(info.displayDate))")
    }
}
