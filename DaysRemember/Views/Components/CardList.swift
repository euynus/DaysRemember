import SwiftUI

/// Unframed form sections with shared separators.
struct CardList<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

extension View {
    /// Standard grouped-list cell metrics (`.sg-cell`).
    func cardRow() -> some View {
        self.frame(minHeight: 56).padding(.horizontal, 18).padding(.vertical, 12)
    }
}
