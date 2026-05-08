import SwiftUI

struct DayTile: View {
    enum Size { case hero, wide, sq }
    let day: Day
    let size: Size
    var action: () -> Void = {}

    var body: some View {
        let info = DayInfo.compute(day)
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                PhotoTile(day: day, cornerRadius: 20)

                if day.pinned {
                    pinnedBadge
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(10)
                        .allowsHitTesting(false)
                }

                content(info: info)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .foregroundStyle(.white)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
            .shadow(color: .black.opacity(0.05), radius: 16, y: 6)
        }
        .buttonStyle(PressableTileStyle())
        .accessibilityLabel("\(day.title)，\(info.days) \(info.labelShort)")
    }

    @ViewBuilder
    private func content(info: DayInfo) -> some View {
        switch size {
        case .hero:
            VStack(alignment: .leading, spacing: 8) {
                Text(day.categoryLabel.uppercased())
                    .font(Theme.sans(12))
                    .tracking(1.8)
                    .foregroundStyle(Color.white.opacity(0.85))
                Text(day.title)
                    .font(Theme.serif(22, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(info.days)")
                        .font(Theme.serif(56, weight: .medium))
                        .monospacedDigit()
                    Text("\(info.labelShort) · 天")
                        .font(Theme.sans(13))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
            }
        case .wide:
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(day.categoryLabel.uppercased())
                        .font(Theme.sans(10))
                        .tracking(1.5)
                        .foregroundStyle(Color.white.opacity(0.8))
                    Text(day.title)
                        .font(Theme.serif(17, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(info.days)")
                        .font(Theme.serif(36, weight: .medium))
                        .monospacedDigit()
                    Text(info.labelShort)
                        .font(Theme.sans(10))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
            }
        case .sq:
            VStack(alignment: .leading, spacing: 4) {
                Text(day.categoryLabel)
                    .font(Theme.sans(11))
                    .foregroundStyle(Color.white.opacity(0.8))
                Text(day.title)
                    .font(Theme.serif(14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(info.days)")
                        .font(Theme.serif(28, weight: .medium))
                        .monospacedDigit()
                    Text(info.labelShort)
                        .font(Theme.sans(10))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
            }
        }
    }

    private var pinnedBadge: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.2))
            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundStyle(.white)
        }
        .frame(width: 24, height: 24)
        .background(.ultraThinMaterial, in: Circle())
    }
}

struct PressableTileStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: configuration.isPressed)
    }
}
