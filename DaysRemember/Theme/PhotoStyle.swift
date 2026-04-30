import SwiftUI

/// One of the prototype's CSS `.photo-*` gradient classes.
enum PhotoStyle: String, Codable, CaseIterable, Hashable {
    case wedding, baby, birthday, japan, study, memorial, work, pet, home, health

    /// Background gradient — matches the corresponding rule in `styles.css`.
    @ViewBuilder
    func background() -> some View {
        switch self {
        case .wedding:
            // radial-gradient(circle at 30% 40%, oklch(0.88 0.05 60) → oklch(0.78 0.09 45) → oklch(0.55 0.09 30))
            RadialGradient(
                colors: [Color(oklch: 0.88, 0.05, 60),
                         Color(oklch: 0.78, 0.09, 45),
                         Color(oklch: 0.55, 0.09, 30)],
                center: UnitPoint(x: 0.30, y: 0.40),
                startRadius: 0, endRadius: 280)
        case .baby:
            RadialGradient(
                colors: [Color(oklch: 0.93, 0.04, 25),
                         Color(oklch: 0.82, 0.07, 20),
                         Color(oklch: 0.65, 0.09, 15)],
                center: UnitPoint(x: 0.70, y: 0.30),
                startRadius: 0, endRadius: 280)
        case .birthday:
            RadialGradient(
                colors: [Color(oklch: 0.88, 0.12, 70),
                         Color(oklch: 0.68, 0.15, 45),
                         Color(oklch: 0.35, 0.10, 25)],
                center: UnitPoint(x: 0.50, y: 0.70),
                startRadius: 0, endRadius: 320)
        case .japan:
            LinearGradient(
                colors: [Color(oklch: 0.78, 0.08, 10),
                         Color(oklch: 0.55, 0.10, 260),
                         Color(oklch: 0.32, 0.08, 270)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .study:
            LinearGradient(
                colors: [Color(oklch: 0.40, 0.08, 250),
                         Color(oklch: 0.25, 0.06, 255)],
                startPoint: .top, endPoint: .bottom)
        case .memorial:
            LinearGradient(
                colors: [Color(oklch: 0.70, 0.02, 230),
                         Color(oklch: 0.45, 0.02, 230)],
                startPoint: .top, endPoint: .bottom)
        case .work:
            LinearGradient(
                colors: [Color(oklch: 0.78, 0.05, 150),
                         Color(oklch: 0.50, 0.07, 155)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pet:
            LinearGradient(
                colors: [Color(oklch: 0.85, 0.06, 70),
                         Color(oklch: 0.55, 0.08, 50)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .home:
            LinearGradient(
                colors: [Color(oklch: 0.82, 0.04, 55),
                         Color(oklch: 0.48, 0.06, 30)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .health:
            LinearGradient(
                colors: [Color(oklch: 0.80, 0.09, 140),
                         Color(oklch: 0.45, 0.08, 150)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}
