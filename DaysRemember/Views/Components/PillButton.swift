import SwiftUI

struct PillButton: View {
    enum Style { case dark, white, ghost }
    let title: String
    var style: Style = .dark
    var trailingSystemName: String? = nil
    var fill: Bool = false      // expand to full width
    var height: CGFloat = 48
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text(title).font(Theme.sans(15, weight: .heavy))
                if let t = trailingSystemName {
                    Image(systemName: t).font(Theme.symbol(16, weight: .bold))
                }
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: fill ? .infinity : nil)
            .frame(minHeight: height)
            .padding(.horizontal, 22)
            .background(background, in: .capsule)
        }
        .buttonStyle(PressScale())
    }

    private var foreground: Color {
        switch style { case .dark: return .white; case .white, .ghost: return Theme.ink }
    }
    private var background: Color {
        switch style { case .dark: return Theme.accent; case .white: return .white; case .ghost: return Theme.bg2 }
    }
}
