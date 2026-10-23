import SwiftUI

/// A category as a pastel tile in 我的: its flat illustration, name and day count.
struct CategoryTile: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let category: CategoryDefinition
    let coverDay: Day?
    let count: Int
    var onEdit: () -> Void

    /// The newest day's preset cover, or the category's default template.
    private var coverStyle: PhotoStyle {
        if let coverDay, coverDay.photoData == nil { return coverDay.photo }
        return PhotoStyle.defaultCover(forCategoryID: category.id) ?? coverDay?.photo ?? .systemDefault
    }

    var body: some View {
        NavigationLink(value: CategoryRoute.category(category.id)) {
            VStack(alignment: .leading, spacing: 1) {
                // Room for the edit button, which large text would otherwise put over the icon.
                Spacer(minLength: dynamicTypeSize.isAccessibilitySize && category.isSystem ? 0 : 36)
                Label {
                    Text(category.displayName)
                } icon: {
                    Image(systemName: category.symbolName)
                        .foregroundStyle(category.tintInk)
                }
                .font(Theme.sans(16, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .multilineTextAlignment(.leading)
                Text(String(localized: "\(count) 个日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.onPastel)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .bottomLeading)
            .background(alignment: .topTrailing) {
                if !dynamicTypeSize.isAccessibilitySize {
                    FlatCover(style: coverStyle)
                        .frame(width: 66, height: 66)
                        .padding(8)
                }
            }
            .background(category.tint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressableTileStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(category.displayName)，\(count) 个日子")
        .accessibilityIdentifier("category-\(category.id)")
        .contextMenu {
            if !category.isSystem {
                Button("编辑分类", systemImage: "pencil", action: onEdit)
            }
        }
        .overlay(alignment: .topLeading) {
            if !category.isSystem {
                Button(action: onEdit) {
                    Label("编辑分类", systemImage: "pencil")
                        .labelStyle(.iconOnly)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(category.tintInk)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.75), in: Circle())
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // The pencil stays inside its circle and the space the tile leaves it.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityLabel("编辑\(category.displayName)")
                .accessibilityIdentifier("editCategory-\(category.id)")
                .help("编辑分类")
            }
        }
    }
}
