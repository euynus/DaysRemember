import SwiftUI

struct DayRow: View {
    @Environment(\.currentDay) private var today
    @Environment(DayStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let day: Day
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        let info = DayInfo.compute(day, today: today)
        let countdown = info.isToday ? String(localized: "就是今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : info.isPast ? String(localized: "\(info.days) 天前", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : String(localized: "\(info.days) 天后", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        Button { onOpen(day) } label: {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
            layout {
                if !dynamicTypeSize.isAccessibilitySize {
                    PhotoTile(day: day, flat: true, cornerRadius: 3, maximumPixelSize: 256)
                        .frame(width: 62, height: 72)
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text(verbatim: day.title)
                        .font(Theme.sans(16, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .multilineTextAlignment(.leading)
                    Text("\(CNDate.short(info.displayDate)) · \(store.category(for: day).displayName)")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                countdownValue(info)
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { RowDivider() }
        }
        .buttonStyle(PressableTileStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.pinned ? String(localized: "\(day.title)，\(countdown)，已置顶", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                             : String(localized: "\(day.title)，\(countdown)", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
        .accessibilityHint("长按可置顶、编辑或分享")
        .accessibilityIdentifier("dayRow.\(day.id)")
    }

    private func countdownValue(_ info: DayInfo) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
            : AnyLayout(VStackLayout(alignment: .trailing, spacing: 3))
        return layout {
            if day.pinned {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
            }
            Text(info.isToday ? String(localized: "今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : info.days.formatted())
                .font(info.isToday ? Theme.sans(22) : Theme.number(38))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .foregroundStyle(info.isPast ? Theme.ink2 : Theme.ink)
            if !info.isToday {
                Text(info.countdownUnit)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 84, alignment: .trailing)
    }
}

struct UpcomingDayView: View {
    @Environment(\.currentDay) private var today
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let day: Day
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        let info = DayInfo.compute(day, today: today)
        let countdown = info.isToday ? String(localized: "就是今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "\(info.days) 天后", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        Button { onOpen(day) } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("即将到来")
                        .font(Theme.sans(12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.ink2)
                }
                Color.clear
                    .aspectRatio(1.6, contentMode: .fit)
                    .overlay { PhotoTile(day: day, flat: true, cornerRadius: 3) }
                if dynamicTypeSize.isAccessibilitySize {
                    stackedSummary(info)
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .center, spacing: 16) {
                            titleBlock(info).fixedSize(horizontal: true, vertical: false)
                            Spacer(minLength: 0)
                            countdownValue(info).fixedSize(horizontal: true, vertical: false)
                        }
                        stackedSummary(info)
                    }
                }
            }
            .padding(.top, 18)
        }
        .buttonStyle(PressableTileStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "即将到来，\(day.title)，\(countdown)", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
        .accessibilityHint("长按可置顶、编辑或分享")
        .accessibilityIdentifier("upcomingDay.\(day.id)")
    }

    private func titleBlock(_ info: DayInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: day.title)
                .font(Theme.sans(24, weight: .medium, relativeTo: .title2))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(CNDate.full(info.displayDate))
                .font(Theme.sans(12))
                .foregroundStyle(Theme.muted)
        }
    }

    private func stackedSummary(_ info: DayInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            titleBlock(info)
            countdownValue(info)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func countdownValue(_ info: DayInfo) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(info.isToday ? String(localized: "今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : info.days.formatted())
                .font(info.isToday ? Theme.sans(32) : Theme.number(68))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if !info.isToday {
                Text(info.countdownUnit)
                    .font(Theme.sans(12))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(Theme.accent)
    }
}

struct PressableTileStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Long-press context menu for a day tile — quick pin / edit / share / delete
/// without opening Detail. Self-contained: owns its sheet + dialog state and reads
/// the live `Day` back from the store so the actions reflect the latest edit.
struct DayContextMenu: ViewModifier {
    @Environment(DayStore.self) private var store
    let day: Day
    @State private var showEditor = false
    @State private var showShare = false
    @State private var showDeleteConfirm = false

    private var current: Day { store.days.first { $0.id == day.id } ?? day }

    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button {
                    var updated = current
                    updated.pinned.toggle()
                    store.update(updated)
                } label: {
                    Label(current.pinned ? String(localized: "取消置顶", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "置顶", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                          systemImage: current.pinned ? "star.slash" : "star")
                }
                Button { showEditor = true } label: {
                    Label("编辑", systemImage: "pencil")
                }
                Button { showShare = true } label: {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
                Divider()
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("删除", systemImage: "trash")
                }
            }
            .sheet(isPresented: $showEditor) { DayEditorView(day: current).environment(store) }
            .sheet(isPresented: $showShare) { ShareCardView(day: current) }
            .confirmationDialog("删除这个日子？", isPresented: $showDeleteConfirm,
                                titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    Haptics.warning()
                    store.delete(current)
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后会取消它的待提醒；30 天内可在「设置 › 数据与同步 › 最近删除」中恢复。")
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: current.pinned)
    }
}

extension View {
    /// Attach the quick day-actions context menu (pin / edit / share / delete).
    func dayContextMenu(day: Day) -> some View {
        modifier(DayContextMenu(day: day))
    }
}
