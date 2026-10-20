import Foundation

/// The two faces of the feed: days ahead count down, days behind count up.
enum HomeFace: String, Hashable {
    case upcoming, past

    /// Allows `xcrun simctl launch ... --face past` for screenshotting.
    static func initial() -> HomeFace {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--face"), i + 1 < args.count,
           let face = HomeFace(rawValue: args[i + 1]) { return face }
        return .upcoming
    }
}
