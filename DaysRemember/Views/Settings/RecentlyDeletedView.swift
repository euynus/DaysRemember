import SwiftUI

struct RecentlyDeletedView: View {
    @Environment(DayStore.self) private var store
    @State private var deletion: DeletedDay?

    var body: some View {
        List {
            if store.deletedDays.isEmpty {
                ContentUnavailableView("没有最近删除的日子", systemImage: "trash")
                    .listRowBackground(Color.clear)
            }
            ForEach(store.deletedDays) { entry in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.day.title).font(.headline)
                        Text(entry.deletedAt, format: .dateTime.year().month().day())
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button { store.restoreDeletedDay(id: entry.id) } label: {
                        Label("恢复", systemImage: "arrow.uturn.backward")
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                    }
                    .accessibilityLabel("恢复\(entry.day.title)")
                    .buttonStyle(.borderless)
                    Button(role: .destructive) { deletion = entry } label: {
                        Label("永久删除", systemImage: "trash")
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                    }
                    .accessibilityLabel("永久删除\(entry.day.title)")
                    .buttonStyle(.borderless)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .navigationTitle("最近删除")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("永久删除这个日子？", isPresented: Binding(
            get: { deletion != nil }, set: { if !$0 { deletion = nil } }
        ), titleVisibility: .visible) {
            Button("永久删除", role: .destructive) {
                if let deletion { store.permanentlyDeleteDay(id: deletion.id) }
                deletion = nil
            }
            Button("取消", role: .cancel) { deletion = nil }
        } message: {
            Text("删除后无法从最近删除恢复。已导出的备份不受影响。")
        }
    }
}
