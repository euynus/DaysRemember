import SwiftUI
import UIKit
import ImageIO
import CryptoKit

/// Share pixel-bounded bitmaps across list rows, previews and widget snapshots.
enum PhotoDecodeCache {
    private static let storage: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 64
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    static func decoded(_ data: Data, maximumPixelSize: CGFloat) -> UIImage? {
        guard let key = key(for: data, maximumPixelSize: maximumPixelSize) else { return nil }
        if let cached = storage.object(forKey: key) { return cached }
        guard let image = downsample(data, maximumPixelSize: maximumPixelSize) else { return nil }
        store(image, forKey: key)
        return image
    }

    /// A cache lookup that never decodes, for views that decode off the main actor.
    static func cached(_ data: Data, maximumPixelSize: CGFloat) -> UIImage? {
        key(for: data, maximumPixelSize: maximumPixelSize).flatMap { storage.object(forKey: $0) }
    }

    private static func key(for data: Data, maximumPixelSize: CGFloat) -> NSString? {
        guard maximumPixelSize.isFinite, maximumPixelSize >= 1 else { return nil }
        let digest = Data(SHA256.hash(data: data)).base64EncodedString()
        return "photo:\(digest):\(maximumPixelSize)" as NSString
    }

    static func bundled(_ name: String, maximumPixelSize: CGFloat) -> UIImage? {
        let key = "asset:\(name):\(maximumPixelSize)" as NSString
        if let cached = storage.object(forKey: key) { return cached }
        guard let original = UIImage(named: name),
              let image = PhotoTile.thumbnail(original, maximumPixelSize: maximumPixelSize) else { return nil }
        store(image, forKey: key)
        return image
    }

    private static func store(_ image: UIImage, forKey key: NSString) {
        guard let bitmap = image.cgImage else { return }
        storage.setObject(image, forKey: key, cost: bitmap.bytesPerRow * bitmap.height)
    }

    static func downsample(_ data: Data, maximumPixelSize: CGFloat) -> UIImage? {
        guard maximumPixelSize.isFinite, maximumPixelSize >= 1,
              let source = CGImageSourceCreateWithData(data as CFData,
                  [kCGImageSourceShouldCache: false] as CFDictionary),
              let bitmap = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
                  kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: bitmap)
    }

    static func compressedJPEG(from data: Data) -> Data? {
        downsample(data, maximumPixelSize: 1600)?.jpegData(compressionQuality: 0.82)
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
    var maximumPixelSize: CGFloat = 1600
    /// Scrolling lists decode uncached photos off the main actor and show plain paper
    /// meanwhile. Widgets and image exports must stay synchronous.
    var decodesAsynchronously = false
    @State private var loadedImage: UIImage?

    init(style: PhotoStyle, imageData: Data? = nil, focusX: Double = 0.5, focusY: Double = 0.5,
         flat: Bool = false, cornerRadius: CGFloat = 20, maximumPixelSize: CGFloat = 1600,
         decodesAsynchronously: Bool = false) {
        self.style = style
        self.imageData = imageData
        self.focusX = focusX
        self.focusY = focusY
        self.flat = flat
        self.cornerRadius = cornerRadius
        self.maximumPixelSize = maximumPixelSize
        self.decodesAsynchronously = decodesAsynchronously
    }

    /// Convenience for callers that have a `Day`.
    init(day: Day, flat: Bool = false, cornerRadius: CGFloat = 20, maximumPixelSize: CGFloat = 1600,
         decodesAsynchronously: Bool = false) {
        self.init(style: day.photo, imageData: day.photoData,
                  focusX: day.coverFocusX, focusY: day.coverFocusY,
                  flat: flat, cornerRadius: cornerRadius, maximumPixelSize: maximumPixelSize,
                  decodesAsynchronously: decodesAsynchronously)
    }

    var body: some View {
        let pickedImage = imageData.flatMap { data in
            decodesAsynchronously
                ? PhotoDecodeCache.cached(data, maximumPixelSize: maximumPixelSize) ?? loadedImage
                : PhotoDecodeCache.decoded(data, maximumPixelSize: maximumPixelSize)
        }
        let awaitingPhoto = imageData != nil && pickedImage == nil && decodesAsynchronously
        let image = pickedImage ?? PhotoDecodeCache.bundled(style.assetName, maximumPixelSize: maximumPixelSize)
        // Retain the optional scrim for callers that place white text over a cover.
        let scrimEndOpacity = pickedImage != nil ? 0.85 : 0.55
        let scrimStartY = pickedImage != nil ? 0.25 : 0.35

        GeometryReader { geometry in
            ZStack {
                if awaitingPhoto {
                    Theme.coverPaper
                } else if let pickedImage {
                    focusedImage(pickedImage, in: geometry.size)
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                } else if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .mask { Self.featheredEdges }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .background(Theme.coverPaper)
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
        .task(id: decodesAsynchronously ? imageData : nil) {
            guard decodesAsynchronously, let data = imageData else { return }
            loadedImage = nil
            guard PhotoDecodeCache.cached(data, maximumPixelSize: maximumPixelSize) == nil else { return }
            let size = maximumPixelSize
            let image = await Task.detached(priority: .userInitiated) {
                PhotoDecodeCache.decoded(data, maximumPixelSize: size)
            }.value
            if !Task.isCancelled { loadedImage = image }
        }
    }

    /// Feathers the artwork's paper texture into the letterbox fill, so a fitted
    /// illustration never shows a hard rectangular edge in wider or taller frames.
    static var featheredEdges: some View {
        let stops: [Gradient.Stop] = [
            .init(color: .clear, location: 0), .init(color: .black, location: 0.06),
            .init(color: .black, location: 0.94), .init(color: .clear, location: 1),
        ]
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
            .mask(LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom))
    }

    static func thumbnail(_ image: UIImage, maximumPixelSize: CGFloat) -> UIImage? {
        guard maximumPixelSize.isFinite, maximumPixelSize >= 1,
              image.size.width > 0, image.size.height > 0 else { return nil }
        if let bitmap = image.cgImage,
           CGFloat(max(bitmap.width, bitmap.height)) <= maximumPixelSize, image.imageOrientation == .up {
            return image
        }
        let scale = min(1, maximumPixelSize / (max(image.size.width, image.size.height) * image.scale))
        return image.preparingThumbnail(of: CGSize(width: image.size.width * scale,
                                                   height: image.size.height * scale))
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
