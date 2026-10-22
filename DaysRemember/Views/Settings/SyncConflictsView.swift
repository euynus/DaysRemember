import SwiftUI

struct SyncConflictsView: View {
    @Environment(DayStore.self) private var store

    var body: some View {
        List {
            if store.syncConflicts.isEmpty {
                ContentUnavailableView("没有本机保留版本", systemImage: "clock.arrow.circlepath")
                    .listRowBackground(Color.clear)
            }
            ForEach(store.syncConflicts) { conflict in
                SyncConflictSection(conflict: conflict)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .tint(Theme.accent)
        .navigationTitle("同步保留版本")
        .navigationBarTitleDisplayMode(.inline)
    }
}
