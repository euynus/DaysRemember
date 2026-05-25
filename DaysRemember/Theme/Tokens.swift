import SwiftUI

/// Maps the prototype's CSS variables (`styles.css`) to Swift-side colors and fonts.
enum Theme {
    // Backgrounds & ink — from styles.css :root and .sg-dark
    static let bg = Color.adaptive(light: Color(hex: 0xF7F3EE), dark: Color(hex: 0x15120F))
    static let bg2 = Color.adaptive(light: Color(hex: 0xEEE6DC), dark: Color(hex: 0x1F1A16))
    static let card = Color.adaptive(light: Color(hex: 0xFFFCF7), dark: Color(hex: 0x241F1A))
    static let ink = Color.adaptive(light: Color(hex: 0x241D18), dark: Color(hex: 0xF3EDE4))
    static let ink2 = Color.adaptive(light: Color(hex: 0x5E544B), dark: Color(hex: 0xC8BDB0))
    static let muted = Color.adaptive(light: Color(hex: 0x8D8276), dark: Color(hex: 0x93897D))
    static let accentForeground = Color.adaptive(light: Color(hex: 0xFFF8F1), dark: Color(hex: 0x241D18))

    static let hairline = Color.adaptive(
        light: Color(.sRGB, red: 31/255, green: 26/255, blue: 21/255, opacity: 0.08),
        dark: Color(.sRGB, red: 240/255, green: 234/255, blue: 224/255, opacity: 0.08)
    )
    static let hairlineStrong = Color.adaptive(
        light: Color(.sRGB, red: 31/255, green: 26/255, blue: 21/255, opacity: 0.14),
        dark: Color(.sRGB, red: 240/255, green: 234/255, blue: 224/255, opacity: 0.14)
    )

    // Accents — tuned for a warmer but clearer app palette.
    static let terracotta = Color.adaptive(
        lightOklch: (0.58, 0.105, 33), darkOklch: (0.74, 0.10, 33))
    static let terracottaSoft = Color.adaptive(
        lightOklch: (0.91, 0.045, 33), darkOklch: (0.30, 0.055, 33))
    static let sage = Color.adaptive(
        lightOklch: (0.57, 0.07, 150), darkOklch: (0.72, 0.075, 150))
    static let sageSoft = Color.adaptive(
        lightOklch: (0.92, 0.04, 150), darkOklch: (0.30, 0.045, 150))
    static let dusty = Color.adaptive(
        lightOklch: (0.58, 0.07, 250), darkOklch: (0.72, 0.075, 250))
    static let dustySoft = Color.adaptive(
        lightOklch: (0.92, 0.035, 250), darkOklch: (0.30, 0.045, 250))
    static let amber = Color.adaptive(
        lightOklch: (0.70, 0.10, 78), darkOklch: (0.78, 0.105, 78))
    static let amberSoft = Color.adaptive(
        lightOklch: (0.93, 0.045, 78), darkOklch: (0.31, 0.055, 78))
    static let rose = Color.adaptive(
        lightOklch: (0.63, 0.095, 12), darkOklch: (0.74, 0.10, 12))
    static let roseSoft = Color.adaptive(
        lightOklch: (0.92, 0.04, 12), darkOklch: (0.30, 0.05, 12))

    // MARK: - Fonts
    /// Serif stack: Noto Serif SC → Songti SC → system serif
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular,
                      relativeTo textStyle: Font.TextStyle = .body) -> Font {
        if UIFont(name: "NotoSerifSC-Regular", size: size) != nil {
            return .custom(notoName(family: "NotoSerifSC", weight: weight), size: size, relativeTo: textStyle)
        }
        // Songti SC ships discrete weight faces; choose the face directly. Calling
        // `.weight()` on a custom font is unreliable (it doesn't switch to the named
        // bold face), and the design depends on the serif weight hierarchy.
        let songti = songtiName(for: weight)
        if UIFont(name: songti, size: size) != nil {
            return .custom(songti, size: size, relativeTo: textStyle)
        }
        return .system(size: size, weight: weight, design: .serif)
    }

    /// Sans stack: Noto Sans SC → PingFang SC → system
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular,
                     relativeTo textStyle: Font.TextStyle = .body) -> Font {
        if UIFont(name: "NotoSansSC-Regular", size: size) != nil {
            return .custom(notoName(family: "NotoSansSC", weight: weight), size: size, relativeTo: textStyle)
        }
        let pingfang = pingFangName(for: weight)
        if UIFont(name: pingfang, size: size) != nil {
            return .custom(pingfang, size: size, relativeTo: textStyle)
        }
        return .system(size: size, weight: weight)
    }

    /// Map a Font.Weight to one of the three Noto SC face suffixes we ship.
    private static func notoName(family: String, weight: Font.Weight) -> String {
        let suffix: String
        switch weight {
        case .semibold, .bold, .heavy, .black: suffix = "SemiBold"
        case .medium: suffix = "Medium"
        default: suffix = "Regular"
        }
        return "\(family)-\(suffix)"
    }

    /// Songti SC weight faces — Light / Regular / Bold / Black (no Medium/Semibold).
    private static func songtiName(for weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight, .thin, .light: return "STSongti-SC-Light"
        case .semibold, .bold: return "STSongti-SC-Bold"
        case .heavy, .black: return "STSongti-SC-Black"
        default: return "STSongti-SC-Regular" // regular, medium
        }
    }

    /// PingFang SC weight faces — Ultralight … Semibold (no Bold/Heavy/Black).
    private static func pingFangName(for weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight: return "PingFangSC-Ultralight"
        case .thin, .light: return "PingFangSC-Light"
        case .medium: return "PingFangSC-Medium"
        case .semibold, .bold, .heavy, .black: return "PingFangSC-Semibold"
        default: return "PingFangSC-Regular" // regular
        }
    }
}
