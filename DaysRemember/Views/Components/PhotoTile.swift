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
        // Sample count + head/middle/tail bytes. Header-only keys collide for images
        // that share a JFIF/EXIF prefix and length (e.g. same-camera shots); sampling
        // three regions makes a collision astronomically unlikely.
        var key = "\(data.count):"
        data.withUnsafeBytes { raw in
            let buf = raw.bindMemory(to: UInt8.self)
            guard buf.count > 0 else { return }
            for start in [0, max(0, buf.count / 2 - 4), max(0, buf.count - 8)] {
                for i in start..<min(start + 8, buf.count) {
                    key.append(String(buf[i], radix: 16))
                }
            }
        }
        return key as NSString
    }
}

/// User photos take precedence over bundled covers; both obey the same clipping bounds.
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
        // Retain the optional scrim for callers that place white text over a cover.
        let scrimEndOpacity = pickedImage != nil ? 0.85 : 0.55
        let scrimStartY = pickedImage != nil ? 0.25 : 0.35

        GeometryReader { geometry in
            ZStack {
                if let pickedImage {
                    focusedImage(pickedImage, in: geometry.size)
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                } else {
                    style.background()
                        .frame(width: geometry.size.width, height: geometry.size.height)
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
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // Clipping pixels does not clip hit testing for a scaled-to-fill image.
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
