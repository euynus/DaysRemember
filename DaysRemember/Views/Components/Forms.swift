import SwiftUI

/// Inset form row — used in Add and Notifications.
struct FormRow<Trailing: View>: View {
    let label: String
    var isLast: Bool = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(label)
                .font(Theme.sans(14, weight: .medium))
                .foregroundStyle(Theme.ink)
            Spacer()
            trailing
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(minHeight: 52, alignment: .leading)
        .rowHairline(isLast: isLast, hPadding: 18)
    }
}

private extension View {
    /// Hairline divider at the bottom of a stacked row, suppressed for the last item.
    func rowHairline(isLast: Bool, hPadding: CGFloat = 16) -> some View {
        overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(Theme.hairline).frame(height: 0.5).padding(.horizontal, hPadding)
            }
        }
    }
}

/// 2-position segmented control (公历/农历, 一次/每年).
struct SegBtnPair: View {
    let leftLabel: String
    let rightLabel: String
    @Binding var leftSelected: Bool

    var body: some View {
        HStack(spacing: 0) {
            seg(leftLabel, active: leftSelected) { leftSelected = true }
            seg(rightLabel, active: !leftSelected) { leftSelected = false }
        }
        .padding(2)
        .background(Theme.bg2)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .sensoryFeedback(.selection, trigger: leftSelected)
    }

    @ViewBuilder
    private func seg(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.sans(12, weight: .medium))
                .foregroundStyle(active ? Theme.terracotta : Theme.ink2)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background {
                    if active {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.terracottaSoft)
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Theme.terracotta.opacity(0.18), lineWidth: 0.5)
                            }
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(active ? "已选择" : "未选择")
    }
}

/// iOS-style toggle row — terracotta when on, with sliding thumb.
struct ToggleRow: View {
    let label: String
    var sub: String? = nil
    @Binding var on: Bool
    var isLast: Bool = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { on.toggle() }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(Theme.sans(14, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    if let sub {
                        Text(sub)
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.muted)
                    }
                }
                Spacer()
                ZStack(alignment: on ? .trailing : .leading) {
                    Capsule()
                        .fill(on ? Theme.terracotta : Theme.bg2)
                        .frame(width: 44, height: 26)
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .padding(.horizontal, 2)
                        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 50)
            .rowHairline(isLast: isLast)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: on)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(on ? "开启" : "关闭")
        .accessibilityHint("双击切换")
    }
}

/// Editable time row backed by DatePicker.
struct TimeRow: View {
    let label: String
    @Binding var time: Date
    var isLast: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(Theme.sans(14, relativeTo: .body))
                .foregroundStyle(Theme.ink)
            Spacer()
            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .rowHairline(isLast: isLast)
    }
}

/// Read-only label / value row.
struct ValueRow: View {
    let label: String
    let value: String
    var isLast: Bool = false
    var body: some View {
        HStack {
            Text(label).font(Theme.sans(14)).foregroundStyle(Theme.ink)
            Spacer()
            Text(value).font(Theme.sans(13)).foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .rowHairline(isLast: isLast)
    }
}

/// White card container with hairline border.
struct InsetCard<Content: View>: View {
    var radius: CGFloat = 18
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
