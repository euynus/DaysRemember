import SwiftUI

enum CategoryRoute: Hashable {
    case all, category(String)
}

struct CategoriesView: View {
    @Environment(DayStore.self) var store
    @Environment(\.currentDay) private var today
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var creatingCategory = false
    @State private var editingCategory: CategoryDefinition?

    var body: some View {
        let daysByCategory = store.daysByCategory(today: today)
        VStack(spacing: 0) {
            NavHeader(title: String(localized: "分类")) {
                FAB(systemName: "plus", dark: true) {
                    creatingCategory = true
                }
                .accessibilityLabel("新建分类")
                .accessibilityIdentifier("addCategoryButton")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    NavigationLink(value: CategoryRoute.all) {
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Text("\(store.days.count)")
                                .font(Theme.number(48))
                            Text("全部日子").font(Theme.sans(14))
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.body)
                        }
                        .foregroundStyle(Theme.ink)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 280 : 145), spacing: 18)], spacing: 24) {
                        ForEach(store.categories) { category in
                            let days = daysByCategory[category.id] ?? []
                            CategoryTile(category: category, coverDay: days.first, count: days.count) {
                                editingCategory = category
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Theme.bg)
        .sheet(isPresented: $creatingCategory) {
            CategoryEditorView().environment(store)
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditorView(category: category).environment(store)
        }
    }
}
