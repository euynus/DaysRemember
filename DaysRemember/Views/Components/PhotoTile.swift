import SwiftUI
import UIKit

/// A photo placeholder — colored gradient + optional bottom-darkening scrim.
/// When `imageData` is non-nil it is rendered in place of the gradient.
struct PhotoTile: View {
    let style: PhotoStyle
    var imageData: Data? = nil
    var focusX: Double = 0.5
    var focusY: Double = 0.5
    var flat: Bool = false
    var cornerRadius: CGFloat = 20

    init(style: PhotoStyle, imageData: Data? = nil, focusX: Double = 0.5, focusY: Double = 0.5,
         flat: Bool = false, cornerRadius: CGFloat = 20) {
        self.style = style
        self.imageData = imageData
        self.focusX = focusX
        self.focusY = focusY
        self.flat = flat
        self.cornerRadius = cornerRadius
    }

    /// Convenience for callers that have a `Day`.
    init(day: Day, flat: Bool = false, cornerRadius: CGFloat = 20) {
        self.init(style: day.photo, imageData: day.photoData,
                  focusX: day.coverFocusX, focusY: day.coverFocusY,
                  flat: flat, cornerRadius: cornerRadius)
    }

    var body: some View {
        let pickedImage = imageData.flatMap { UIImage(data: $0) }
        // Real photographs cover the full color range; the gradient palette already
        // darkens at the bottom by design. So picked photos need a stronger scrim
        // (and an earlier ramp) to keep white overlay text legible.
        let scrimEndOpacity = pickedImage != nil ? 0.85 : 0.55
        let scrimStartY = pickedImage != nil ? 0.25 : 0.35

        ZStack {
            GeometryReader { geo in
                Group {
                    if let pickedImage {
                        focusedImage(pickedImage, in: geo.size)
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
        .accessibilityHidden(true)
    }

    private func focusedImage(_ image: UIImage, in container: CGSize) -> some View {
        let size = fillSize(image: image.size, in: container)
        let xOffset = (container.width - size.width) * CGFloat(min(1, max(0, focusX)))
        let yOffset = (container.height - size.height) * CGFloat(min(1, max(0, focusY)))

        return Image(uiImage: image)
            .resizable()
            .frame(width: size.width, height: size.height)
            .offset(x: xOffset, y: yOffset)
    }

    private func fillSize(image: CGSize, in container: CGSize) -> CGSize {
        guard image.width > 0, image.height > 0,
              container.width > 0, container.height > 0 else {
            return container
        }
        let imageAspect = image.width / image.height
        let containerAspect = container.width / container.height
        if imageAspect > containerAspect {
            return CGSize(width: container.height * imageAspect, height: container.height)
        }
        return CGSize(width: container.width, height: container.width / imageAspect)
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
