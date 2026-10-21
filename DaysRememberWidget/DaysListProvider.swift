import WidgetKit

struct DaysListEntry: TimelineEntry {
    var date: Date
    var days: [Day]
    var colorTokens: [String: CategoryColorToken] = [:]

    /// The entry's moment on the app calendar, which countdowns count from.
    var today: Date { CNDate.appTime(date) }
}

/// The days-list widget shows no photos, so it reads day metadata only, and turns over at each
/// local midnight like the single-day widget.
struct DaysListProvider: TimelineProvider {
    func placeholder(in context: Context) -> DaysListEntry {
        DaysListEntry(date: .now, days: [WidgetDay.gallerySample])
    }

    func getSnapshot(in context: Context, completion: @escaping (DaysListEntry) -> Void) {
        let entry = makeEntry(at: .now, family: context.family, library: SharedStorage.loadLibrary().days,
                              categories: SharedStorage.loadCategories())
        completion(context.isPreview && entry.days.isEmpty ? placeholder(in: context) : entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DaysListEntry>) -> Void) {
        let now = Date.now
        let library = SharedStorage.loadLibrary().days
        let categories = SharedStorage.loadCategories()
        let entries = ([now] + CNDate.localDayStarts(after: now, count: 7)).map {
            makeEntry(at: $0, family: context.family, library: library, categories: categories)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func makeEntry(at date: Date, family: WidgetFamily, library: [Day],
                           categories: [CategoryDefinition]) -> DaysListEntry {
        let days = WidgetDay.list(in: library, today: CNDate.appTime(date),
                                  limit: DayListWidgetCard.capacity(large: family == .systemLarge))
        let tokens = Dictionary(uniqueKeysWithValues: days.map {
            ($0.id, CategoryDefinition.colorToken(for: $0, in: categories))
        })
        return DaysListEntry(date: date, days: days, colorTokens: tokens)
    }
}
