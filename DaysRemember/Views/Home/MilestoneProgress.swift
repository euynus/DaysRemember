import SwiftUI

/// A thin bar toward the next round number, with when it lands.
struct MilestoneProgress: View {
    let milestone: Milestone
    let ink: Color

    var body: some View {
        HStack(spacing: 10) {
            ProgressCapsule(fraction: milestone.progress, track: Color.white.opacity(0.8), fill: ink)
            Text(DayCardText.milestone(milestone))
                .font(Theme.sans(12, weight: .bold))
                .foregroundStyle(ink)
                .lineLimit(1)
                .fixedSize()
        }
    }
}
