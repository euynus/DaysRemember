import SwiftUI

/// Maps the prototype's CSS variables (`styles.css`) to Swift-side colors and fonts.
enum Theme {
    // Backgrounds & ink — from styles.css :root and .sg-dark
    static let bg = Color.adaptive(light: Color(hex: 0xF5F1EA), dark: Color(hex: 0x161310))
    static let bg2 = Color.adaptive(light: Color(hex: 0xEFE9DF), dark: Color(hex: 0x1E1A16))
    static let card = Color.adaptive(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x221E1A))
    static let ink = Color.adaptive(light: Color(hex: 0x1F1A15), dark: Color(hex: 0xF0EAE0))
    static let ink2 = Color.adaptive(light: Color(hex: 0x5A5148), dark: Color(hex: 0xBDB3A6))
    static let muted = Color.adaptive(light: Color(hex: 0x8A8074), dark: Color(hex: 0x877E72))

    static let hairline = Color.adaptive(
        light: Color(.sRGB, red: 31/255, green: 26/255, blue: 21/255, opacity: 0.08),
        dark: Color(.sRGB, red: 240/255, green: 234/255, blue: 224/255, opacity: 0.08)
    )
    static let hairlineStrong = Color.adaptive(
        light: Color(.sRGB, red: 31/255, green: 26/255, blue: 21/255, opacity: 0.14),
        dark: Color(.sRGB, red: 240/255, green: 234/255, blue: 224/255, opacity: 0.14)
    )

    // Accents — values lifted from styles.css; dark-mode variants brighten L by 0.10.
    static let terracotta = Color.adaptive(
        lightOklch: (0.62, 0.12, 35), darkOklch: (0.72, 0.12, 35))
    static let terracottaSoft = Color.adaptive(
        lightOklch: (0.92, 0.04, 35), darkOklch: (0.32, 0.06, 35))
    static let sage = Color.adaptive(
        lightOklch: (0.62, 0.08, 155), darkOklch: (0.72, 0.08, 155))
    static let sageSoft = Color.adaptive(
        lightOklch: (0.93, 0.03, 155), darkOklch: (0.32, 0.04, 155))
    static let dusty = Color.adaptive(
        lightOklch: (0.62, 0.08, 245), darkOklch: (0.72, 0.08, 245))
    static let dustySoft = Color.adaptive(
        lightOklch: (0.93, 0.025, 245), darkOklch: (0.32, 0.04, 245))
    static let amber = Color.adaptive(
        lightOklch: (0.72, 0.12, 75), darkOklch: (0.78, 0.12, 75))
    static let amberSoft = Color.adaptive(
        lightOklch: (0.94, 0.04, 75), darkOklch: (0.34, 0.06, 75))
    static let rose = Color.adaptive(
        lightOklch: (0.68, 0.11, 10), darkOklch: (0.74, 0.11, 10))
    static let roseSoft = Color.adaptive(
        lightOklch: (0.94, 0.03, 10), darkOklch: (0.32, 0.05, 10))

    // MARK: - Fonts
    /// Serif stack: Noto Serif SC → Songti SC → system serif
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular,
                      relativeTo textStyle: Font.TextStyle = .body) -> Font {
        if let _ = UIFont(name: "NotoSerifSC-Regular", size: size) {
            return .custom(notoSerifName(for: weight), size: size, relativeTo: textStyle)
        }
        if UIFont(name: "STSongti-SC-Regular", size: size) != nil {
            return .custom("STSongti-SC-Regular", size: size, relativeTo: textStyle).weight(weight)
        }
        return .system(size: size, weight: weight, design: .serif)
    }

    /// Sans stack: Noto Sans SC → PingFang SC → system
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular,
                     relativeTo textStyle: Font.TextStyle = .body) -> Font {
        if UIFont(name: "NotoSansSC-Regular", size: size) != nil {
            return .custom(notoSansName(for: weight), size: size, relativeTo: textStyle)
        }
        if UIFont(name: "PingFangSC-Regular", size: size) != nil {
            return .custom("PingFangSC-Regular", size: size, relativeTo: textStyle).weight(weight)
        }
        return .system(size: size, weight: weight)
    }

    private static func notoSerifName(for weight: Font.Weight) -> String {
        switch weight {
        case .semibold, .bold, .heavy, .black: return "NotoSerifSC-SemiBold"
        case .medium: return "NotoSerifSC-Medium"
        default: return "NotoSerifSC-Regular"
        }
    }
    private static func notoSansName(for weight: Font.Weight) -> String {
        switch weight {
        case .semibold, .bold, .heavy, .black: return "NotoSansSC-SemiBold"
        case .medium: return "NotoSansSC-Medium"
        default: return "NotoSansSC-Regular"
        }
    }
}

extension Font {
    /// Approximate a weight on a custom font that may not have weight variants.
    func weight(_ w: Font.Weight) -> Font {
        // Font.weight() returns Font; identity for custom fonts that already chose a face.
        self
    }
}
