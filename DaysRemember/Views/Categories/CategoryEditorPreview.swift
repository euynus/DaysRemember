import SwiftUI

/// The category as it will look: its icon on its colour, its name and the colour's name.
struct CategoryEditorPreview: View {
    let name: String
    let icon: String
    let colorToken: CategoryColorToken

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: CategoryDefinition.symbolName(for: icon))
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(colorToken.color)
                .frame(width: 56, height: 56)
                .background(colorToken.soft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(name.isEmpty ? String(localized: "分类名称", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : name)
                    .font(Theme.sans(22, weight: .medium))
                    .foregroundStyle(name.isEmpty ? Theme.muted : Theme.ink)
                Text(colorToken.label)
                    .font(Theme.sans(12, weight: .bold))
                    .foregroundStyle(colorToken.color)
            }
            Spacer()
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) { RowDivider() }
    }
}
