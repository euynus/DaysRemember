import SwiftUI

/// The detail's cover card: a preset's flat illustration on the category pastel, or the user's
/// photo filling the card. A photo has no size of its own, so the card gives it one; left to the
/// scroll view it would collapse to a sliver.
struct DetailCover: View {
    let day: Day
    let tint: Color
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let side: CGFloat = dynamicTypeSize.isAccessibilitySize ? 160 : 240
        if day.photoData != nil {
            PhotoTile(day: day, flat: true, cornerRadius: 30, maximumPixelSize: 1600)
                .frame(maxWidth: .infinity)
                .frame(height: side + 48)
        } else {
            FlatCover(style: day.photo)
                .frame(maxWidth: side, maxHeight: side)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(tint, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
    }
}
