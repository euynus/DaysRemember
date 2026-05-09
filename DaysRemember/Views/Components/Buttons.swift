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
                .background(accent ? Theme.terracotta : Theme.card)
                .foregroundStyle(accent ? Theme.accentForeground : Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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

    private var label: String {
        switch kind {
        case .search: return "搜索"
        case .plus: return "新增日子"
        case .back: return "返回"
        case .ellipsis: return "更多"
        case .star: return "置顶"
        case .chevronLeft: return "上一个"
        case .chevronRight: return "下一个"
        }
    }
}

/// Frosted-glass 40pt circular button used over photos (Detail screen).
struct GlassButton<Content: View>: View {
    let accessibilityLabel: String
    let action: () -> Void
    @ViewBuilder var content: Content
    init(accessibilityLabel: String, action: @escaping () -> Void = {}, @ViewBuilder content: () -> Content) {
        self.accessibilityLabel = accessibilityLabel
        self.action = action
        self.content = content()
    }
    var body: some View {
        Button(action: action) {
            content.glassCircle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

extension View {
    /// Translucent white-on-photo circle — the visual the GlassButton ships with,
    /// also reused as the label of Menu/Picker triggers that need the same look.
    func glassCircle(size: CGFloat = 40) -> some View {
        frame(width: size, height: size)
            .foregroundStyle(.white)
            .background(Color.white.opacity(0.18))
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5))
    }

    /// Pad a text-only nav-bar button so the hit area reaches iOS's recommended
    /// 44pt-ish target without changing the visual position of the label glyphs.
    func navTextButton() -> some View {
        padding(.vertical, 10)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
    }
}
