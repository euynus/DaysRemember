import Foundation

/// A widget link: `daysremember://day/<id>` opens that day and `daysremember://new` starts a new
/// one; any other link in the scheme, such as the empty widget's `daysremember://home`, returns to 日子.
enum DeepLink: Equatable {
    case day(String), newDay, home

    init?(_ url: URL) {
        guard url.scheme == "daysremember" else { return nil }
        let id = url.lastPathComponent
        if url.host() == "new" { self = .newDay; return }
        self = url.host() == "day" && !id.isEmpty && id != "/" ? .day(id) : .home
    }

    static func url(forDayID id: String) -> URL {
        URL(string: "daysremember://day/")!.appending(path: id)
    }
}
