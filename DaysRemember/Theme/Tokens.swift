import SwiftUI
import UIKit

/// Shared light appearance palette and scalable typography.
enum Theme {
    // MARK: - Canvas and text
    static let bg = Color(hex: 0xF6F6F3)
    static let bg2 = Color(hex: 0xEFEEEA)
    static let card = Color(hex: 0xFFFFFF)
    static let ink = Color(hex: 0x24222B)
    static let ink2 = Color(hex: 0x5E5A66)
    static let muted = Color(hex: 0x6E6A75)
    /// Primary actions are ink pills; the tint follows them.
    static let accent = Color(hex: 0x24222B)
    /// Secondary text on a pastel card.
    static let onPastel = Color(hex: 0x24222B, opacity: 0.7)

    /// Matches the paper of the bundled cover illustrations.
    static let coverPaper = Color(hex: 0xF7F8F5)

    static let hairline = Color(.sRGB, red: 21/255, green: 23/255, blue: 28/255, opacity: 0.08)
    static let hairlineStrong = Color(.sRGB, red: 21/255, green: 23/255, blue: 28/255, opacity: 0.14)

    // MARK: - Semantic colors
    /// 节气 and traditional festival labels.
    static let solarTerm = Color(hex: 0x23608F)
    /// Errors and disabled permissions.
    static let danger = Color(hex: 0xB83F65)
    /// Count-up days (已过) and written memories.
    static let memory = Color(hex: 0xE8E4F8)
    static let memoryInk = Color(hex: 0x4B3F8F)

    // MARK: - Category backgrounds (pastel cards)
    static let noteBlue = Color(hex: 0xDDEBFA)
    static let noteYellow = Color(hex: 0xFBF0C4)
    static let notePink = Color(hex: 0xFBE0E8)
    static let noteGreen = Color(hex: 0xD7EFE0)
    static let notePeach = Color(hex: 0xFCE5CB)

    // MARK: - Category accents (text and marks on the pastel)
    static let catLove = Color(hex: 0x9C2F55)
    static let catFamily = Color(hex: 0x8A4B12)
    static let catTravel = Color(hex: 0x23608F)
    static let catWork = Color(hex: 0x2F6A47)
    static let catLife = Color(hex: 0x7A5A0E)

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

    /// Heavy SF Rounded countdown numerals at a fixed size, for fixed-scale surfaces
    /// (widgets, share images). Views that follow Dynamic Type use `.numberFont(_:)`.
    static func number(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
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

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

/// Countdown numerals that scale like `.title` with the environment's Dynamic Type size,
/// so `.dynamicTypeSize(...)` caps apply to them as they do to text styles.
struct NumberFont: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let size: CGFloat
    var weight: Font.Weight = .heavy

    func body(content: Content) -> some View {
        content.font(Theme.number(size * Self.scale(for: dynamicTypeSize), weight: weight))
    }

    /// The title text style's growth relative to the default size.
    static func scale(for size: DynamicTypeSize) -> CGFloat {
        switch size {
        case .xSmall: return 0.89
        case .small: return 0.93
        case .medium: return 0.96
        case .large: return 1
        case .xLarge: return 1.07
        case .xxLarge: return 1.14
        case .xxxLarge: return 1.21
        case .accessibility1: return 1.36
        case .accessibility2: return 1.54
        case .accessibility3: return 1.71
        case .accessibility4: return 1.89
        case .accessibility5: return 2.07
        @unknown default: return 1
        }
    }
}

extension View {
    func numberFont(_ size: CGFloat, weight: Font.Weight = .heavy) -> some View {
        modifier(NumberFont(size: size, weight: weight))
    }
}
