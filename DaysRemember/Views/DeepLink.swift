import Foundation

/// A widget link: `daysremember://day/<id>` opens that day; any other link in the scheme,
/// such as the empty widget's `daysremember://home`, returns to 日子.
enum DeepLink: Equatable {
    case day(String), home

    init?(_ url: URL) {
        guard url.scheme == "daysremember" else { return nil }
        let id = url.lastPathComponent
        self = url.host() == "day" && !id.isEmpty && id != "/" ? .day(id) : .home
    }
}
