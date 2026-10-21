import SwiftUI
import TipKit

/// Long-press context menu for a day tile — quick pin / edit / share / delete
/// without opening Detail. Self-contained: owns its sheet + dialog state. Callers pass
/// the store's current record, which the menu shows; the actions read it back from the
/// store when they run, so the menu doesn't search every day on each update.
struct DayContextMenu: ViewModifier {
    @Environment(DayStore.self) private var store
    @Environment(DeepLinkRouter.self) private var router
    @Environment(\.editDay) private var editDay
    let day: Day
    // Each action keeps the day it was chosen for: after midnight the hero card shows another day.
    @State private var sharing: Day?
    @State private var deleting: Day?

    private var current: Day { store.days.first { $0.id == day.id } ?? day }

    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button {
                    found()
                    var updated = current
                    updated.pinned.toggle()
                    store.update(updated)
                } label: {
                    Label(day.pinned ? String(localized: "取消置顶", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "置顶", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                          systemImage: day.pinned ? "pin.slash" : "pin")
                }
                Button { found(); editDay(current) } label: {
                    Label("编辑", systemImage: "pencil")
                }
                Button { found(); sharing = current } label: {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
                Divider()
                Button(role: .destructive) { found(); deleting = current } label: {
                    Label("删除", systemImage: "trash")
                }
            }
            .sheet(item: $sharing) { ShareCardView(day: $0) }
            .confirmationDialog("删除这个日子？", isPresented: Binding(
                get: { deleting != nil }, set: { if !$0 { deleting = nil } }
            ), titleVisibility: .visible, presenting: deleting) { day in
                Button("删除", role: .destructive) {
                    Haptics.warning()
                    store.delete(day)
                }
                Button("取消", role: .cancel) {}
            } message: { _ in
                Text("删除后会取消它的待提醒；30 天内可在「我的 › 数据与同步 › 最近删除」中恢复。")
            }
            .onChange(of: router.linkOpenCount) {
                sharing = nil
                deleting = nil
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: day.pinned)
    }

    /// Whichever action is chosen, the menu has been found, so its tip can go.
    private func found() {
        DayMenuTip().invalidate(reason: .actionPerformed)
    }
}

extension View {
    /// Attach the quick day-actions context menu (pin / edit / share / delete).
    func dayContextMenu(day: Day) -> some View {
        modifier(DayContextMenu(day: day))
    }
}
