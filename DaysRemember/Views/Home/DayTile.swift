import SwiftUI

struct DayTile: View {
    enum Size { case hero, wide, sq }
    let day: Day
    let size: Size
    var action: () -> Void = {}

    var body: some View {
        let info = DayInfo.compute(day)
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                PhotoTile(day: day, cornerRadius: 20)

                if day.pinned {
                    pinnedBadge
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(10)
                        .allowsHitTesting(false)
                }

                content(info: info)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .foregroundStyle(.white)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
            .shadow(color: .black.opacity(0.05), radius: 16, y: 6)
        }
        .buttonStyle(PressableTileStyle())
        .accessibilityLabel(
            "\(day.title)，"
            + (info.isToday ? "就是今天" : "\(info.labelShort) \(info.days) 天")
            + (day.pinned ? "，已置顶" : "")
        )
        .accessibilityHint("长按可置顶、编辑或分享")
    }

    @ViewBuilder
    private func content(info: DayInfo) -> some View {
        switch size {
        case .hero:
            VStack(alignment: .leading, spacing: 8) {
                Text(day.categoryLabel.uppercased())
                    .font(Theme.sans(12))
                    .tracking(1.8)
                    .foregroundStyle(Color.white.opacity(0.85))
                Text(day.title)
                    .font(Theme.serif(22, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(info.days)")
                        .font(Theme.serif(56, weight: .medium))
                        .monospacedDigit()
                    Text(info.isToday ? info.labelShort : "\(info.labelShort) · 天")
                        .font(Theme.sans(13))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
            }
        case .wide:
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(day.categoryLabel.uppercased())
                        .font(Theme.sans(10))
                        .tracking(1.5)
                        .foregroundStyle(Color.white.opacity(0.8))
                    Text(day.title)
                        .font(Theme.serif(17, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(info.days)")
                        .font(Theme.serif(36, weight: .medium))
                        .monospacedDigit()
                    Text(info.labelShort)
                        .font(Theme.sans(10))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
            }
        case .sq:
            VStack(alignment: .leading, spacing: 4) {
                Text(day.categoryLabel)
                    .font(Theme.sans(11))
                    .foregroundStyle(Color.white.opacity(0.8))
                Text(day.title)
                    .font(Theme.serif(14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(info.days)")
                        .font(Theme.serif(28, weight: .medium))
                        .monospacedDigit()
                    Text(info.labelShort)
                        .font(Theme.sans(10))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
            }
        }
    }

    private var pinnedBadge: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.2))
            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundStyle(.white)
        }
        .frame(width: 24, height: 24)
        .background(.ultraThinMaterial, in: Circle())
    }
}

struct PressableTileStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: configuration.isPressed)
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
