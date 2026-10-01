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
                            categoryTile(category)
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

    private func categoryTile(_ category: CategoryDefinition) -> some View {
        NavigationLink(value: CategoryRoute.category(category.id)) {
            VStack(alignment: .leading, spacing: 12) {
                if let day = store.days(in: category.id).first {
                    PhotoTile(day: day, flat: true, cornerRadius: 3)
                        .frame(height: 118)
                } else {
                    Rectangle().fill(category.colorToken.soft)
                        .frame(height: 118)
                        .overlay {
                            Image(systemName: category.symbolName)
                                .font(.system(size: 30, weight: .light))
                                .foregroundStyle(category.colorToken.color)
                        }
                }
                HStack(alignment: .firstTextBaseline) {
                    Label(category.name, systemImage: category.symbolName)
                        .font(Theme.sans(15, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Text("\(store.days(in: category.id).count)")
                        .font(Theme.number(22))
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
                        .background(Theme.bg, in: Circle())
                }
                .accessibilityLabel("编辑\(category.name)")
            }
        }
    }
}
