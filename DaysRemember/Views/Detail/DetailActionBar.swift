import SwiftUI

/// Edit and share, pinned above the home indicator.
struct DetailActionBar: View {
    var onEdit: () -> Void = {}
    var onShare: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            Button { onEdit() } label: {
                Label("编辑", systemImage: "pencil")
                    .font(Theme.sans(16, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 22)
                    .frame(minHeight: 54)
                    .background(Theme.card, in: Capsule())
            }
            .accessibilityIdentifier("detail.edit")
            Button { onShare() } label: {
                Label("分享这一天", systemImage: "square.and.arrow.up")
                    .font(Theme.sans(16, weight: .heavy))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Theme.ink, in: Capsule())
            }
        }
        .buttonStyle(PressScale(scale: 0.97))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .background(Theme.bg.opacity(0.94))
    }
}
