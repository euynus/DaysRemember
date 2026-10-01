import SwiftUI
import UIKit

/// Shared light appearance palette and scalable typography.
enum Theme {
    // MARK: - Canvas and text
    static let bg = Color(hex: 0xF6F8F8)
    static let bg2 = Color(hex: 0xE8EEEE)
    static let card = Color(hex: 0xFFFFFF)
    static let ink = Color(hex: 0x15171C)           // near-black headings
    static let ink2 = Color(hex: 0x5B6068)
    static let muted = Color(hex: 0x69787C)
    static let accent = Color(hex: 0x16756D)
    static let accentForeground = Color.white

    static let hairline = Color(.sRGB, red: 21/255, green: 23/255, blue: 28/255, opacity: 0.08)
    static let hairlineStrong = Color(.sRGB, red: 21/255, green: 23/255, blue: 28/255, opacity: 0.14)

    // MARK: - Category backgrounds
    static let noteBlue = Color(hex: 0xBCDDF0)
    static let noteYellow = Color(hex: 0xFBE7A2)
    static let notePink = Color(hex: 0xF8C9D6)
    static let noteGreen = Color(hex: 0xC5E5C9)
    static let notePeach = Color(hex: 0xFAD4BC)

    // MARK: - Category accents
    static let catLove = Color(hex: 0xB83F65)
    static let catFamily = Color(hex: 0xA46512)
    static let catTravel = Color(hex: 0x267C9F)
    static let catWork = Color(hex: 0x397D52)
    static let catLife = Color(hex: 0xB65438)

    // MARK: - Category palette (named tokens used by DayCategory / CategoryColorToken)
    // Token names are persisted in categories.v1 and must remain stable.
    static let rose = catLove
    static let roseSoft = notePink
    static let amber = catFamily
    static let amberSoft = notePeach
    static let dusty = catTravel
    static let dustySoft = noteBlue
    static let sage = catWork
    static let sageSoft = noteGreen
    static let terracotta = catLife
    static let terracottaSoft = noteYellow

    // MARK: - Fonts

    /// Bold sans stack: Inter → PingFang SC → system. Carries the headings, titles,
    /// meta rows, and the big tabular countdown numbers (use `.monospacedDigit()`).
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular,
                     relativeTo textStyle: Font.TextStyle = .body) -> Font {
        if FontAvailability.inter {
            return .custom("Inter", size: size, relativeTo: textStyle).weight(weight)
        }
        return .custom(UIFont.systemFont(ofSize: size).fontName, size: size,
                       relativeTo: textStyle).weight(weight)
    }

}

/// Resolved-once availability of the bundled custom fonts. `UIFont(name:)` is the
/// reliable "is this registered?" probe; caching avoids hitting it per text view.
enum FontAvailability {
    static let inter = UIFont(name: "Inter", size: 12) != nil
}
