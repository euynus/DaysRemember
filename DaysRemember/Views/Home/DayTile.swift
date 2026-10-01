import SwiftUI

struct DayRow: View {
    @Environment(DayStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let day: Day
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        let info = DayInfo.compute(day)
        Button { onOpen(day) } label: {
            HStack(spacing: 14) {
                if !dynamicTypeSize.isAccessibilitySize {
                    PhotoTile(day: day, flat: true, cornerRadius: 8)
                        .frame(width: 76, height: 84)
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text(day.title)
                        .font(Theme.sans(17, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    Text(CNDate.short(info.displayDate))
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.ink2)
                    Label(store.category(for: day).name, systemImage: store.category(for: day).symbolName)
                        .font(Theme.sans(11, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 3) {
                    if day.pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.catLove)
                    }
                    Text(info.isToday ? "今天" : "\(info.days)")
                        .font(Theme.sans(info.isToday ? 22 : 30, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(Theme.ink)
                    if !info.isToday {
                        Text(info.isPast ? "天前" : "天后")
                            .font(Theme.sans(11))
                            .foregroundStyle(Theme.ink2)
                    }
                }
            }
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PressableTileStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.title)，" + (info.isToday ? "就是今天" : "\(info.labelShort) \(info.days) 天") + (day.pinned ? "，已置顶" : ""))
        .accessibilityHint("长按可置顶、编辑或分享")
    }
}

struct UpcomingDayView: View {
    let day: Day
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        let info = DayInfo.compute(day)
        Button { onOpen(day) } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("即将到来", systemImage: "sun.max")
                        .font(Theme.sans(12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Text(CNDate.short(info.displayDate))
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.ink2)
                }
                PhotoTile(day: day, flat: true, cornerRadius: 8)
                    .frame(height: 210)
                    .overlay(alignment: .topTrailing) {
                        VStack(spacing: 2) {
                            Text(info.isToday ? "今天" : "\(info.days)")
                                .font(Theme.sans(info.isToday ? 26 : 42, weight: .semibold))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            if !info.isToday {
                                Text("天后").font(Theme.sans(12, weight: .medium))
                            }
                        }
                        .foregroundStyle(Theme.ink)
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .padding(12)
                    }
                HStack {
                    Text(day.title)
                        .font(Theme.sans(25, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(PressableTileStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("即将到来，\(day.title)，" + (info.isToday ? "就是今天" : "\(info.days) 天后"))
        .accessibilityHint("长按可置顶、编辑或分享")
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
                    Label(current.pinned ? "取消置顶" : "置顶",
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
                Text("删除后会同时取消这个日子的待提醒。")
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
