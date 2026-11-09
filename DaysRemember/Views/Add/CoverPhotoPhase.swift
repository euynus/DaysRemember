import PhotosUI
import SwiftUI

/// The cover photo the user picked, on its way to the draft. Saving waits while it loads. A photo
/// that can't be read keeps the old cover and says so beside the photo button until another photo
/// or a template is chosen. The picker's selection is only ever the photo loading, so the same
/// photo can be picked again after it failed.
enum CoverPhotoPhase: Equatable {
    case idle
    /// Reading, downsampling and recompressing this photo (`CoverPhotoImport`).
    case loading(PhotosPickerItem)
    /// The last photo picked couldn't be read; the cover is as it was.
    case failed

    /// The picker's selection: the photo loading, if any.
    var item: PhotosPickerItem? {
        if case .loading(let item) = self { item } else { nil }
    }

    var isLoading: Bool { item != nil }

    /// The picker chose `item`, or cleared its selection, which stops a photo loading.
    mutating func pick(_ item: PhotosPickerItem?) {
        if let item { self = .loading(item) }
        else if isLoading { self = .idle }
    }

    /// The import of `item` ended. False, changing nothing, when another photo or a template
    /// replaced it meanwhile: then what it read mustn't reach the draft.
    @discardableResult
    mutating func finish(_ item: PhotosPickerItem, succeeded: Bool) -> Bool {
        guard self == .loading(item) else { return false }
        self = succeeded ? .idle : .failed
        return true
    }
}
