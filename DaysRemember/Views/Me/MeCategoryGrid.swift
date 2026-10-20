import SwiftUI

/// Every category with its count and latest cover, and a tile to add one.
struct MeCategoryGrid: View {
    @Environment(DayStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.editCategory) private var editCategory
    /// The library's days by category ID.
    let byCategory: [String: [Day]]

    var body: some View {
        let columns = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(store.categories) { category in
                let days = byCategory[category.id] ?? []
                CategoryTile(category: category, coverDay: days.first, count: days.count) {
                    editCategory(category)
                }
            }
            Button { editCategory(nil) } label: {
                Label("新分类", systemImage: "plus")
                    .font(Theme.sans(14, weight: .bold))
                    .foregroundStyle(Theme.ink2)
                    .frame(maxWidth: .infinity, minHeight: 92)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Theme.hairlineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(PressableTileStyle())
            .accessibilityLabel("新建分类")
            .accessibilityIdentifier("addCategoryButton")
        }
    }
}
