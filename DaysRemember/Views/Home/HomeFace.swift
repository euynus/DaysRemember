import Foundation

/// The two faces of the feed: days ahead count down, days behind count up.
enum HomeFace: String, Hashable {
    case upcoming, past

    /// Allows `xcrun simctl launch ... --face past` for screenshotting.
    static var launchArgument: HomeFace? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--face"), i + 1 < args.count else { return nil }
        return HomeFace(rawValue: args[i + 1])
    }

    /// The face the feed opens on: the first pinned day's, else 将至 unless only 已过 has days.
    static func opening(upcoming: [Day], past: [Day]) -> HomeFace {
        if upcoming.contains(where: \.pinned) { return .upcoming }
        if past.contains(where: \.pinned) || upcoming.isEmpty && !past.isEmpty { return .past }
        return .upcoming
    }
}
