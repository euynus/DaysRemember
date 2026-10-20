import SwiftUI

struct Chip<Leading: View>: View {
    let title: String
    var selected: Bool = false
    let leading: Leading
    var action: () -> Void = {}

    init(_ title: String, selected: Bool = false, @ViewBuilder leading: () -> Leading,
         action: @escaping () -> Void = {}) {
        self.title = title; self.selected = selected; self.leading = leading(); self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                leading
                Text(title).font(Theme.sans(14, weight: .medium))
            }
            .foregroundStyle(selected ? Color.white : Theme.ink2)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .padding(.horizontal, 15)
            .background(selected ? Theme.ink : Theme.card, in: .capsule)
        }
        .buttonStyle(PressScale(scale: 0.95))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

extension Chip where Leading == EmptyView {
    init(_ title: String, selected: Bool = false, action: @escaping () -> Void = {}) {
        self.init(title, selected: selected, leading: { EmptyView() }, action: action)
    }
}
