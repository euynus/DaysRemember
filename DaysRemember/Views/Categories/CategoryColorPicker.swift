import SwiftUI

/// The five category colours.
struct CategoryColorPicker: View {
    @Binding var colorToken: CategoryColorToken

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(String(localized: "颜色", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            HStack(spacing: 12) {
                ForEach(CategoryColorToken.allCases) { token in
                    let selected = colorToken == token
                    Button { colorToken = token } label: {
                        Circle()
                            .fill(token.color)
                            .frame(width: 38, height: 38)
                            .frame(minWidth: 44, minHeight: 44)
                            .overlay {
                                Circle().strokeBorder(Color.white, lineWidth: selected ? 3 : 0)
                            }
                            .overlay {
                                Circle().strokeBorder(token.color, lineWidth: selected ? 2 : 0)
                                    .padding(-3)
                            }
                            .shadow(color: Color(hex: 0x15171C).opacity(0.12), radius: 3, x: 0, y: 2)
                    }
                    .buttonStyle(PressScale(scale: 0.9))
                    .accessibilityLabel("颜色 \(token.label)")
                    .accessibilityIdentifier("category-color-\(token.rawValue)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
                Spacer()
            }
        }
    }
}
