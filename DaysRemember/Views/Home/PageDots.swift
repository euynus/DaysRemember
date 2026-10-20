import SwiftUI

struct PageDots: View {
    let index: Int
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(color.opacity(i == index ? 1 : 0.3))
                    .frame(width: i == index ? 16 : 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}
