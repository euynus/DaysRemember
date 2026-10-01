import SwiftUI
import UIKit

/// Shared light appearance palette and scalable typography.
enum Theme {
    // MARK: - Canvas and text
    static let bg = Color(hex: 0xFCFCFA)
    static let bg2 = Color(hex: 0xF0F0EE)
    static let card = Color(hex: 0xFFFFFF)
    static let ink = Color(hex: 0x242424)
    static let ink2 = Color(hex: 0x646460)
    static let muted = Color(hex: 0x757570)
    static let accent = Color(hex: 0xBB4235)
    static let accentForeground = Color.white

    static let hairline = Color(.sRGB, red: 21/255, green: 23/255, blue: 28/255, opacity: 0.08)
    static let hairlineStrong = Color(.sRGB, red: 21/255, green: 23/255, blue: 28/255, opacity: 0.14)

    // MARK: - Category backgrounds
    static let noteBlue = Color(hex: 0xE7EFF4)
    static let noteYellow = Color(hex: 0xF4EEDC)
    static let notePink = Color(hex: 0xF7E8E5)
    static let noteGreen = Color(hex: 0xE7EEE6)
    static let notePeach = Color(hex: 0xF4EBE0)

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

    static func number(_ size: CGFloat) -> Font {
        .custom("Baskerville", size: size, relativeTo: .title)
    }

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
