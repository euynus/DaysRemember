import Foundation

/// UserDefaults backing for data that is shared with the widget extension via App Group.
///
/// Falls back to `.standard` if the App Group entitlement isn't configured (e.g. while
/// running unit tests, or before code-signing has wired up the group capability) so the
/// app stays functional even without the widget — the widget just won't see fresh data.
enum SharedStorage {
    static let appGroupID = "group.com.shiguang.daysremember"
    static let daysKey = "days.v2"
    static let legacyDaysKey = "days.v1"

    static let defaults: UserDefaults = {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }()

    static var photoDirectory: URL {
        let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent("DayPhotos", isDirectory: true)
    }

    static func loadDays(defaults: UserDefaults = SharedStorage.defaults,
                         photoDirectory: URL = SharedStorage.photoDirectory) -> [Day] {
        guard let data = defaults.data(forKey: daysKey) ?? defaults.data(forKey: legacyDaysKey) else { return [] }
        return (try? PhotoFileStore(directory: photoDirectory).decoder().decode([Day].self, from: data)) ?? []
    }

    /// Day metadata without file-backed photo bytes. Widget extensions have a small memory
    /// budget, so they read only the photos of the days they actually display.
    struct Library {
        var days: [Day] = []
        fileprivate var references: [String: String] = [:]
        fileprivate var files: PhotoFileStore?

        /// A missing or damaged photo file falls back to the day's preset cover.
        func withPhoto(_ day: Day) -> Day {
            guard day.photoData == nil, let reference = references[day.id], let files,
                  let data = try? files.data(for: reference, id: day.id) else { return day }
            var day = day
            day.photoData = data
            return day
        }
    }

    static func loadLibrary(defaults: UserDefaults = SharedStorage.defaults,
                            photoDirectory: URL = SharedStorage.photoDirectory) -> Library {
        guard let data = defaults.data(forKey: daysKey) ?? defaults.data(forKey: legacyDaysKey) else { return Library() }
        let files = PhotoFileStore(directory: photoDirectory)
        let references = PhotoFileStore.DeferredReferences()
        guard let days = try? files.metadataDecoder(collecting: references).decode([Day].self, from: data) else {
            return Library()
        }
        return Library(days: days, references: references.byDayID, files: files)
    }
}
