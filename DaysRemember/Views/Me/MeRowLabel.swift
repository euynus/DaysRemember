import SwiftUI

/// Icon tile, title, optional value and a chevron.
struct MeRowLabel: View {
    let title: String
    let systemImage: String
    let tint: Color
    let ink: Color
    var value: String? = nil
    var valueColor = Theme.muted
    var showsChevron = true
    var trailingSymbol = "chevron.right"

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ink)
                .frame(width: 32, height: 32)
                .background(tint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            Text(title)
                .font(Theme.sans(16, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let value {
                Text(verbatim: value)
                    .font(Theme.sans(15))
                    .foregroundStyle(valueColor)
                    .multilineTextAlignment(.trailing)
            }
            if showsChevron {
                Image(systemName: trailingSymbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}
