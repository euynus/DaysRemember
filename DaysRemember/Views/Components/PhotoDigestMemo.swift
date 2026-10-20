import Foundation

/// The digest of the photo a tile last drew, so an update that keeps the photo doesn't hash it
/// again. Held in `@State` as a cache that nothing observes.
final class PhotoDigestMemo {
    private var data: Data?
    private var digest = ""

    func digest(of data: Data) -> String {
        if let previous = self.data, previous.hasSameBytes(as: data) { return digest }
        digest = PhotoDecodeCache.digest(of: data)
        self.data = data
        return digest
    }
}
