import SwiftUI

enum CategoryRoute: Hashable {
    case all, category(String)
}

struct CategoriesView: View {
    @Environment(DayStore.self) var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var creatingCategory = false
    @State private var editingCategory: CategoryDefinition?

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "分类") {
                FAB(systemName: "plus", dark: true) {
                    creatingCategory = true
                }
                .accessibilityLabel("新建分类")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    NavigationLink(value: CategoryRoute.all) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("全部日子").font(Theme.sans(15, weight: .medium))
                                Text("\(store.days.count)")
                                    .font(Theme.sans(56, weight: .semibold))
                                    .monospacedDigit()
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.title2)
                        }
                        .foregroundStyle(Theme.accent)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 280 : 145), spacing: 12)], spacing: 12) {
                        ForEach(store.categories) { category in
                            categoryTile(category)
                        }
                    }
                }
                .padding(.horizontal, 22)
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

    private func categoryTile(_ category: CategoryDefinition) -> some View {
        NavigationLink(value: CategoryRoute.category(category.id)) {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: category.symbolName)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(category.colorToken.color)
                    .frame(height: 32)
                VStack(alignment: .leading, spacing: 6) {
                    Text(category.name)
                        .font(Theme.sans(18, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                    Text("\(store.days(in: category.id).count) 个日子")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.ink2)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .padding(18)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PressableTileStyle())
        .accessibilityIdentifier("category-\(category.id)")
        .contextMenu {
            if !category.isSystem {
                Button("编辑分类", systemImage: "pencil") {
                    editingCategory = category
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if !category.isSystem {
                Button {
                    editingCategory = category
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 44, height: 44)
                        .foregroundStyle(Theme.ink2)
                }
                .accessibilityLabel("编辑\(category.name)")
            }
        }
    }
}
