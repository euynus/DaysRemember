import SwiftUI

/// A category as a pastel tile in 我的: its flat illustration, name and day count.
struct CategoryTile: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let category: CategoryDefinition
    let coverDay: Day?
    let count: Int
    var onEdit: () -> Void

    private static let coverSide: CGFloat = 66
    private static let coverInset: CGFloat = 8
    private static let horizontalPadding: CGFloat = 14
    private static let verticalPadding: CGFloat = 12
    private static let editButtonRoom: CGFloat = 36
    /// Trailing room a name beside the illustration leaves it, with a gap.
    private static let besideCover = coverSide + coverInset - horizontalPadding + 6
    /// Room above a name below the illustration, with a gap.
    private static let belowCover = coverSide + coverInset - verticalPadding + 4

    private var name: some View {
        Label {
            Text(category.displayName)
        } icon: {
            Image(systemName: category.symbolName)
                .foregroundStyle(category.tintInk)
        }
        .font(Theme.sans(16, weight: .heavy))
        .foregroundStyle(Theme.ink)
        .multilineTextAlignment(.leading)
    }

    /// The first day's preset cover, or the category's default template; the editor's preview
    /// shows the same one.
    static func cover(categoryID: String, coverDay: Day?) -> PhotoStyle {
        if let coverDay, coverDay.photoData == nil { return coverDay.photo }
        return PhotoStyle.defaultCover(forCategoryID: categoryID) ?? coverDay?.photo ?? .systemDefault
    }

    var body: some View {
        NavigationLink(value: CategoryRoute.category(category.id)) {
            VStack(alignment: .leading, spacing: 1) {
                // Fills the row, which a neighbour with a longer name can make taller.
                Spacer(minLength: 0)
                if dynamicTypeSize.isAccessibilitySize {
                    // Room for the edit button, which large text would otherwise put over the icon.
                    name.padding(.top, category.isSystem ? 0 : Self.editButtonRoom)
                } else {
                    ViewThatFits(in: .horizontal) {
                        // One line beside the illustration, below the edit button.
                        name.lineLimit(1)
                            .padding(.trailing, Self.besideCover)
                            .padding(.top, Self.editButtonRoom)
                        // A longer name goes below it rather than under it.
                        name.lineLimit(2)
                            .padding(.top, Self.belowCover)
                    }
                }
                Text(String(localized: "\(count) 个日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.onPastel)
            }
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.vertical, Self.verticalPadding)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .bottomLeading)
            .background(alignment: .topTrailing) {
                if !dynamicTypeSize.isAccessibilitySize {
                    FlatCover(style: Self.cover(categoryID: category.id, coverDay: coverDay))
                        .frame(width: Self.coverSide, height: Self.coverSide)
                        .padding(Self.coverInset)
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
