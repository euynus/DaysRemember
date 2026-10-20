import SwiftUI

struct FAB: View {
    let systemName: String
    var size: CGFloat = 46
    var iconSize: CGFloat = 18
    var dark: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .regular))
                .foregroundStyle(dark ? Color.white : Theme.ink)
                .frame(width: size, height: size)
                .background(dark ? Theme.accent : Color.white, in: .circle)
                .overlay { Circle().strokeBorder(dark ? .clear : Theme.hairline, lineWidth: 1) }
                // Keep the tappable area at the 44pt HIG minimum even when the visible
                // circle is smaller (e.g. the 38/42pt calendar & header FABs).
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScale(scale: 0.9))
    }
}
