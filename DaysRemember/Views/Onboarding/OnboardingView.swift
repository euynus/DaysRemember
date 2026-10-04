import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("时光")
                    .font(Theme.sans(32, weight: .medium))
                    .foregroundStyle(Theme.ink)
                PhotoTile(style: .systemDefault, flat: true, cornerRadius: 3)
                    .frame(height: 340)
                Text("值得记住的每一天")
                    .font(Theme.sans(24, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text("从今天开始。")
                    .font(Theme.sans(17))
                    .foregroundStyle(Theme.ink2)
            }
            .padding(28)
        }
        .safeAreaInset(edge: .bottom) {
            PillButton(title: String(localized: "开始记录"), trailingSystemName: "arrow.right", fill: true, action: onFinish)
                .padding(24)
                .background(Theme.bg)
        }
        .background(Theme.bg)
    }
}
