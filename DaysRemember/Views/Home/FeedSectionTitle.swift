import SwiftUI

/// A feed section's heading with how many days it holds.
struct FeedSectionTitle: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.sans(17, weight: .heavy, relativeTo: .headline))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Text("\(count)")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }
}
