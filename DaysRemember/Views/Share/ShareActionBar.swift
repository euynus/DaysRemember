import SwiftUI

/// 保存 and 分享图片 under the card; stacked at accessibility sizes.
struct ShareActionBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var onSave: () -> Void = {}
    var onShare: () -> Void = {}

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 16))
        return layout {
            Button(action: onSave) {
                Label("保存", systemImage: "square.and.arrow.down")
                    .font(Theme.sans(16, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, minHeight: 52)
                    .background(Theme.card, in: Capsule())
            }
            .buttonStyle(PressScale(scale: 0.97))
            Button(action: onShare) {
                Label("分享图片", systemImage: "square.and.arrow.up")
                    .font(Theme.sans(16, weight: .heavy))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Theme.ink, in: Capsule())
            }
            .buttonStyle(PressScale(scale: 0.97))
        }
    }
}
