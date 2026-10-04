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
        .navigationTitle("本机保留版本")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SyncConflictSection: View {
    @Environment(DayStore.self) private var store
    let conflict: SyncConflict
    @State private var confirmRestore = false
    @State private var confirmDeletion = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        Section {
            switch conflict.record {
            case .day(let day):
                PhotoTile(day: day, flat: true, cornerRadius: 8, maximumPixelSize: 1200)
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    .accessibilityHidden(false)
                    .accessibilityLabel("\(day.title)的本机封面")
                Text(day.title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                LabeledContent("日期", value: CNDate.full(day.date))
                if day.lunar {
                    LabeledContent("农历", value: Lunar.fmtFull(day.date))
                }
                LabeledContent("分类") {
                    Text(day.categoryDisplayName)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("笔记").foregroundStyle(.secondary)
                    Text(day.note.isEmpty ? String(localized: "无", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : day.note)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            case .category(let category):
                Label {
                    Text(category.displayName)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                } icon: {
                    Image(systemName: category.symbolName)
                        .foregroundStyle(category.colorToken.color)
                }
            }
            LabeledContent("保存时间") {
                Text(conflict.createdAt, format: .dateTime.year().month().day().hour().minute().second())
            }
            HStack {
                Spacer(minLength: 0)
                Button {
                    confirmRestore = true
                } label: {
                    Label("恢复本机保留版本", systemImage: "arrow.uturn.backward")
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("恢复\(recordTitle)的本机保留版本")
                .help("恢复本机保留版本")
                .confirmationDialog("恢复“\(recordTitle)”的本机保留版本？", isPresented: $confirmRestore,
                                    titleVisibility: .visible) {
                    Button("恢复并同步", role: .destructive, action: restore)
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("此版本将恢复对应的\(recordKind)，替换当前同一条记录并同步到其他设备。其他记录保持不变。恢复后将移除此保留版本。")
                }
                Button(role: .destructive) {
                    confirmDeletion = true
                } label: {
                    Label("永久删除本机保留版本", systemImage: "trash")
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("永久删除\(recordTitle)的本机保留版本")
                .help("永久删除本机保留版本")
                .confirmationDialog("永久删除“\(recordTitle)”的本机保留版本？", isPresented: $confirmDeletion,
                                    titleVisibility: .visible) {
                    Button("永久删除", role: .destructive, action: discard)
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("仅删除这份本机保留版本，删除后无法撤销。当前日子、分类、其他保留版本和已导出的备份不受影响。")
                }
            }
            .disabled(store.loadError != nil)
        } header: {
            Text("\(recordKind) · 本机保留版本")
        }
        .listRowBackground(Theme.card)
        .alert("操作失败", isPresented: $showError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var recordTitle: String {
        switch conflict.record {
        case .day(let day): return day.title
        case .category(let category): return category.displayName
        }
    }

    private var recordKind: String {
        switch conflict.record {
        case .day: return String(localized: "日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .category: return String(localized: "分类", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
    }

    private func restore() {
        do {
            try store.restoreSyncConflict(id: conflict.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func discard() {
        do {
            try store.discardSyncConflict(id: conflict.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
