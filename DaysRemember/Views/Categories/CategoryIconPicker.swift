import SwiftUI

/// The icon grid.
struct CategoryIconPicker: View {
    @Binding var icon: String
    /// The icon the category was saved with, which the grid keeps offering; nil for a new one.
    let storedIcon: String?
    let colorToken: CategoryColorToken

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(String(localized: "图标", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                      spacing: 10) {
                // Offered from the stored icon, so picking another doesn't take it away.
                ForEach(CategoryEditorView.iconChoices(for: storedIcon ?? icon), id: \.symbol) { choice in
                    let selected = CategoryEditorView.isSelected(choice.symbol, icon: icon)
                    Button {
                        icon = choice.symbol
                    } label: {
                        Image(systemName: choice.symbol)
                            .font(Theme.symbol(24))
                            .foregroundStyle(selected ? Theme.accent : Theme.ink2)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 56)
                            .background(selected ? colorToken.soft : Color.white, in: .rect(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(selected ? colorToken.color : Theme.hairline,
                                                  lineWidth: selected ? 2 : 0.5)
                            }
                    }
                    .buttonStyle(PressScale(scale: 0.92))
                    .accessibilityLabel("图标 \(choice.label)")
                    .accessibilityIdentifier("category-icon-\(choice.symbol)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            // Five fixed columns; larger text would push the symbols out of their tiles.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }
}
