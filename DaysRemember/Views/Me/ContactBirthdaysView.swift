import SwiftUI
import UIKit

/// Imports birthdays from Contacts as yearly days, letting the user leave any out first.
struct ContactBirthdaysView: View {
    @Environment(DayStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.currentDay) private var today
    @State private var phase = Phase.loading
    @State private var selected: Set<String> = []

    private enum Phase: Equatable {
        case loading, denied, failed
        case ready([ContactBirthdays.Candidate])
    }

    var body: some View {
        NavigationStack {
            content
                .scrollContentBackground(.hidden)
                .background(Theme.bg)
                .navigationTitle("导入通讯录生日")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("导入") { importSelected() }
                            .disabled(selected.isEmpty)
                            .accessibilityIdentifier("contacts.import")
                    }
                }
        }
        .tint(Theme.accent)
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView("正在读取通讯录")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .denied:
            ContentUnavailableView {
                Label("无法读取通讯录", systemImage: "person.crop.circle.badge.exclamationmark")
            } description: {
                Text("在「设置」里允许「时光」访问通讯录后，就能导入联系人的生日。")
            } actions: {
                Button("打开设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
        case .failed:
            ContentUnavailableView("通讯录未能读取", systemImage: "exclamationmark.triangle",
                                   description: Text("请稍后再试。"))
        case .ready(let candidates) where candidates.isEmpty:
            ContentUnavailableView("没有可导入的生日", systemImage: "gift",
                                   description: Text("通讯录里填写了生日的联系人都已经在「时光」里了。"))
        case .ready(let candidates):
            List {
                Section {
                    ForEach(candidates) { candidate in
                        row(candidate)
                    }
                } footer: {
                    Text("生日会作为每年重复的日子保存在「家人」里。只读取姓名和生日，不会上传给开发者。")
                }
            }
        }
    }

    private func row(_ candidate: ContactBirthdays.Candidate) -> some View {
        let isSelected = selected.contains(candidate.id)
        let day = candidate.day
        return Button {
            if isSelected { selected.remove(candidate.id) } else { selected.insert(candidate.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(Theme.symbol(20))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.muted)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: day.title)
                        .font(Theme.sans(16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(verbatim: day.lunar ? Lunar.fmt(day.date) : CNDate.short(day.date))
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func load() async {
        guard await ContactBirthdays.requestAccess() else {
            phase = .denied
            return
        }
        do {
            let candidates = try await ContactBirthdays.candidates(today: today, library: store.days,
                                                                   imported: ContactBirthdays.importedIDs())
            selected = Set(candidates.map(\.id))
            phase = .ready(candidates)
        } catch {
            phase = .failed
        }
    }

    private func importSelected() {
        guard case .ready(let candidates) = phase else { return }
        let chosen = candidates.filter { selected.contains($0.id) }
        guard store.add(contentsOf: chosen.map(\.day)) else { return }
        ContactBirthdays.remember(chosen.map(\.id))
        Haptics.success()
        dismiss()
    }
}
