import SwiftUI

/// A feed polaroid — photo card with a clipped countdown sticky note, pinned-star
/// badge, handwritten date, and a category sticker peeking from the bottom-left.
/// Port of `DayPolaroid` in `screens/Home.jsx`.
struct DayPolaroid: View {
    let day: Day
    /// Feed index — drives the per-card rotation cadence.
    var idx: Int = 0
    var onOpen: (Day) -> Void = { _ in }

    private let rotations: [Double] = [-1.6, 1.4, -1.0, 1.8, -1.3, 1.1]

    var body: some View {
        let info = DayInfo.compute(day)
        let nc = noteColorFor(day.id)
        let rot = rotations[idx % rotations.count]
        let label = info.isToday ? "今天" : (info.isPast ? "天前" : "天后")

        Button { onOpen(day) } label: {
            ZStack(alignment: .topLeading) {
                // Polaroid card — leaves top/right room for the sticky note and the
                // bottom-left room for the sticker to overhang.
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        PhotoTile(day: day, flat: true, cornerRadius: 12)
                            .frame(height: 132)
                        if day.pinned { pinnedBadge.padding(7) }
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(day.title)
                            .font(Theme.sans(14, weight: .heavy))
                            .tracking(-0.3)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text(enDate(info.displayDate))
                            .font(Theme.hand(18))
                            .foregroundStyle(Theme.ink2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
                    .padding(.bottom, 2)
                }
                .polaroidCard(rotation: rot, padding: 7)
                .padding(.top, 12)     // room for the sticky note's overhang
                .padding(.trailing, 4)

                // Category sticker peeking bottom-left.
                Sticker(name: stickerFor(day), size: 30, rotate: -10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .offset(x: -8, y: 0)
                    .allowsHitTesting(false)

                // Countdown sticky note clipped top-right.
                StickyNote(color: nc.paper, ink: nc.ink, rotate: 6, size: .s) {
                    VStack(spacing: 0) {
                        Text("\(info.days)")
                            .font(Theme.sans(22, weight: .bold))
                            .monospacedDigit()
                        Text(label)
                            .font(Theme.handCN(11))
                    }
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(x: 4, y: 2)
                .allowsHitTesting(false)
            }
        }
        .buttonStyle(PressableTileStyle())
        .accessibilityLabel(
            "\(day.title)，"
            + (info.isToday ? "就是今天" : "\(info.labelShort) \(info.days) 天")
            + (day.pinned ? "，已置顶" : "")
        )
        .accessibilityHint("长按可置顶、编辑或分享")
    }

    private var pinnedBadge: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.9))
            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundStyle(Theme.catLove)
        }
        .frame(width: 22, height: 22)
    }
}

/// The big "即将到来" hero polaroid at the top of the feed — the nearest upcoming day
/// with an eyebrow on the photo, title + handwritten date caption, a sticker, and a
/// clipped countdown sticky note. Port of `HeroPolaroid` in `screens/Home.jsx`.
struct HeroPolaroid: View {
    let day: Day
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        let info = DayInfo.compute(day)
        let nc = noteColorFor(day.id)

        Button { onOpen(day) } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        PhotoTile(day: day, cornerRadius: 12)
                            .frame(height: 230)
                        Text("即将到来")
                            .font(Theme.sans(11, weight: .bold))
                            .tracking(1.8)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.leading, 14)
                            .padding(.bottom, 12)
                    }
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.title)
                                .font(Theme.sans(20, weight: .heavy))
                                .tracking(-0.4)
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Text(enDate(info.displayDate))
                                .font(Theme.hand(22))
                                .foregroundStyle(Theme.ink2)
                        }
                        Spacer(minLength: 8)
                        Sticker(name: stickerFor(day), size: 44, rotate: 8)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                }
                .polaroidCard(rotation: -1.2)
                .padding(.top, 10)     // room for the sticky note's overhang

                StickyNote(color: nc.paper, ink: nc.ink, rotate: 5, clip: true, size: .m) {
                    VStack(spacing: 0) {
                        Text("\(info.days)")
                            .font(Theme.sans(34, weight: .bold))
                            .monospacedDigit()
                        Text("天后")
                            .font(Theme.handCN(15))
                    }
                    .multilineTextAlignment(.center)
                }
                .offset(x: -6, y: 0)
                .allowsHitTesting(false)
            }
        }
        .buttonStyle(PressableTileStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("即将到来，\(day.title)，\(info.days) 天后")
        .accessibilityHint("长按可置顶、编辑或分享")
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
