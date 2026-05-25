import SwiftUI

/// Selectable pill — softly tinted when active, card fill otherwise.
struct FilterChip: View {
    let label: String
    let active: Bool
    var tint: Color = Theme.terracotta
    var softTint: Color = Theme.terracottaSoft
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.sans(13, weight: .medium))
                .foregroundStyle(active ? tint : Theme.ink2)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(active ? softTint : Theme.card)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(active ? tint.opacity(0.28) : Theme.hairline, lineWidth: 0.5)
                }
                .shadow(color: active ? .clear : .black.opacity(0.04), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }
}

/// Uppercase, 0.2em-tracked section label (e.g. "封面", "分类").
struct SectionLabel: View {
    let text: String
    var color: Color? = nil
    var body: some View {
        Text(text)
            .font(Theme.sans(11, weight: .semibold))
            .tracking(2.2) // ≈ 0.2em at 11pt
            .foregroundStyle(color ?? Theme.muted)
    }
}
