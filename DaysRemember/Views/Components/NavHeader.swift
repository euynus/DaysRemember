import SwiftUI

/// A screen's title: on a tab's root, as large as and level with the other tabs' titles; in a
/// sheet, smaller, with a close button at the end.
struct NavHeader: View {
    let title: String
    /// Closes the sheet the header heads.
    var onClose: (() -> Void)? = nil

    var body: some View {
        let inSheet = onClose != nil
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if !inSheet {
                    // The other tabs put a line above their titles (the lunar date, the year); an
                    // empty one keeps this title level with theirs.
                    Text(verbatim: " ")
                        .font(Theme.sans(13, weight: .bold))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(inSheet ? Theme.sans(19, weight: .medium, relativeTo: .headline)
                                  : Theme.sans(30, weight: .heavy, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(inSheet ? 2 : 1)
                    .minimumScaleFactor(0.5)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 8)
            if let onClose {
                FAB(systemName: "xmark", size: 42, iconSize: 16, action: onClose)
                    .accessibilityLabel("关闭")
                    .accessibilityIdentifier("sheet.close")
            }
        }
        // A tab's title lines up with the other tabs' headers; a sheet's with its controls.
        .padding(.horizontal, inSheet ? 24 : 20)
        .padding(.top, inSheet ? 16 : 12)
        .padding(.bottom, inSheet ? 16 : 10)
    }
}
