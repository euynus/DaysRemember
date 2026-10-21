import WidgetKit

struct DaysProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DaysEntry {
        DaysEntry(date: Date.now, day: WidgetDay.gallerySample)
    }

    func snapshot(for configuration: SelectWidgetDay, in context: Context) async -> DaysEntry {
        var photos = PhotoLoader(library: SharedStorage.loadLibrary(), family: context.family)
        let entry = makeEntry(configuration: configuration, photos: &photos,
                              categories: SharedStorage.loadCategories(), asOf: Date.now)
        return context.isPreview && configuration.day == nil && entry.day == nil
            ? placeholder(in: context) : entry
    }

    func timeline(for configuration: SelectWidgetDay, in context: Context) async -> Timeline<DaysEntry> {
        let now = Date.now
        var photos = PhotoLoader(library: SharedStorage.loadLibrary(), family: context.family)
        let categories = SharedStorage.loadCategories()
        let entries = ([now] + CNDate.localDayStarts(after: now, count: 7)).map {
            makeEntry(configuration: configuration, photos: &photos, categories: categories, asOf: $0)
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func makeEntry(configuration: SelectWidgetDay, photos: inout PhotoLoader,
                           categories: [CategoryDefinition], asOf date: Date) -> DaysEntry {
        let days = photos.library.days
        let day = WidgetDay.resolve(in: days, selectedID: configuration.day?.id, today: CNDate.appTime(date))
        return DaysEntry(date: date, day: day.map { photos.load($0) },
                         selectionMissing: configuration.day != nil && day == nil,
                         colorToken: day.map { CategoryDefinition.colorToken(for: $0, in: categories) })
    }

    /// Reads each displayed photo once per timeline; Lock Screen layouts never show photos.
    private struct PhotoLoader {
        let library: SharedStorage.Library
        let showsPhotos: Bool
        private var loaded: [String: Day] = [:]

        init(library: SharedStorage.Library, family: WidgetFamily) {
            self.library = library
            showsPhotos = [.systemSmall, .systemMedium, .systemLarge].contains(family)
        }

        mutating func load(_ day: Day) -> Day {
            guard showsPhotos else { return day }
            if let cached = loaded[day.id] { return cached }
            let withPhoto = library.withPhoto(day)
            loaded[day.id] = withPhoto
            return withPhoto
        }
    }
}
