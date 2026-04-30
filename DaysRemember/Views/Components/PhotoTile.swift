import SwiftUI

/// A photo placeholder — colored gradient + optional bottom-darkening scrim.
/// Mirrors the prototype's `.photo` + `.photo-flat` CSS classes.
struct PhotoTile: View {
    let style: PhotoStyle
    var flat: Bool = false
    var cornerRadius: CGFloat = 20

    var body: some View {
        ZStack {
            style.background()
            if !flat {
                LinearGradient(
                    colors: [.black.opacity(0), .black.opacity(0.55)],
                    startPoint: UnitPoint(x: 0.5, y: 0.35),
                    endPoint: .bottom
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    /// 180° gradient overlay that matches `.photo::after` in `styles.css`.
    func bottomScrim(opacity: Double = 0.55) -> some View {
        overlay {
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(opacity)],
                startPoint: UnitPoint(x: 0.5, y: 0.35),
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
    }
}
