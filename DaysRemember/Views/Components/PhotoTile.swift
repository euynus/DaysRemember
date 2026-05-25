import SwiftUI
import UIKit

/// Process-wide LRU for decoded user photos. Each `UIImage(data:)` produces a fresh
/// instance with its own lazy-decoded bitmap; without sharing, every grid re-render
/// re-decodes the same JPEG. Keyed by a fingerprint (count + first 8 bytes) so the
/// lookup is O(1) and content-stable across `Day` value-type copies.
private enum PhotoDecodeCache {
    static let storage: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 64
        return cache
    }()

    static func decoded(_ data: Data) -> UIImage? {
        let key = fingerprint(data)
        if let cached = storage.object(forKey: key) { return cached }
        guard let image = UIImage(data: data) else { return nil }
        storage.setObject(image, forKey: key)
        return image
    }

    private static func fingerprint(_ data: Data) -> NSString {
        // Two different JPEGs almost always differ in either total length or the first
        // few header bytes (JFIF/EXIF markers vary). 9 chars: count + 8 prefix bytes.
        var key = "\(data.count):"
        data.withUnsafeBytes { buf in
            for byte in buf.bindMemory(to: UInt8.self).prefix(8) {
                key.append(String(byte, radix: 16))
            }
        }
        return key as NSString
    }
}

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
        let pickedImage = imageData.flatMap(PhotoDecodeCache.decoded)
        // Real photographs cover the full color range; the gradient palette already
        // darkens at the bottom by design. So picked photos need a stronger scrim
        // (and an earlier ramp) to keep white overlay text legible.
        let scrimEndOpacity = pickedImage != nil ? 0.85 : 0.55
        let scrimStartY = pickedImage != nil ? 0.25 : 0.35

        ZStack {
            // Only the picked-photo path needs GeometryReader — it positions the
            // image within its container according to the focus point. The gradient
            // and rasterized hand-drawn covers fill naturally.
            if let pickedImage {
                GeometryReader { geo in
                    focusedImage(pickedImage, in: geo.size)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            } else {
                style.background()
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

