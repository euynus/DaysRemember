import SwiftUI

/// Compact cover swatch with an explicit selection outline.
struct MiniPolaroid<Content: View>: View {
    let selected: Bool
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(5)
            .background(tint, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Theme.ink : .clear, lineWidth: 2.5)
            }
            .overlay(alignment: .bottomTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Theme.ink)
                        .padding(3)
                        .accessibilityHidden(true)
                }
            }
    }
}
