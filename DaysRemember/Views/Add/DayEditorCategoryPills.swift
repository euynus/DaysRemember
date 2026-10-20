import SwiftUI

/// The categories to choose from, led by the day's own when it isn't available here.
struct DayEditorCategoryPills: View {
    @Environment(DayStore.self) private var store
    let categoryID: String
    /// The resolved choice; nil while the day's category hasn't synced to this device.
    let selectedCategory: CategoryDefinition?
    /// The name the day stored for its category, for one that isn't available.
    let storedName: String
    var onSelect: (CategoryDefinition) -> Void = { _ in }

    var body: some View {
        FlowLayout(spacing: 8) {
            if !store.categories.contains(where: { $0.id == categoryID }) {
                let name = selectedCategory?.displayName ?? storedName
                let label = name.isEmpty ? String(localized: "未知分类", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : name
                let status = selectedCategory == nil
                    ? String(localized: "未同步", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "不可用", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                Chip(String(localized: "\(label)（\(status)）", bundle: AppLocalization.bundle, locale: AppLocalization.locale), selected: true, leading: {
                    Image(systemName: "questionmark.folder")
                        .font(Theme.symbol(14))
                })
                .disabled(true)
                .accessibilityLabel("分类 \(label)，\(status)")
                .accessibilityIdentifier("unavailableDayCategory")
            }
            ForEach(store.categories) { category in
                Chip(category.displayName, selected: categoryID == category.id) {
                    Image(systemName: category.symbolName)
                        .font(Theme.symbol(14))
                } action: {
                    onSelect(category)
                }
                .accessibilityLabel("分类 \(category.displayName)")
                .accessibilityIdentifier("dayCategory-\(category.id)")
                .accessibilityAddTraits(categoryID == category.id ? [.isSelected] : [])
            }
        }
    }
}
