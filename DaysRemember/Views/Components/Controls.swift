import SwiftUI

// Shared controls for navigation, filtering, and forms.

// MARK: - Press feedback

/// Subtle feedback that respects Reduce Motion.
struct PressScale: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
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
                .font(.system(size: iconSize, weight: .regular))
                .foregroundStyle(dark ? Color.white : Theme.ink)
                .frame(width: size, height: size)
                .background(Circle().fill(dark ? Theme.accent : Color.white))
                .overlay { Circle().strokeBorder(dark ? .clear : Theme.hairline, lineWidth: 1) }
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
                Text(title).font(Theme.sans(15, weight: .medium))
                if let t = trailingSystemName {
                    Image(systemName: t).font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: fill ? .infinity : nil)
            .frame(minHeight: height)
            .padding(.horizontal, 22)
            .background(RoundedRectangle(cornerRadius: 6).fill(background))
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
                Text(title).font(Theme.sans(14, weight: .medium))
            }
            .foregroundStyle(selected ? Theme.accent : Theme.ink2)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .padding(.horizontal, 15)
            .background(RoundedRectangle(cornerRadius: 6).fill(selected ? Theme.notePink : Theme.bg2))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(selected ? Theme.accent.opacity(0.4) : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(PressScale(scale: 0.95))
        .accessibilityAddTraits(selected ? .isSelected : [])
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
                .accessibilityHidden(true)
            Text(text).font(Theme.sans(13)).foregroundStyle(Theme.ink2)
        }
        .padding(.vertical, 8)
        .frame(minHeight: 36)
        .padding(.trailing, 12)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Meta row (bullet separated)

struct MetaItem {
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
        FlowLayout(spacing: 9) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                Text((idx > 0 ? "· " : "") + item.text)
                    .font(Theme.sans(12, weight: item.bold ? .semibold : .regular))
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
            .font(Theme.sans(14, weight: .medium))
            .foregroundStyle(Theme.ink2)
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
                .font(Theme.sans(onBack == nil ? 28 : 19, weight: .medium,
                                 relativeTo: onBack == nil ? .largeTitle : .headline))
                .foregroundStyle(Theme.ink)
                .lineLimit(onBack == nil ? 1 : 2)
                .minimumScaleFactor(0.5)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }
}

extension NavHeader where Trailing == EmptyView {
    init(title: String, onBack: (() -> Void)? = nil) {
        self.init(title: title, onBack: onBack, trailing: { EmptyView() })
    }
}

// MARK: - Grouped list (sg-list / sg-cell)

/// Unframed form sections with shared separators.
struct CardList<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0) { content() }
            .background(Theme.card)
            .overlay(alignment: .top) { RowDivider() }
            .overlay(alignment: .bottom) { RowDivider() }
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
                Text(label).font(Theme.sans(15)).foregroundStyle(Theme.ink)
                if let sub {
                    Text(sub).font(Theme.sans(12)).foregroundStyle(Theme.ink2)
                }
            }
        }
        .tint(Theme.accent)
        .cardRow()
    }
}
