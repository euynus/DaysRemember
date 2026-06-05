import SwiftUI
import UIKit
import CoreGraphics

/// Parameters for one luminous "travel photo" gradient — a diagonal base gradient
/// (the `linear-gradient(Ndeg, …)` in styles.css) with a soft radial "sun bloom"
/// highlight on top (the `radial-gradient(… at x% y%, …)`).
struct GradientSpec {
    let start: UnitPoint
    let end: UnitPoint
    let stops: [Gradient.Stop]
    let bloom: Color
    let bloomCenter: UnitPoint
    let bloomEnd: CGFloat

    init(angle: Double,
         stops: [(l: Double, c: Double, h: Double, loc: Double)],
         bloom: (l: Double, c: Double, h: Double),
         bloomCenter: UnitPoint,
         bloomEnd: CGFloat) {
        // CSS gradient angle → axis end direction (0deg = up, clockwise). Screen y is
        // down, so end vector = (sin a, -cos a); start/end straddle the center.
        let a = angle * .pi / 180
        let dx = sin(a), dy = -cos(a)
        self.start = UnitPoint(x: 0.5 - dx / 2, y: 0.5 - dy / 2)
        self.end = UnitPoint(x: 0.5 + dx / 2, y: 0.5 + dy / 2)
        self.stops = stops.map { Gradient.Stop(color: Color(oklch: $0.l, $0.c, $0.h), location: $0.loc) }
        self.bloom = Color(oklch: bloom.l, bloom.c, bloom.h)
        self.bloomCenter = bloomCenter
        self.bloomEnd = bloomEnd
    }
}

/// Renders a `GradientSpec`: diagonal base + radial bloom + film grain.
struct GradientPhotoView: View {
    let spec: GradientSpec

    var body: some View {
        ZStack {
            LinearGradient(stops: spec.stops, startPoint: spec.start, endPoint: spec.end)
            // Bloom sits on top of the base (CSS lists the radial first = topmost layer).
            EllipticalGradient(
                colors: [spec.bloom, spec.bloom.opacity(0)],
                center: spec.bloomCenter,
                startRadiusFraction: 0,
                endRadiusFraction: spec.bloomEnd
            )
            PhotoGrain()
        }
    }
}

extension PhotoStyle {
    /// Spec lookup for the 10 gradient styles — verbatim oklch values from styles.css.
    static func gradientSpec(for style: PhotoStyle) -> GradientSpec {
        switch style {
        case .wedding:
            return GradientSpec(angle: 158,
                stops: [(0.86, 0.08, 68, 0), (0.68, 0.11, 48, 0.58), (0.50, 0.10, 36, 1)],
                bloom: (0.95, 0.06, 88), bloomCenter: UnitPoint(x: 0.30, y: 0.18), bloomEnd: 0.52)
        case .baby:
            return GradientSpec(angle: 158,
                stops: [(0.93, 0.05, 22, 0), (0.85, 0.07, 16, 0.56), (0.74, 0.085, 10, 1)],
                bloom: (0.97, 0.03, 32), bloomCenter: UnitPoint(x: 0.62, y: 0.22), bloomEnd: 0.55)
        case .birthday:
            return GradientSpec(angle: 158,
                stops: [(0.84, 0.12, 28, 0), (0.67, 0.15, 20, 0.60), (0.50, 0.13, 14, 1)],
                bloom: (0.92, 0.11, 62), bloomCenter: UnitPoint(x: 0.50, y: 0.82), bloomEnd: 0.56)
        case .japan:
            return GradientSpec(angle: 165,
                stops: [(0.80, 0.09, 242, 0), (0.56, 0.11, 256, 0.56), (0.38, 0.08, 266, 1)],
                bloom: (0.93, 0.08, 72), bloomCenter: UnitPoint(x: 0.72, y: 0.16), bloomEnd: 0.46)
        case .study:
            return GradientSpec(angle: 170,
                stops: [(0.44, 0.09, 256, 0), (0.27, 0.07, 262, 1)],
                bloom: (0.72, 0.09, 252), bloomCenter: UnitPoint(x: 0.76, y: 0.20), bloomEnd: 0.50)
        case .memorial:
            return GradientSpec(angle: 165,
                stops: [(0.80, 0.02, 232, 0), (0.55, 0.025, 236, 1)],
                bloom: (0.88, 0.02, 230), bloomCenter: UnitPoint(x: 0.50, y: 0.22), bloomEnd: 0.55)
        case .work:
            return GradientSpec(angle: 158,
                stops: [(0.81, 0.07, 150, 0), (0.56, 0.085, 156, 1)],
                bloom: (0.94, 0.05, 142), bloomCenter: UnitPoint(x: 0.66, y: 0.20), bloomEnd: 0.50)
        case .pet:
            return GradientSpec(angle: 158,
                stops: [(0.87, 0.08, 72, 0), (0.63, 0.10, 56, 1)],
                bloom: (0.95, 0.06, 82), bloomCenter: UnitPoint(x: 0.34, y: 0.24), bloomEnd: 0.50)
        case .home:
            return GradientSpec(angle: 158,
                stops: [(0.85, 0.07, 52, 0), (0.59, 0.095, 36, 1)],
                bloom: (0.94, 0.05, 62), bloomCenter: UnitPoint(x: 0.60, y: 0.20), bloomEnd: 0.50)
        case .health:
            return GradientSpec(angle: 158,
                stops: [(0.86, 0.09, 146, 0), (0.56, 0.09, 151, 1)],
                bloom: (0.95, 0.07, 146), bloomCenter: UnitPoint(x: 0.60, y: 0.22), bloomEnd: 0.52)
        default:
            // Sketch styles never reach here (they draw a Canvas), but keep total.
            return GradientSpec(angle: 158,
                stops: [(0.85, 0.07, 52, 0), (0.59, 0.095, 36, 1)],
                bloom: (0.94, 0.05, 62), bloomCenter: UnitPoint(x: 0.6, y: 0.2), bloomEnd: 0.5)
        }
    }
}

/// Faint photographic grain laid over every gradient photo (styles.css `.photo::before`,
/// a soft-light fractal-noise tile). Generated once per process and tiled.
struct PhotoGrain: View {
    var body: some View {
        Image(uiImage: GrainTexture.shared)
            .resizable(resizingMode: .tile)
            .opacity(0.32)
            .blendMode(.softLight)
            .allowsHitTesting(false)
    }
}

private enum GrainTexture {
    static let shared: UIImage = make(side: 96)

    /// A small square of mid-band gray noise. Mid-band (not full 0–255) keeps the
    /// soft-light blend subtle, like the alpha-limited SVG turbulence in the design.
    static func make(side n: Int) -> UIImage {
        let bytesPerRow = n * 4
        var pixels = [UInt8](repeating: 0, count: n * n * 4)
        var rng = SeededRNG(seed: 0x5DEECE66D)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let v = UInt8(64 + Int(rng.next() % 128))   // 64…191
            pixels[i] = v; pixels[i + 1] = v; pixels[i + 2] = v; pixels[i + 3] = 255
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &pixels, width: n, height: n, bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let cg = ctx.makeImage() else { return UIImage() }
        return UIImage(cgImage: cg)
    }
}

/// Tiny deterministic LCG so the grain is identical every launch (and across the
/// app/widget) without pulling in extra dependencies.
private struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state >> 33
    }
}
