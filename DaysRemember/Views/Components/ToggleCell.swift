import SwiftUI

struct ToggleCell: View {
    let label: String
    var sub: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(Theme.sans(15)).foregroundStyle(Theme.ink)
                if let sub {
                    Text(sub).font(Theme.sans(12)).foregroundStyle(Theme.ink2)
                }
            }
        }
        .tint(Theme.accent)
        .cardRow()
    }
}
