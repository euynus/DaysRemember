import SwiftUI

// Category edits and deletion preserve the existing day migration behavior.
struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DayStore.self) var store

    private let category: CategoryDefinition?
    @State private var name: String
    @State private var icon: String
    @State private var colorToken: CategoryColorToken
    @State private var confirmingDelete = false

    init(category: CategoryDefinition? = nil) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _icon = State(initialValue: category?.icon ?? "tag")
        _colorToken = State(initialValue: category?.colorToken ?? .terracotta)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canDelete: Bool {
        guard let category else { return false }
        // System categories are immutable; deletion needs a migration target.
        return !category.isSystem && store.categories.contains { $0.id != category.id }
    }

    /// Curated SF Symbols suited to anniversaries / life events — kept so custom
    /// categories that were created before stickers still round-trip their icon.
    private static let iconChoices = [
        "heart", "house", "airplane", "graduationcap", "sparkles", "star",
        "gift", "birthday.cake", "camera", "pawprint", "sun.max", "moon.stars",
        "leaf", "cup.and.saucer", "music.note", "flag", "bell", "tag",
    ]

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    preview
                    nameField
                    stickerPicker
                    colorPicker
                    if canDelete { deleteButton }
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .sensoryFeedback(.selection, trigger: icon)
        .sensoryFeedback(.selection, trigger: colorToken)
        .confirmationDialog("删除分类后迁移日子到哪里？",
                            isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            if let category {
                ForEach(store.categories.filter { $0.id != category.id }) { target in
                    Button("迁移到 \(target.name)") {
                        Haptics.warning()
                        store.deleteCategory(id: category.id, migrateTo: target.id)
                        dismiss()
                    }
                }
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var navBar: some View {
        NavHeader(title: category == nil ? "新建分类" : "编辑分类") {
            dismiss()
        } trailing: {
            Button("保存", action: save)
                .font(Theme.sans(15, weight: .bold))
                .foregroundStyle(canSave ? Theme.ink : Theme.muted)
                .frame(minWidth: 42, minHeight: 42, alignment: .trailing)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .disabled(!canSave)
        }
    }

    // MARK: - Live preview card

    private var preview: some View {
        HStack(spacing: 14) {
            Image(systemName: CategoryDefinition.symbolName(for: icon))
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(colorToken.color)
                .frame(width: 56, height: 56)
                .background(colorToken.soft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(name.isEmpty ? "分类名称" : name)
                    .font(Theme.sans(20, weight: .heavy))
                    .foregroundStyle(name.isEmpty ? Theme.muted : Theme.ink)
                Text(colorToken.label)
                    .font(Theme.sans(12, weight: .bold))
                    .foregroundStyle(colorToken.color)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white))
        .shadow(color: Color(hex: 0x15171C).opacity(0.05), radius: 1, x: 0, y: 1)
        .shadow(color: Color(hex: 0x15171C).opacity(0.06), radius: 12, x: 0, y: 8)
    }

    // MARK: - Name field

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("名称")
            TextField("例如：朋友", text: $name)
                .font(Theme.sans(16, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .submitLabel(.done)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white))
                .shadow(color: Color(hex: 0x15171C).opacity(0.05), radius: 1, x: 0, y: 1)
        }
    }

    // MARK: - Sticker picker

    private var stickerPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("图标")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                      spacing: 10) {
                ForEach(Self.iconChoices, id: \.self) { symbol in
                    let selected = icon == symbol
                    Button {
                        icon = symbol
                    } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 24))
                            .foregroundStyle(selected ? Theme.accent : Theme.ink2)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selected ? colorToken.soft : Color.white)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(selected ? colorToken.color : Theme.hairline,
                                                  lineWidth: selected ? 2 : 0.5)
                            }
                    }
                    .buttonStyle(PressScale(scale: 0.92))
                    .accessibilityLabel("图标 \(symbol)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Color picker

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("颜色")
            HStack(spacing: 12) {
                ForEach(CategoryColorToken.allCases) { token in
                    let selected = colorToken == token
                    Button { colorToken = token } label: {
                        Circle()
                            .fill(token.color)
                            .frame(width: 38, height: 38)
                            .frame(minWidth: 44, minHeight: 44)
                            .overlay {
                                Circle().strokeBorder(Color.white, lineWidth: selected ? 3 : 0)
                            }
                            .overlay {
                                Circle().strokeBorder(token.color, lineWidth: selected ? 2 : 0)
                                    .padding(-3)
                            }
                            .shadow(color: Color(hex: 0x15171C).opacity(0.12), radius: 3, x: 0, y: 2)
                    }
                    .buttonStyle(PressScale(scale: 0.9))
                    .accessibilityLabel("颜色 \(token.label)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
                Spacer()
            }
        }
    }

    // MARK: - Delete

    private var deleteButton: some View {
        PillButton(title: "删除分类", style: .ghost, fill: true) {
            confirmingDelete = true
        }
        .padding(.top, 4)
    }

    private func save() {
        if var category {
            category.name = name
            category.icon = icon
            category.colorToken = colorToken
            store.updateCategory(category)
        } else {
            store.addCategory(name: name, icon: icon, colorToken: colorToken)
        }
        Haptics.success()
        dismiss()
    }
}
