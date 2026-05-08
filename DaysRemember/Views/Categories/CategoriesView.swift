import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject var store: DayStore
    var onOpen: (Day) -> Void = { _ in }

    @State private var editing = false
    @State private var showingEditor = false
    @State private var editingCategory: CategoryDefinition?
    @State private var deletingCategory: CategoryDefinition?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            header
            ScrollView(.vertical, showsIndicators: false) {
                grid
                addCategoryButton
                    .padding(.top, 24)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 96)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .sheet(isPresented: $showingEditor) {
            CategoryEditorView(category: editingCategory)
        }
        .confirmationDialog("删除分类后迁移日子到哪里？",
                            isPresented: Binding(
                                get: { deletingCategory != nil },
                                set: { if !$0 { deletingCategory = nil } }
                            ),
                            titleVisibility: .visible) {
            if let deletingCategory {
                ForEach(store.categories.filter { $0.id != deletingCategory.id }) { target in
                    Button("迁移到 \(target.name)") {
                        store.deleteCategory(id: deletingCategory.id, migrateTo: target.id)
                        self.deletingCategory = nil
                    }
                }
            }
            Button("取消", role: .cancel) { deletingCategory = nil }
        }
    }

    private var topBar: some View {
        HStack {
            Color.clear.frame(width: 44, height: 44)
            Spacer()
            Text("分类")
                .font(Theme.serif(17, weight: .semibold, relativeTo: .headline))
            Spacer()
            Button(editing ? "完成" : "编辑") {
                withAnimation(.easeInOut(duration: 0.18)) { editing.toggle() }
            }
            .font(Theme.sans(14, weight: .medium, relativeTo: .body))
            .foregroundStyle(Theme.terracotta)
            .buttonStyle(.plain)
            .frame(width: 44, height: 44, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 8)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("你的分类")
                .font(Theme.serif(30, weight: .semibold, relativeTo: .largeTitle))
                .foregroundStyle(Theme.ink)
            Text("共 \(store.days.count) 个日子 · \(store.categories.count) 个分类")
                .font(Theme.sans(13, relativeTo: .body))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private var grid: some View {
        VStack(spacing: 10) {
            NavigationLink {
                CategoryDaysListView(title: "全部日子", days: store.days(in: nil), onOpen: onOpen)
            } label: {
                tileView(title: "全部日子", subtitle: "\(store.days.count) 个日子",
                         icon: "square.grid.2x2.fill", color: Theme.terracotta,
                         soft: Theme.terracottaSoft, hero: true)
            }
            .buttonStyle(.plain)
            .disabled(editing)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(store.categories) { categoryTile($0) }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private func categoryTile(_ category: CategoryDefinition) -> some View {
        let count = store.days.filter { $0.categoryID == category.id }.count
        return ZStack(alignment: .topTrailing) {
            NavigationLink {
                CategoryDaysListView(title: category.name,
                                     days: store.days(in: category.id),
                                     onOpen: onOpen)
            } label: {
                tileView(title: category.name, subtitle: "\(count) 个日子",
                         icon: category.icon, color: category.colorToken.color,
                         soft: category.colorToken.soft, hero: false)
            }
            .buttonStyle(.plain)
            .disabled(editing)

            if editing && !category.isSystem {
                HStack(spacing: 6) {
                    Button {
                        editingCategory = category
                        showingEditor = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(Theme.card.opacity(0.9), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("编辑\(category.name)")

                    Button {
                        deletingCategory = category
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.rose)
                            .frame(width: 28, height: 28)
                            .background(Theme.card.opacity(0.9), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("删除\(category.name)")
                }
                .padding(10)
            }
        }
    }

    private func tileView(title: String, subtitle: String, icon: String, color: Color,
                          soft: Color, hero: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            soft
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: hero ? 28 : 22, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: hero ? 36 : 30, height: hero ? 36 : 30, alignment: .leading)
                Text(title)
                    .font(Theme.serif(hero ? 20 : 16, weight: .semibold, relativeTo: hero ? .title3 : .headline))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(Theme.sans(12, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(color)
            }
            .padding(16)

            if hero {
                stackedPhotoPeek
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                    .padding(14)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: hero ? 140 : 110)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)，\(subtitle)")
    }

    private var stackedPhotoPeek: some View {
        let stack: [PhotoStyle] = [.wedding, .baby, .japan]
        return HStack(spacing: -10) {
            ForEach(stack.indices, id: \.self) { index in
                PhotoTile(style: stack[index], flat: true, cornerRadius: 10)
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Theme.bg, lineWidth: 2)
                    )
                    .zIndex(Double(stack.count - index))
            }
        }
    }

    private var addCategoryButton: some View {
        Button {
            editingCategory = nil
            showingEditor = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Theme.bg2)
                    Image(systemName: "plus")
                        .foregroundStyle(Theme.muted)
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text("新建分类").font(Theme.sans(14, weight: .medium, relativeTo: .body))
                    Text("自己定义标签和颜色").font(Theme.sans(12, relativeTo: .caption)).foregroundStyle(Theme.muted)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(Theme.hairlineStrong)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("新建分类")
    }
}
