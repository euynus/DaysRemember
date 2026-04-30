import SwiftUI
import UIKit

/// A photo placeholder — colored gradient + optional bottom-darkening scrim.
/// When `imageData` is non-nil it is rendered in place of the gradient.
struct PhotoTile: View {
    let style: PhotoStyle
    var imageData: Data? = nil
    var flat: Bool = false
    var cornerRadius: CGFloat = 20

    init(style: PhotoStyle, imageData: Data? = nil, flat: Bool = false, cornerRadius: CGFloat = 20) {
        self.style = style
        self.imageData = imageData
        self.flat = flat
        self.cornerRadius = cornerRadius
    }

    /// Convenience for callers that have a `Day`.
    init(day: Day, flat: Bool = false, cornerRadius: CGFloat = 20) {
        self.init(style: day.photo, imageData: day.photoData, flat: flat, cornerRadius: cornerRadius)
    }

    var body: some View {
        let renderingPhoto = imageData.flatMap { UIImage(data: $0) } != nil
        // Real photographs cover the full color range; the gradient palette already
        // darkens at the bottom by design. So picked photos need a stronger scrim
        // (and an earlier ramp) to keep white overlay text legible.
        let scrimEndOpacity = renderingPhoto ? 0.85 : 0.55
        let scrimStartY = renderingPhoto ? 0.25 : 0.35

        ZStack {
            GeometryReader { geo in
                Group {
                    if let data = imageData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                    } else {
                        style.background()
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }
            if !flat {
                LinearGradient(
                    colors: [.black.opacity(0), .black.opacity(scrimEndOpacity)],
                    startPoint: UnitPoint(x: 0.5, y: scrimStartY),
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    /// 180° gradient overlay that matches `.photo::after` in `styles.css`.
    func bottomScrim(opacity: Double = 0.55) -> some View {
        overlay {
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(opacity)],
                startPoint: UnitPoint(x: 0.5, y: 0.35),
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
    }
}
