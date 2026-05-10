import SwiftUI

struct WidgetsPreviewView: View {
    @State private var size: WSize = .m
    enum WSize: String, CaseIterable { case s, m, l
        var label: String { ["s":"小", "m":"中", "l":"大"][rawValue] ?? "" }
    }

    var onBack: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            navBar
            VStack(alignment: .leading, spacing: 4) {
                Text("把日子放在主屏")
                    .font(Theme.serif(26, weight: .semibold))
                Text("每次解锁手机，都和重要的日子打个招呼")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 12)

            HStack(spacing: 8) {
                ForEach(WSize.allCases, id: \.self) { s in
                    Button { size = s } label: {
                        Text("\(s.label)号")
                            .font(Theme.sans(13, weight: .medium))
                            .foregroundStyle(size == s ? Theme.terracotta : Theme.ink2)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(size == s ? Theme.terracottaSoft : Theme.card)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(size == s ? Theme.terracotta.opacity(0.22) : Theme.hairline,
                                                  lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            ScrollView(.vertical, showsIndicators: false) {
                wallpaper
                styleGrid.padding(.top, 22)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
    }

    private var navBar: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            Text("桌面小组件").font(Theme.serif(17, weight: .semibold))
            Spacer()
            Color.clear.frame(width: 18, height: 18)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 8)
    }

    private var wallpaper: some View {
        VStack(spacing: 14) {
            Group {
                switch size {
                case .s: SmallWidget()
                case .m: MediumWidget()
                case .l: LargeWidget()
                }
            }
            Text("主屏预览").font(Theme.sans(11)).foregroundStyle(Color.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .background(
            LinearGradient(
                colors: [Color(oklch: 0.62, 0.08, 250), Color(oklch: 0.42, 0.08, 270)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var styleGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "风格")
            let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(0..<4, id: \.self) { i in styleTile(i) }
            }
        }
    }

    @ViewBuilder
    private func styleTile(_ i: Int) -> some View {
        let isInverted = i == 0
        VStack(alignment: .leading) {
            Text("样式 \(i+1)")
                .font(Theme.sans(11))
                .foregroundStyle((isInverted ? Color.white : Theme.ink).opacity(0.7))
            Spacer()
            Group {
                switch i {
                case 0:
                    VStack(alignment: .leading, spacing: 2) {
                        Text("132").font(Theme.serif(32, weight: .medium))
                        Text("蜜月旅行 · 天")
                            .font(Theme.sans(10))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                case 1:
                    VStack(alignment: .leading, spacing: 2) {
                        Text("132")
                            .font(Theme.serif(30, weight: .medium))
                            .foregroundStyle(Theme.terracotta)
                        Text("蜜月旅行")
                            .font(Theme.sans(10))
                            .foregroundStyle(Theme.muted)
                    }
                case 2:
                    Text("距 蜜月旅行\n还有 132 天")
                        .font(Theme.serif(14, weight: .medium))
                case 3:
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)], spacing: 3) {
                        PhotoTile(style: .japan, flat: true, cornerRadius: 6).frame(height: 36)
                        PhotoTile(style: .wedding, flat: true, cornerRadius: 6).frame(height: 36)
                        PhotoTile(style: .baby, flat: true, cornerRadius: 6).frame(height: 36)
                        PhotoTile(style: .birthday, flat: true, cornerRadius: 6).frame(height: 36)
                    }
                default: EmptyView()
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(isInverted ? Theme.ink : Theme.card)
        .foregroundStyle(isInverted ? Theme.bg : Theme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: isInverted ? 0 : 0.5)
        )
    }
}

struct SmallWidget: View {
    var body: some View {
        ZStack {
            PhotoTile(style: .japan, cornerRadius: 0)
            LinearGradient(
                colors: [.black.opacity(0.08), .black.opacity(0.22), .black.opacity(0.72)],
                startPoint: UnitPoint(x: 0.5, y: 0.15),
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("时光")
                        .font(Theme.sans(10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(Color.white.opacity(0.82))
                    Spacer()
                    Circle()
                        .fill(Color.white.opacity(0.76))
                        .frame(width: 6, height: 6)
                }
                Spacer(minLength: 4)
                Text("蜜月旅行")
                    .font(Theme.sans(12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineLimit(1)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("132").font(Theme.serif(46, weight: .medium))
                        .monospacedDigit()
                    Text("天后")
                        .font(Theme.sans(11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.82))
                }
            }
            .padding(16)
            .foregroundStyle(.white)
        }
        .frame(width: 150, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct MediumWidget: View {
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading) {
                Text("即将到来")
                    .font(Theme.sans(10, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.terracotta)
                Text("蜜月旅行")
                    .font(Theme.serif(18, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 3)
                Spacer(minLength: 8)
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("132")
                        .font(Theme.serif(42, weight: .medium))
                        .foregroundStyle(Theme.terracotta)
                        .monospacedDigit()
                    Text("天后")
                        .font(Theme.sans(12, weight: .medium))
                        .foregroundStyle(Theme.muted)
                }
                Text("8月23日")
                    .font(Theme.sans(11, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PhotoTile(style: .japan, flat: true, cornerRadius: 24)
                .frame(width: 104, height: 104)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.65), lineWidth: 1)
                )
        }
        .padding(16)
        .frame(width: 320, height: 150)
        .background(
            LinearGradient(
                colors: [Theme.card, Theme.terracottaSoft],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
    }
}

struct LargeWidget: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PhotoTile(style: .japan, flat: true, cornerRadius: 0)
            LinearGradient(
                colors: [.black.opacity(0.08), .black.opacity(0.22), .black.opacity(0.72)],
                startPoint: UnitPoint(x: 0.5, y: 0.15),
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 0) {
                Text("旅行")
                    .font(Theme.sans(10, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Color.white.opacity(0.78))
                Spacer()
                Text("蜜月旅行")
                    .font(Theme.serif(24, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("132")
                        .font(Theme.serif(72, weight: .medium))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text("天后")
                        .font(Theme.sans(13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.82))
                }
                .padding(.top, 4)
                Text("8月23日")
                    .font(Theme.sans(12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .padding(.top, 2)
            }
            .padding(20)
        }
        .frame(width: 320, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
    }
}
