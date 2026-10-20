import SwiftUI

/// The 将至 / 已过 switch, with each face's count.
struct HomeFacePicker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var face: HomeFace
    let upcoming: Int
    let past: Int

    var body: some View {
        HStack(spacing: 4) {
            faceButton(.upcoming, title: String(localized: "将至 · \(upcoming)", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                       identifier: "home.face.upcoming")
            faceButton(.past, title: String(localized: "已过 · \(past)", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                       identifier: "home.face.past")
        }
        .padding(3)
        .background(Theme.bg2, in: Capsule())
    }

    private func faceButton(_ value: HomeFace, title: String, identifier: String) -> some View {
        let selected = face == value
        return Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) { face = value }
        } label: {
            Text(title)
                .font(Theme.sans(14, weight: selected ? .heavy : .medium))
                .foregroundStyle(selected ? Theme.ink : Theme.ink2)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    if selected {
                        Capsule().fill(Theme.card)
                            .shadow(color: Theme.ink.opacity(0.08), radius: 3, y: 1)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}
