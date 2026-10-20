import UIKit
import ImageIO
import CryptoKit

/// Share pixel-bounded bitmaps across list rows, previews and widget snapshots.
enum PhotoDecodeCache {
    // NSCache is thread-safe, though the SDK does not mark it Sendable.
    nonisolated(unsafe) private static let storage: NSCache<NSString, UIImage> = {
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

    /// Drops every entry, as memory pressure may.
    static func removeAll() { storage.removeAllObjects() }

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

    /// `decoded(_:maximumPixelSize:)` off the main actor, for lists that decode while scrolling.
    @concurrent static func decodedInBackground(_ data: Data, maximumPixelSize: CGFloat) async -> UIImage? {
        decoded(data, maximumPixelSize: maximumPixelSize)
    }

    /// `compressedJPEG(from:)` off the main actor, for an imported photo.
    @concurrent static func compressedJPEGInBackground(from data: Data) async -> Data? {
        autoreleasepool { compressedJPEG(from: data) }
    }
}
