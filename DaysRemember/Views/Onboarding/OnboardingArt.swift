import SwiftUI

// Onboarding art areas — travel-scrapbook collages of tilted polaroids, stickers,
// clipped sticky notes and washi tape. Ports of WelcomeArt/CountArt/CollageArt/
// StartArt in screens/Onboarding.jsx; the surrounding `<div>`s are absolutely
// positioned, so each art view fills its area with a ZStack + offsets.

// MARK: - Small polaroid helper

/// A polaroid photo with an optional handwritten English caption underneath
/// (the `.polaroid` + `.sg-hand` block in the prototype).
private struct ArtPolaroid: View {
    let style: PhotoStyle
    var width: CGFloat
    var photoHeight: CGFloat
    var rotate: Double = 0
    var caption: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            PhotoTile(style: style, imageData: nil, focusX: 0.5, focusY: 0.5,
                      flat: true, cornerRadius: 12)
                .frame(width: width, height: photoHeight)
            if let caption {
                Text(caption)
                    .font(Theme.hand(20))
                    .foregroundStyle(Theme.ink2)
                    .frame(width: width, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
                    .padding(.bottom, 2)
            }
        }
        .polaroidCard(rotation: rotate)
    }
}

// MARK: - Page 1: welcome

struct WelcomeArt: View {
    var body: some View {
        ZStack {
            // Kyoto polaroid — top-left, tilted left.
            ArtPolaroid(style: .japan, width: 150, photoHeight: 180,
                        rotate: -7, caption: "Kyoto, Japan")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: 6, y: 18)
                .zIndex(2)

            // Wedding polaroid — top-right, tilted right.
            ArtPolaroid(style: .wedding, width: 140, photoHeight: 168,
                        rotate: 6, caption: "Our day")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: -4, y: 62)
                .zIndex(3)

            // Yellow sticky note pinned at the very top-right.
            StickyNote(color: Theme.noteYellow, ink: Theme.noteYellowInk,
                       rotate: 8, clip: true) { Text("记得每一天") }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: -20, y: 4)
                .zIndex(5)

            // Stickers.
            Sticker(name: .plane, size: 54, rotate: -12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .offset(x: 40, y: -24)
                .zIndex(6)
            Sticker(name: .heart, size: 40, rotate: 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: -30, y: -60)
                .zIndex(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Page 2: count

struct CountArt: View {
    var body: some View {
        ZStack {
            // Centered Hokkaido polaroid with an in-photo eyebrow + handwritten date.
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    PhotoTile(style: .japan, imageData: nil, focusX: 0.5, focusY: 0.5,
                              flat: false, cornerRadius: 12)
                        .frame(width: 220, height: 240)
                    Text("北海道旅行")
                        .font(Theme.sans(11, weight: .bold))
                        .tracking(1.8)
                        .foregroundStyle(Color.white.opacity(0.9))
                        .padding(.leading, 14)
                        .padding(.bottom, 12)
                }
                Text("20 Jul 2026")
                    .font(Theme.hand(22))
                    .foregroundStyle(Theme.ink2)
                    .frame(width: 220, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, 10)
                    .padding(.bottom, 2)
            }
            .polaroidCard(rotation: -2)

            // Blue countdown sticky note, top-right.
            StickyNote(color: Theme.noteBlue, ink: Theme.noteBlueInk,
                       rotate: 7, clip: true, size: .l) {
                VStack(spacing: 0) {
                    Text("88")
                        .font(Theme.sans(40, weight: .bold))
                        .monospacedDigit()
                    Text("天后").font(Theme.handCN(18))
                }
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .offset(x: -10, y: 40)
            .zIndex(5)

            // Sun sticker, bottom-left.
            Sticker(name: .sun, size: 44, rotate: -8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .offset(x: 26, y: -30)
                .zIndex(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Page 3: collage

struct CollageArt: View {
    var body: some View {
        ZStack {
            ArtPolaroid(style: .baby, width: 130, photoHeight: 150, rotate: -8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: 8, y: 22)
                .zIndex(2)

            ArtPolaroid(style: .birthday, width: 124, photoHeight: 140, rotate: 7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: -6, y: 8)
                .zIndex(3)

            ArtPolaroid(style: .home, width: 130, photoHeight: 150, rotate: 3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: 52, y: 142)
                .zIndex(4)

            // Camera sticker, mid-left.
            Sticker(name: .camera, size: 50, rotate: -14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: 0, y: 102)
                .zIndex(6)

            // Pink sticky note near the top center.
            StickyNote(color: Theme.notePink, ink: Theme.notePinkInk,
                       rotate: -6, clip: true) { Text("好久不见") }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: 102, y: -2)
                .zIndex(6)

            // Cake sticker, bottom-right.
            Sticker(name: .cake, size: 46, rotate: 9)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: -24, y: -20)
                .zIndex(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Page 4: start

struct StartArt: View {
    private let fan: [(style: PhotoStyle, rotate: Double)] = [
        (.wedding, -8), (.japan, 4), (.baby, -4),
    ]

    var body: some View {
        ZStack {
            // Overlapping fan of three small polaroids.
            HStack(spacing: -10) {
                ForEach(Array(fan.enumerated()), id: \.offset) { idx, item in
                    PhotoTile(style: item.style, imageData: nil, focusX: 0.5, focusY: 0.5,
                              flat: true, cornerRadius: 12)
                        .frame(width: 110, height: 130)
                        .polaroidCard(rotation: item.rotate)
                        .offset(x: CGFloat(idx) * -14)
                        .zIndex(Double(idx))
                }
            }

            // Green "开始吧!" sticky note, top-right.
            StickyNote(color: Theme.noteGreen, ink: Theme.noteGreenInk,
                       rotate: 8, clip: true) { Text("开始吧!") }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: -30, y: 40)
                .zIndex(6)

            // Star sticker, bottom-left.
            Sticker(name: .star, size: 40, rotate: -10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .offset(x: 36, y: -40)
                .zIndex(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
