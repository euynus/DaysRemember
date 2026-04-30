import SwiftUI
import UIKit

/// OKLCH → sRGB. Lets us declare colors directly from the prototype's CSS values
/// (e.g. `oklch(0.62 0.12 35)`) without hand-converting them.
struct OKLCH {
    var L: Double  // 0...1
    var C: Double
    var h: Double  // degrees

    func srgb() -> (r: Double, g: Double, b: Double) {
        let a = C * cos(h * .pi / 180)
        let b = C * sin(h * .pi / 180)
        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b
        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_
        let lr = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let lg = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let lb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        return (toSRGB(lr), toSRGB(lg), toSRGB(lb))
    }

    private func toSRGB(_ x: Double) -> Double {
        let v = max(0, min(1, x))
        return v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1.0 / 2.4) - 0.055
    }
}

extension Color {
    init(oklch L: Double, _ C: Double, _ h: Double, opacity: Double = 1) {
        let (r, g, b) = OKLCH(L: L, C: C, h: h).srgb()
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// Light/dark adaptive color.
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    static func adaptive(lightOklch: (Double, Double, Double),
                         darkOklch: (Double, Double, Double),
                         opacity: Double = 1) -> Color {
        adaptive(
            light: Color(oklch: lightOklch.0, lightOklch.1, lightOklch.2, opacity: opacity),
            dark: Color(oklch: darkOklch.0, darkOklch.1, darkOklch.2, opacity: opacity)
        )
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
