import SwiftUI

/// A white rounded group of rows.
struct MeGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
