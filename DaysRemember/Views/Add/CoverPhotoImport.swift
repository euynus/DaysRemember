import Foundation

/// Turns a picked photo into a cover: downsampled and recompressed off the main actor, and
/// abandoned as soon as its task is cancelled (another photo or a template was chosen).
@MainActor
enum CoverPhotoImport {
    /// `data` is the picked item's contents; nil, or bytes that aren't an image, fail as a corrupt file.
    static func cover(from data: Data?) async throws -> Data {
        guard let data else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try Task.checkCancellation()
        let compressed = await PhotoDecodeCache.compressedJPEGInBackground(from: data)
        try Task.checkCancellation()
        guard let compressed else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return compressed
    }
}
