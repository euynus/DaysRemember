import SwiftUI

struct CategoryTile: View {
    let category: CategoryDefinition
    let coverDay: Day?
    let count: Int
    var onEdit: () -> Void

    var body: some View {
        NavigationLink(value: CategoryRoute.category(category.id)) {
            VStack(alignment: .leading, spacing: 12) {
                if let coverDay {
                    PhotoTile(day: coverDay, flat: true, cornerRadius: 3)
                        .frame(height: 118)
                } else {
                    Rectangle().fill(category.colorToken.soft)
                        .frame(height: 118)
                        .overlay {
                            Image(systemName: category.symbolName)
                                .font(.system(size: 30, weight: .light))
                                .foregroundStyle(category.colorToken.color)
                        }
                        .accessibilityHidden(true)
                }
                HStack(alignment: .firstTextBaseline) {
                    Label(category.name, systemImage: category.symbolName)
                        .font(Theme.sans(15, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Text("\(count)")
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
                Button("编辑分类", systemImage: "pencil", action: onEdit)
            }
        }
        .overlay(alignment: .topTrailing) {
            if !category.isSystem {
                Button(action: onEdit) {
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
