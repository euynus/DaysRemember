import SwiftUI

/// Top-of-screen circular button with cream/ink fill (used on Home: search & "+").
struct IconBtn: View {
    enum Kind { case search, plus, back, ellipsis, star, chevronLeft, chevronRight }
    let kind: Kind
    var accent: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            icon
                .frame(width: 40, height: 40)
                .background(accent ? Theme.ink : Theme.card)
                .foregroundStyle(accent ? Theme.bg : Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var icon: some View {
        switch kind {
        case .search: Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .semibold))
        case .plus: Image(systemName: "plus").font(.system(size: 17, weight: .bold))
        case .back: Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold))
        case .ellipsis: Image(systemName: "ellipsis").font(.system(size: 17, weight: .bold))
        case .star: Image(systemName: "star").font(.system(size: 16, weight: .semibold))
        case .chevronLeft: Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
        case .chevronRight: Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold))
        }
    }
}

/// Frosted-glass 40pt circular button used over photos (Detail screen).
struct GlassButton<Content: View>: View {
    let action: () -> Void
    @ViewBuilder var content: Content
    init(action: @escaping () -> Void = {}, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }
    var body: some View {
        Button(action: action) {
            content
                .frame(width: 40, height: 40)
                .foregroundStyle(.white)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}
