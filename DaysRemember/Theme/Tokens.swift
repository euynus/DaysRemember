import SwiftUI
import UIKit
import CoreText

/// Maps the prototype's CSS variables (`styles.css`) to Swift-side colors and fonts.
///
/// Travel-scrapbook aesthetic: a cool light-gray paper canvas, near-black headings,
/// pastel sticky-note palette, flat-sticker category tints, bold Inter sans + two
/// handwriting accents (Caveat for Latin, Ma Shan Zheng for Chinese). The app is
/// locked to a light appearance (see Info.plist `UIUserInterfaceStyle`), so tokens
/// are plain light-mode colors rather than adaptive pairs.
enum Theme {
    // MARK: - Canvas & ink  (styles.css :root)
    static let bg = Color(hex: 0xF6F8F8)
    static let bg2 = Color(hex: 0xE8EEEE)
    static let card = Color(hex: 0xFFFFFF)
    static let ink = Color(hex: 0x15171C)           // near-black headings
    static let ink2 = Color(hex: 0x5B6068)
    static let muted = Color(hex: 0x69787C)
    /// Primary pill accent = ink; foreground on it = white.
    static let accent = Color(hex: 0x16756D)
    static let accentForeground = Color.white

    static let hairline = Color(.sRGB, red: 21/255, green: 23/255, blue: 28/255, opacity: 0.08)
    static let hairlineStrong = Color(.sRGB, red: 21/255, green: 23/255, blue: 28/255, opacity: 0.14)

    // MARK: - Sticky-note palette  (paper + matching handwriting ink)
    static let noteBlue = Color(hex: 0xBCDDF0)
    static let noteBlueInk = Color(hex: 0x3A7CA0)
    static let noteYellow = Color(hex: 0xFBE7A2)
    static let noteYellowInk = Color(hex: 0x9B7A1E)
    static let notePink = Color(hex: 0xF8C9D6)
    static let notePinkInk = Color(hex: 0xB05670)
    static let noteGreen = Color(hex: 0xC5E5C9)
    static let noteGreenInk = Color(hex: 0x4E8A57)
    static let notePeach = Color(hex: 0xFAD4BC)
    static let notePeachInk = Color(hex: 0xB5663C)

    // MARK: - Category sticker tints (flat illustration colors)
    static let catLove = Color(hex: 0xF2778E)
    static let catFamily = Color(hex: 0xF5A623)
    static let catTravel = Color(hex: 0x4FB0D8)
    static let catWork = Color(hex: 0x5FB97D)
    static let catLife = Color(hex: 0xE0795A)

    // MARK: - Category palette (named tokens used by DayCategory / CategoryColorToken)
    // These are the same five CategoryColorToken cases, remapped to the scrapbook
    // tints. The token *names* are persisted in `categories.v1`, so they stay; only
    // the colors change. `*Soft` resolves to the matching sticky-note paper, mirroring
    // the prototype's CATEGORY_SOFT map (love→pink, family→peach, travel→blue,
    // work→green, life→yellow).
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
        if FontAvailability.inter, let ui = interUIFont(size: size, weight: weight) {
            // Scale for Dynamic Type while preserving the true variable-font weight.
            let scaled = UIFontMetrics(forTextStyle: Self.uiTextStyle(for: textStyle)).scaledFont(for: ui)
            return Font(scaled)
        }
        return .system(size: size, weight: weight)
    }

    /// Inter is a variable font; `Font.custom(...).weight()` synthesizes faux-bold
    /// instead of moving the `wght` axis. Build the true weight via the variation axis.
    private static func interUIFont(size: CGFloat, weight: Font.Weight) -> UIFont? {
        let wght: CGFloat
        switch weight {
        case .ultraLight: wght = 100
        case .thin: wght = 200
        case .light: wght = 300
        case .medium: wght = 500
        case .semibold: wght = 600
        case .bold: wght = 700
        case .heavy: wght = 800
        case .black: wght = 900
        default: wght = 400
        }
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: "Inter",
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [2003265652: wght],
        ])
        return UIFont(descriptor: descriptor, size: size)
    }

    private static func uiTextStyle(for style: Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        default: return .body
        }
    }

    /// Latin handwriting accent (Caveat) — English-style dates, "My Memory", eyebrows.
    static func hand(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        if FontAvailability.caveat {
            return .custom("Caveat-Regular", size: size, relativeTo: textStyle)
        }
        return .system(size: size, weight: .semibold, design: .rounded)
    }

    /// Chinese handwriting accent (Ma Shan Zheng) — sticky-note counts, mood notes.
    static func handCN(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        if FontAvailability.maShanZheng {
            return .custom("MaShanZheng-Regular", size: size, relativeTo: textStyle)
        }
        return .system(size: size, weight: .medium, design: .serif)
    }

}

/// Resolved-once availability of the bundled custom fonts. `UIFont(name:)` is the
/// reliable "is this registered?" probe; caching avoids hitting it per text view.
enum FontAvailability {
    static let inter = UIFont(name: "Inter", size: 12) != nil
    static let caveat = UIFont(name: "Caveat-Regular", size: 12) != nil
    static let maShanZheng = UIFont(name: "MaShanZheng-Regular", size: 12) != nil
}
