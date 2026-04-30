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
                            .foregroundStyle(size == s ? Theme.bg : Theme.ink2)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(size == s ? Theme.ink : Theme.card)
                            .clipShape(Capsule())
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
        ZStack(alignment: .bottomLeading) {
            PhotoTile(style: .japan, cornerRadius: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text("蜜月旅行")
                    .font(Theme.sans(10))
                    .foregroundStyle(Color.white.opacity(0.85))
                Text("132").font(Theme.serif(44, weight: .medium))
                    .monospacedDigit()
                Text("天后 · 京都")
                    .font(Theme.sans(10))
                    .foregroundStyle(Color.white.opacity(0.8))
            }
            .padding(14)
            .foregroundStyle(.white)
        }
        .frame(width: 150, height: 150)
    }
}

struct MediumWidget: View {
    var body: some View {
        HStack(spacing: 0) {
            PhotoTile(style: .japan, flat: true, cornerRadius: 0)
                .frame(width: 150)
            VStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("即将到来").font(Theme.sans(10)).tracking(2)
                        .foregroundStyle(Color(hex: 0x8A8074))
                    Text("蜜月旅行").font(Theme.serif(16, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x1F1A15))
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("132")
                        .font(Theme.serif(38, weight: .medium))
                        .foregroundStyle(Color(oklch: 0.62, 0.12, 35))
                        .monospacedDigit()
                    Text("天 · 8月23日")
                        .font(Theme.sans(11))
                        .foregroundStyle(Color(hex: 0x8A8074))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            Spacer()
        }
        .frame(width: 320, height: 150)
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
    }
}

struct LargeWidget: View {
    var body: some View {
        VStack(spacing: 0) {
            PhotoTile(style: .japan, flat: true, cornerRadius: 0)
                .frame(height: 160)
            VStack(alignment: .leading, spacing: 0) {
                Text("即将到来")
                    .font(Theme.sans(10))
                    .tracking(2)
                    .foregroundStyle(Color(hex: 0x8A8074))
                Text("蜜月旅行")
                    .font(Theme.serif(18, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x1F1A15))
                    .padding(.top, 4)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("132")
                        .font(Theme.serif(56, weight: .medium))
                        .foregroundStyle(Color(oklch: 0.62, 0.12, 35))
                        .monospacedDigit()
                    Text("天后 · 京都").font(Theme.sans(12)).foregroundStyle(Color(hex: 0x8A8074))
                }
                .padding(.top, 10)
                HStack(spacing: 6) {
                    ForEach(0..<4) { i in
                        Capsule()
                            .fill(i == 0 ? Color(oklch: 0.62, 0.12, 35) : Color(hex: 0xEFE9DF))
                            .frame(height: 4)
                    }
                }
                .padding(.top, 12)
            }
            .padding(16)
        }
        .frame(width: 320, height: 320)
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
    }
}
