import SwiftUI

struct NavHeader<Trailing: View>: View {
    let title: String
    var onBack: (() -> Void)? = nil
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            if let onBack {
                FAB(systemName: "chevron.left", size: 42, action: onBack)
                    .accessibilityLabel("返回")
            }
            Text(title)
                .font(Theme.sans(onBack == nil ? 28 : 19, weight: .medium,
                                 relativeTo: onBack == nil ? .largeTitle : .headline))
                .foregroundStyle(Theme.ink)
                .lineLimit(onBack == nil ? 1 : 2)
                .minimumScaleFactor(0.5)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }
}

extension NavHeader where Trailing == EmptyView {
    init(title: String, onBack: (() -> Void)? = nil) {
        self.init(title: title, onBack: onBack, trailing: { EmptyView() })
    }
}
