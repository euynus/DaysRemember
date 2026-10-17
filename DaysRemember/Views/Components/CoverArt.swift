import SwiftUI

/// Card art for the pastel layouts. A preset cover is the flat illustration drawn
/// directly on the card colour; a user's photo keeps its own rendering in a rounded tile.
struct CoverArt: View {
    let day: Day
    var photoCornerRadius: CGFloat = 16
    var maximumPixelSize: CGFloat = 512
    var decodesAsynchronously = false

    var body: some View {
        if day.photoData != nil {
            PhotoTile(day: day, flat: true, cornerRadius: photoCornerRadius,
                      maximumPixelSize: maximumPixelSize, decodesAsynchronously: decodesAsynchronously)
        } else {
            FlatCover(style: day.photo)
        }
    }
}

/// A preset cover's flat illustration, fitted inside its frame.
struct FlatCover: View {
    let style: PhotoStyle

    var body: some View {
        Image(style.flatAssetName)
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

extension CategoryDefinition {
    /// The pastel card colour.
    var tint: Color { colorToken.soft }
    /// Text and marks drawn on the pastel.
    var tintInk: Color { colorToken.color }
}
