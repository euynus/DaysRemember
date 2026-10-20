import SwiftUI

/// A thin bar filled to `fraction`, never shorter than a dot. Decorative: the text beside it
/// says the same thing.
struct ProgressCapsule: View {
    let fraction: Double
    let track: Color
    let fill: Color

    var body: some View {
        Capsule()
            .fill(track)
            .frame(height: 8)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(fill)
                        .frame(width: max(8, proxy.size.width * fraction))
                }
            }
            .accessibilityHidden(true)
    }
}
