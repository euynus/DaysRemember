import SwiftUI

struct MetaItem {
    let text: String
    var color: Color = Theme.ink2
    var bold: Bool = false
}

/// Bullet-separated metadata line (`.meta` with `.dot` separators).
struct MetaRow: View {
    let items: [MetaItem]
    init(_ items: [MetaItem]) { self.items = items }
    init(_ strings: [String]) { self.items = strings.map { MetaItem(text: $0) } }

    var body: some View {
        FlowLayout(spacing: 9) {
            ForEach(items.enumerated(), id: \.offset) { idx, item in
                Text((idx > 0 ? "· " : "") + item.text)
                    .font(Theme.sans(12, weight: item.bold ? .semibold : .regular))
                    .foregroundStyle(item.color)
            }
        }
    }
}
