import SwiftUI

struct CategoryTile: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let category: CategoryDefinition
    let coverDay: Day?
    let count: Int
    var onEdit: () -> Void

    var body: some View {
        NavigationLink(value: CategoryRoute.category(category.id)) {
            VStack(alignment: .leading, spacing: 12) {
                Rectangle()
                    .fill(category.colorToken.soft)
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    .overlay {
                        if let coverDay {
                            // A ~170 pt tile never needs the 1600 px full cover.
                            PhotoTile(day: coverDay, flat: true, cornerRadius: 3, maximumPixelSize: 512,
                                      decodesAsynchronously: true)
                        } else {
                            Image(systemName: category.symbolName)
                                .font(.system(size: 30, weight: .light))
                                .foregroundStyle(category.colorToken.color)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Label(category.displayName, systemImage: category.symbolName)
                        .font(Theme.sans(15, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(count)")
                        .font(Theme.number(22))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
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
        .overlay(alignment: .topTrailing) {
            if !category.isSystem {
                Button(action: onEdit) {
                    Label("编辑分类", systemImage: "pencil")
                        .labelStyle(.iconOnly)
                        .font(.body.weight(.medium))
                        .frame(minWidth: 44, minHeight: 44)
                        .foregroundStyle(Theme.ink)
                        .background(Theme.bg, in: Circle())
                        .overlay {
                            Circle().strokeBorder(Theme.hairlineStrong, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("编辑\(category.displayName)")
                .accessibilityIdentifier("editCategory-\(category.id)")
                .help("编辑分类")
                .padding(6)
            }
        }
    }
}
