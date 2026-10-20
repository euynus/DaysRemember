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
