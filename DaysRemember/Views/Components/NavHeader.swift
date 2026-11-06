import SwiftUI

/// A screen's title, large on a tab's root; in a sheet, smaller with a close button at the end.
struct NavHeader<Trailing: View>: View {
    let title: String
    /// Closes the sheet the header heads.
    var onClose: (() -> Void)? = nil
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(Theme.sans(onClose == nil ? 28 : 19, weight: .medium,
                                 relativeTo: onClose == nil ? .largeTitle : .headline))
                .foregroundStyle(Theme.ink)
                .lineLimit(onClose == nil ? 1 : 2)
                .minimumScaleFactor(0.5)
            Spacer(minLength: 8)
            trailing
            if let onClose {
                FAB(systemName: "xmark", size: 42, iconSize: 16, action: onClose)
                    .accessibilityLabel("关闭")
                    .accessibilityIdentifier("sheet.close")
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }
}

extension NavHeader where Trailing == EmptyView {
    init(title: String, onClose: (() -> Void)? = nil) {
        self.init(title: title, onClose: onClose, trailing: { EmptyView() })
    }
}
