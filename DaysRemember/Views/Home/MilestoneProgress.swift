import SwiftUI

/// A thin bar toward the next round number, with when it lands.
struct MilestoneProgress: View {
    let milestone: Milestone
    let ink: Color

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(Color.white.opacity(0.8))
                .frame(height: 8)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule().fill(ink)
                            .frame(width: max(8, proxy.size.width * milestone.progress))
                    }
                }
                .accessibilityHidden(true)
            Text(DayCardText.milestone(milestone))
                .font(Theme.sans(12, weight: .bold))
                .foregroundStyle(ink)
                .lineLimit(1)
                .fixedSize()
        }
    }
}
