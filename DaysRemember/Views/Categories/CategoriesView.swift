import SwiftUI

enum CategoryRoute: Hashable {
    case all, category(String)
}

struct CategoriesView: View {
    @Environment(DayStore.self) var store
    @Environment(\.currentDay) private var today
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var minimumColumnWidth: CGFloat = 145
    @State private var creatingCategory = false
    @State private var editingCategory: CategoryDefinition?

    var body: some View {
        let daysByCategory = store.daysByCategory(today: today)
        let columns = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible(), alignment: .top)]
            : [GridItem(.adaptive(minimum: minimumColumnWidth), spacing: 18, alignment: .top)]
        VStack(spacing: 0) {
            NavHeader(title: String(localized: "分类", bundle: AppLocalization.bundle, locale: AppLocalization.locale)) {
                FAB(systemName: "plus", dark: true) {
                    creatingCategory = true
                }
                .accessibilityLabel("新建分类")
                .accessibilityIdentifier("addCategoryButton")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    NavigationLink(value: CategoryRoute.all) {
                        HStack(spacing: 14) {
                            let summaryLayout = dynamicTypeSize.isAccessibilitySize
                                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 14))
                            summaryLayout {
                                Text("\(store.days.count)")
                                    .font(Theme.number(48))
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                Text("全部日子")
                                    .font(Theme.sans(14))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.body)
                                .accessibilityHidden(true)
                        }
                        .foregroundStyle(Theme.ink)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                    LazyVGrid(columns: columns, spacing: 24) {
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
