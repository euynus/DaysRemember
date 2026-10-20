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
    @State private var saveError: String?

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

    /// The grid, led by the category's own icon when the grid doesn't offer it, so it stays chosen.
    static func iconChoices(for icon: String) -> [(symbol: String, label: String)] {
        let symbol = CategoryDefinition.symbolName(for: icon)
        guard !choices.contains(where: { $0.symbol == symbol }) else { return choices }
        return [(symbol, String(localized: "当前图标", bundle: AppLocalization.bundle, locale: AppLocalization.locale))] + choices
    }

    /// Older categories stored sticker names; they are selected as the symbols they show.
    static func isSelected(_ symbol: String, icon: String) -> Bool {
        CategoryDefinition.symbolName(for: icon) == symbol
    }

    /// Curated SF Symbols suited to anniversaries / life events — kept so custom
    /// categories that were created before stickers still round-trip their icon.
    /// Built on each use: the app changes language without relaunching.
    private static var choices: [(symbol: String, label: String)] { [
        ("heart", String(localized: "爱心", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
        ("house", String(localized: "房屋", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
        ("airplane", String(localized: "飞机", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
        ("graduationcap", String(localized: "毕业帽", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
        ("sparkles", String(localized: "闪光", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
        ("star", String(localized: "星星", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
        ("gift", String(localized: "礼物", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
        ("birthday.cake", String(localized: "生日蛋糕", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
        ("camera", String(localized: "相机", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
        ("pawprint", String(localized: "爪印", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
        ("sun.max", String(localized: "太阳", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
        ("moon.stars", String(localized: "月亮和星星", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
        ("leaf", String(localized: "叶子", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
        ("cup.and.saucer", String(localized: "茶杯", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
        ("music.note", String(localized: "音符", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
        ("flag", String(localized: "旗帜", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
        ("bell", String(localized: "铃铛", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
        ("tag", String(localized: "标签", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
    ] }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    CategoryEditorPreview(name: name, icon: icon, colorToken: colorToken)
                    nameField
                    CategoryIconPicker(icon: $icon, storedIcon: category?.icon, colorToken: colorToken)
                    CategoryColorPicker(colorToken: $colorToken)
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
        .alert("未能保存", isPresented: Binding(
            get: { saveError != nil }, set: { if !$0 { saveError = nil } }
        )) {
            Button("好", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    private var navBar: some View {
        NavHeader(title: category == nil ? String(localized: "新建分类", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "编辑分类", bundle: AppLocalization.bundle, locale: AppLocalization.locale)) {
            dismiss()
        } trailing: {
            Button(action: save) {
                Text("保存")
                    .font(Theme.sans(15, weight: .bold))
                    .foregroundStyle(canSave ? Theme.ink : Theme.muted)
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .accessibilityIdentifier("saveCategoryButton")
        }
    }

    // MARK: - Name field

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(String(localized: "名称", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            TextField("例如：朋友", text: $name)
                .font(Theme.sans(17))
                .foregroundStyle(Theme.ink)
                .submitLabel(.done)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: .rect(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.hairline, lineWidth: 1) }
                .accessibilityLabel("分类名称")
                .accessibilityIdentifier("categoryNameField")
        }
    }

    // MARK: - Delete

    private var deleteButton: some View {
        PillButton(title: String(localized: "删除分类", bundle: AppLocalization.bundle, locale: AppLocalization.locale), style: .ghost, fill: true) {
            confirmingDelete = true
        }
        .confirmationDialog("删除分类后迁移日子到哪里？",
                            isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            if let category {
                ForEach(store.categories.filter { $0.id != category.id }) { target in
                    Button("迁移到 \(target.displayName)") {
                        Haptics.warning()
                        finishSaving(store.deleteCategory(id: category.id, migrateTo: target.id))
                    }
                }
            }
            Button("取消", role: .cancel) {}
        }
        .padding(.top, 4)
        .accessibilityIdentifier("deleteCategoryButton")
    }

    private func save() {
        if var category {
            category.name = name
            category.icon = icon
            category.colorToken = colorToken
            finishSaving(store.updateCategory(category))
        } else {
            store.addCategory(name: name, icon: icon, colorToken: colorToken)
            finishSaving(store.saveError == nil)
        }
    }

    /// A change that didn't apply keeps the editor and its draft open.
    private func finishSaving(_ saved: Bool) {
        guard saved else {
            saveError = store.loadError ?? store.saveError
                ?? String(localized: "这个分类已在其他设备上删除，修改尚未保存。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            return
        }
        Haptics.success()
        dismiss()
    }
}
