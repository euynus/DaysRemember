import SwiftUI

/// A preset cover's flat illustration, fitted inside its frame.
struct FlatCover: View {
    let style: PhotoStyle

    var body: some View {
        Image(style.assetName)
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}
