import SwiftUI

/// Selectable pill — ink fill when active, card fill otherwise.
struct FilterChip: View {
    let label: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.sans(13, weight: .medium))
                .foregroundStyle(active ? Theme.bg : Theme.ink2)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(active ? Theme.ink : Theme.card)
                .clipShape(Capsule())
                .shadow(color: active ? .clear : .black.opacity(0.04), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
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
