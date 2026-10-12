import Foundation
@testable import DaysRemember

/// What a test changes when it uses the app's shared library through `DayStore()`: the stored
/// records and the photo files they use. Putting back only the records would leave references to
/// photos the store deleted once nothing used them, and the next store couldn't load.
struct SharedLibrarySnapshot {
    private let values: [(String, Any?)]
    private let photos: [URL: Data]

    init(keys: [String]) {
        values = keys.map { ($0, SharedStorage.defaults.object(forKey: $0)) }
        let files = (try? FileManager.default.contentsOfDirectory(at: SharedStorage.photoDirectory,
                                                                 includingPropertiesForKeys: nil)) ?? []
        photos = Dictionary(uniqueKeysWithValues: files.compactMap { url in
            (try? Data(contentsOf: url)).map { (url, $0) }
        })
    }

    func restore() {
        for (key, value) in values { SharedStorage.defaults.set(value, forKey: key) }
        try? FileManager.default.createDirectory(at: SharedStorage.photoDirectory, withIntermediateDirectories: true)
        for (url, data) in photos where !FileManager.default.fileExists(atPath: url.path) {
            try? data.write(to: url)
        }
    }
}
