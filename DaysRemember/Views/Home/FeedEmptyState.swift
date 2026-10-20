import SwiftUI

/// A face, or a search, with no days to show.
struct FeedEmptyState: View {
    let title: String
    let symbol: String
    let detail: String

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(detail))
            .foregroundStyle(Theme.muted)
            .padding(.top, 40)
    }
}
