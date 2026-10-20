import SwiftUI

/// Hairline divider between grouped-list cells, inset to match `.sg-cell` borders.
struct RowDivider: View {
    var body: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }
}
