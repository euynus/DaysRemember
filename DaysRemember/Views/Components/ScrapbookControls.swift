import SwiftUI

// Shared scrapbook controls used across every screen — faithful ports of the CSS
// classes in styles.css (.fab, .pill, .chip, .toolbar, .meta, .sg-sec, .sg-list,
// .sg-cell, the segmented control, and the custom green toggle).

// MARK: - Press feedback

/// Scales down briefly on press (the `.sg-tap` / `:active` transform in the design).
struct PressScale: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

private let shadowInk = Color(hex: 0x15171C)

extension View {
    /// White-card floating shadow (`.fab` / `.pill-white`): soft near + far drop.
    func floatShadow() -> some View {
        self
            .shadow(color: shadowInk.opacity(0.06), radius: 2, x: 0, y: 2)
            .shadow(color: shadowInk.opacity(0.10), radius: 10, x: 0, y: 8)
    }
}

// MARK: - FAB (circular floating button)

struct FAB: View {
    let systemName: String
    var size: CGFloat = 46
    var iconSize: CGFloat = 18
    var dark: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(dark ? Color.white : Theme.ink)
                .frame(width: size, height: size)
                .background(Circle().fill(dark ? Theme.accent : Color.white))
                // Keep the tappable area at the 44pt HIG minimum even when the visible
                // circle is smaller (e.g. the 38/42pt calendar & header FABs).
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScale(scale: 0.9))
    }
}

// MARK: - Pill button

struct PillButton: View {
    enum Style { case dark, white, ghost }
    let title: String
    var style: Style = .dark
    var trailingSystemName: String? = nil
    var fill: Bool = false      // expand to full width
    var height: CGFloat = 48
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text(title).font(Theme.sans(16, weight: .bold))
                if let t = trailingSystemName {
                    Image(systemName: t).font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: fill ? .infinity : nil)
            .frame(height: height)
            .padding(.horizontal, 22)
            .background(Capsule().fill(background))
            .modifier(PillShadow(style: style))
        }
        .buttonStyle(PressScale())
    }

    private var foreground: Color {
        switch style { case .dark: return .white; case .white, .ghost: return Theme.ink }
    }
    private var background: Color {
        switch style { case .dark: return Theme.accent; case .white: return .white; case .ghost: return Theme.bg2 }
    }
}

private struct PillShadow: ViewModifier {
    let style: PillButton.Style
    func body(content: Content) -> some View {
        switch style {
        case .dark: content.shadow(color: shadowInk.opacity(0.26), radius: 9, x: 0, y: 6)
        case .white: content.floatShadow()
        case .ghost: content
        }
    }
}

// MARK: - Chip

struct Chip: View {
    let title: String
    var selected: Bool = false
    var leading: AnyView? = nil
    var action: () -> Void = {}

    init(_ title: String, selected: Bool = false, action: @escaping () -> Void = {}) {
        self.title = title; self.selected = selected; self.action = action
    }
    init<L: View>(_ title: String, selected: Bool = false, @ViewBuilder leading: () -> L, action: @escaping () -> Void = {}) {
        self.title = title; self.selected = selected; self.leading = AnyView(leading()); self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let leading { leading }
                Text(title).font(Theme.sans(14, weight: .semibold))
            }
            .foregroundStyle(selected ? Color.white : Theme.ink2)
            .frame(height: 36)
            .padding(.horizontal, 15)
            .background(Capsule().fill(selected ? Theme.accent : Color.white))
            .shadow(color: selected ? .clear : shadowInk.opacity(0.05), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(PressScale(scale: 0.95))
    }
}

// MARK: - Info chip (non-interactive, icon + text)

struct InfoChip: View {
    let systemName: String
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.ink2)
            Text(text).font(Theme.sans(14, weight: .semibold)).foregroundStyle(Theme.ink)
        }
        .frame(height: 36)
        .padding(.horizontal, 15)
        .background(Capsule().fill(Color.white))
        .shadow(color: shadowInk.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Meta row (bullet separated)

struct MetaItem: Identifiable {
    let id = UUID()
    let text: String
    var color: Color = Theme.ink2
    var bold: Bool = false
}

/// Bullet-separated metadata line (`.meta` with `.dot` separators).
struct MetaRow: View {
    let items: [MetaItem]
    init(_ items: [MetaItem]) { self.items = items }
    init(_ strings: [String]) { self.items = strings.map { MetaItem(text: $0) } }

    var body: some View {
        HStack(spacing: 9) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                if idx > 0 {
                    Circle().fill(Theme.muted).frame(width: 4, height: 4)
                }
                Text(item.text)
                    .font(Theme.sans(14, weight: item.bold ? .bold : .medium))
                    .foregroundStyle(item.color)
            }
        }
    }
}

// MARK: - Section header (sg-sec)

struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(Theme.sans(13, weight: .bold))
            .foregroundStyle(Theme.muted)
            .padding(.leading, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Nav header (back FAB + centered title + trailing)

struct NavHeader<Trailing: View>: View {
    let title: String
    var onBack: (() -> Void)? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            if let onBack {
                FAB(systemName: "chevron.left", size: 42, action: onBack)
                    .accessibilityLabel("返回")
            }
            Text(title)
                .font(Theme.sans(onBack == nil ? 28 : 20, weight: .bold))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

extension NavHeader where Trailing == EmptyView {
    init(title: String, onBack: (() -> Void)? = nil) {
        self.init(title: title, onBack: onBack, trailing: { EmptyView() })
    }
}

// MARK: - Grouped list (sg-list / sg-cell)

/// White rounded container for grouped rows. Compose rows with `RowDivider()` between.
struct CardList<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0) { content() }
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: shadowInk.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

/// Hairline divider between grouped-list cells, inset to match `.sg-cell` borders.
struct RowDivider: View {
    var body: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }
}

extension View {
    /// Standard grouped-list cell metrics (`.sg-cell`).
    func cardRow() -> some View {
        self.frame(minHeight: 56).padding(.horizontal, 18).padding(.vertical, 12)
    }
}

// MARK: - Native form controls

struct SegPicker<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value

    var body: some View {
        Picker("选项", selection: $selection) {
            ForEach(options, id: \.value) { option in
                Text(option.label).tag(option.value)
            }
        }
        .pickerStyle(.segmented)
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct ToggleCell: View {
    let label: String
    var sub: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(Theme.sans(15, weight: .semibold)).foregroundStyle(Theme.ink)
                if let sub {
                    Text(sub).font(Theme.sans(12)).foregroundStyle(Theme.ink2)
                }
            }
        }
        .tint(Theme.accent)
        .cardRow()
    }
}
