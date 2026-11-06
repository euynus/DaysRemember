import SwiftUI

/// The category on its colour, as its tile in 我的 shows it: the illustration in the corner, then its
/// icon and name and the colour's name.
struct CategoryEditorPreview: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let name: String
    let icon: String
    let colorToken: CategoryColorToken
    let cover: PhotoStyle

    var body: some View {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(alignment: .leading, spacing: 2) {
            // Above the name rather than beside it, so a long name never runs under it.
            if !dynamicTypeSize.isAccessibilitySize {
                FlatCover(style: cover)
                    .frame(width: 76, height: 76)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.bottom, 4)
            }
            Label {
                Text(trimmed.isEmpty ? String(localized: "分类名称", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : trimmed)
                    .foregroundStyle(trimmed.isEmpty ? Theme.onPastel : Theme.ink)
            } icon: {
                Image(systemName: CategoryDefinition.symbolName(for: icon))
                    .foregroundStyle(colorToken.color)
            }
            .font(Theme.sans(20, weight: .heavy, relativeTo: .title3))
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            .multilineTextAlignment(.leading)
            Text(colorToken.label)
                .font(Theme.sans(12, weight: .bold))
                .foregroundStyle(colorToken.color)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorToken.soft, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
