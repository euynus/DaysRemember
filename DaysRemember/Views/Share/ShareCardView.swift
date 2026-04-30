import SwiftUI

struct ShareCardView: View {
    @Environment(\.dismiss) private var dismiss
    let day: Day
    @State private var template: Template = .classic

    enum Template: String, CaseIterable {
        case classic, frame, minimal, collage
        var label: String {
            switch self {
            case .classic: return "经典"; case .frame: return "相框"
            case .minimal: return "极简"; case .collage: return "拼贴"
            }
        }
    }

    var body: some View {
        let info = DayInfo.compute(day)
        VStack(spacing: 0) {
            navBar
            Spacer()
            Group {
                switch template {
                case .classic: ClassicCard(day: day, info: info)
                case .frame: FrameCard(day: day, info: info)
                case .minimal: MinimalCard(day: day, info: info)
                case .collage: CollageCard(day: day, info: info)
                }
            }
            .padding(.horizontal, 32)
            Spacer()
            templatePicker
            shareRow.padding(.bottom, 36)
        }
        .background(Theme.bg2)
    }

    private var navBar: some View {
        HStack {
            Button("取消") { dismiss() }
                .font(Theme.sans(15, weight: .medium))
                .foregroundStyle(Theme.ink2)
                .buttonStyle(.plain)
            Spacer()
            Text("分享").font(Theme.serif(17, weight: .semibold))
            Spacer()
            Button("保存") {}
                .font(Theme.sans(15, weight: .semibold))
                .foregroundStyle(Theme.terracotta)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 8)
    }

    private var templatePicker: some View {
        HStack(spacing: 8) {
            ForEach(Template.allCases, id: \.self) { t in
                Button { template = t } label: {
                    Text(t.label)
                        .font(Theme.sans(12, weight: .medium))
                        .foregroundStyle(template == t ? Theme.bg : Theme.ink2)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(template == t ? Theme.ink : Theme.card)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 14)
    }

    private var shareRow: some View {
        HStack(spacing: 16) {
            shareIcon("微", color: Color(oklch: 0.7, 0.15, 145), label: "微信")
            shareIcon("朋", color: Color(oklch: 0.7, 0.15, 145), label: "朋友圈")
            shareIcon("小", color: Color(oklch: 0.65, 0.18, 25), label: "小红书")
            shareIcon("保", color: Theme.ink, label: "保存")
            shareIcon("更", color: Theme.ink2, label: "更多")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private func shareIcon(_ glyph: String, color: Color, label: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color.opacity(0.92))
                Text(glyph).font(Theme.sans(11)).foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            Text(label).font(Theme.sans(11)).foregroundStyle(Theme.ink2)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ClassicCard: View {
    let day: Day; let info: DayInfo
    var body: some View {
        ZStack(alignment: .topLeading) {
            PhotoTile(style: day.photo, cornerRadius: 18)
            VStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(day.categoryLabel)
                        .font(Theme.sans(11)).tracking(3.3)
                        .foregroundStyle(Color.white.opacity(0.8))
                    Text(day.title)
                        .font(Theme.serif(22, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(info.days)")
                        .font(Theme.serif(78, weight: .medium))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text("\(info.isPast ? "已经" : "还有") · 天")
                        .font(Theme.sans(12))
                        .tracking(2.4)
                        .foregroundStyle(Color.white.opacity(0.8))
                    Divider().background(Color.white.opacity(0.3)).padding(.top, 14)
                    Text("SHIGUANG · 时光")
                        .font(Theme.sans(10))
                        .tracking(2)
                        .foregroundStyle(Color.white.opacity(0.65))
                        .padding(.top, 14)
                }
            }
            .padding(22)
        }
        .frame(width: 280, height: 350)
        .shadow(color: .black.opacity(0.2), radius: 24, y: 12)
    }
}

struct FrameCard: View {
    let day: Day; let info: DayInfo
    var body: some View {
        VStack(spacing: 14) {
            PhotoTile(style: day.photo, cornerRadius: 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: 4) {
                Text(day.title)
                    .font(Theme.serif(16, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x1F1A15))
                Text("第 \(info.days) 天")
                    .font(Theme.serif(32, weight: .medium))
                    .foregroundStyle(Color(oklch: 0.62, 0.12, 35))
                    .monospacedDigit()
                Text(CNDate.full(day.date))
                    .font(Theme.sans(10))
                    .tracking(2)
                    .foregroundStyle(Color(hex: 0x8A8074))
            }
            .padding(.bottom, 4)
        }
        .padding(12)
        .frame(width: 280, height: 350)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 24, y: 12)
    }
}

struct MinimalCard: View {
    let day: Day; let info: DayInfo
    var body: some View {
        VStack(alignment: .leading) {
            Text("时光 · \(CNDate.full(day.date))")
                .font(Theme.sans(10))
                .tracking(3)
                .foregroundStyle(Theme.muted)
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Text("\(info.days)")
                    .font(Theme.serif(110, weight: .medium))
                    .foregroundStyle(Theme.terracotta)
                    .monospacedDigit()
                Text("\(info.isPast ? "已经过去" : "还有") · 天")
                    .font(Theme.serif(13))
                    .tracking(2.6)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Text(day.title)
                .font(Theme.serif(18, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
        .padding(28)
        .frame(width: 280, height: 350, alignment: .topLeading)
        .background(Theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.16), radius: 24, y: 12)
    }
}

struct CollageCard: View {
    let day: Day; let info: DayInfo
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                PhotoTile(style: day.photo, cornerRadius: 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(spacing: 6) {
                    PhotoTile(style: .baby, cornerRadius: 12)
                    PhotoTile(style: .japan, cornerRadius: 12)
                }
                .frame(width: 78)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(day.title).font(Theme.serif(16, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Text("\(info.days)")
                    .font(Theme.serif(28, weight: .medium))
                    .foregroundStyle(Color(oklch: 0.78, 0.13, 35))
                    .monospacedDigit()
            }
            Text("\(CNDate.full(day.date)) · 时光")
                .font(Theme.sans(10))
                .tracking(2)
                .foregroundStyle(Color.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(width: 280, height: 350)
        .background(Theme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 24, y: 12)
    }
}
