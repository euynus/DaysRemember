import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("时光")
                    .font(Theme.sans(42, weight: .bold))
                    .foregroundStyle(Theme.ink)
                PhotoTile(style: .sketchTravel, flat: true, cornerRadius: 8)
                    .frame(height: 320)
                Text("值得记住的每一天")
                    .font(Theme.sans(28, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text("从今天开始。")
                    .font(Theme.sans(17))
                    .foregroundStyle(Theme.ink2)
            }
            .padding(28)
        }
        .safeAreaInset(edge: .bottom) {
            PillButton(title: "开始记录", trailingSystemName: "arrow.right", fill: true, action: onFinish)
                .padding(24)
                .background(Theme.bg)
        }
        .background(Theme.bg)
    }
}
