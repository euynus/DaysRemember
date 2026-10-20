import UIKit
import Photos

/// Saves a `UIImage` to Photos. Asks for permission on first call.
enum PhotoSaver {
    enum SaveError: Error { case denied, failed }

    static func save(image: UIImage) async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let granted: Bool
        switch status {
        case .authorized, .limited:
            granted = true
        case .notDetermined:
            let answer = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            granted = answer == .authorized || answer == .limited
        default:
            granted = false
        }
        guard granted else { throw SaveError.denied }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}
