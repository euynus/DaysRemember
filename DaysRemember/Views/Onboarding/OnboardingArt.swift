import SwiftUI

/// Page 1 — three rotated photo cards stacked.
struct HeroArt: View {
    var body: some View {
        ZStack {
            PhotoTile(style: .birthday, flat: true)
                .frame(width: 140, height: 180)
                .rotationEffect(.degrees(-8))
                .offset(x: -46, y: 10)
                .shadow(color: .black.opacity(0.15), radius: 16, y: 12)
            PhotoTile(style: .japan, flat: true)
                .frame(width: 140, height: 180)
                .rotationEffect(.degrees(6))
                .offset(x: 46, y: -6)
                .shadow(color: .black.opacity(0.15), radius: 16, y: 12)
            ZStack(alignment: .bottomLeading) {
                PhotoTile(style: .wedding, flat: false)
                    .frame(width: 140, height: 180)
                VStack(alignment: .leading, spacing: 2) {
                    Text("结婚 · 第7年")
                        .font(Theme.serif(11))
                        .foregroundStyle(Color.white.opacity(0.85))
                    HStack(spacing: 3) {
                        Text("2387")
                            .font(Theme.serif(22, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("天")
                            .font(Theme.serif(12))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                }
                .padding(14)
            }
            .frame(width: 140, height: 180)
            .shadow(color: .black.opacity(0.18), radius: 20, y: 16)
            .zIndex(2)
        }
        .frame(height: 280)
    }
}

/// Page 2 — giant terracotta number.
struct CountDemoArt: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("2387")
                .font(Theme.serif(128, weight: .medium))
                .foregroundStyle(Theme.terracotta)
                .monospacedDigit()
                .lineSpacing(0)
            Text("天 · 自 2019.10.12")
                .font(Theme.sans(13))
                .tracking(3.9)
                .foregroundStyle(Theme.muted)
        }
        .frame(height: 280)
    }
}

/// Page 3 — 3-photo collage: tall left tile (2 rows) + 2 stacked right tiles.
struct PhotoDemoArt: View {
    var body: some View {
        HStack(spacing: 10) {
            captionTile(.wedding, eyebrow: "结婚纪念日", value: "2387 天")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: 10) {
                captionTile(.baby, eyebrow: "小年糕", value: "1165 天")
                captionTile(.japan, eyebrow: "北海道", value: "还有 88 天")
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 280)
    }

    @ViewBuilder
    private func captionTile(_ p: PhotoStyle, eyebrow: String, value: String) -> some View {
        ZStack(alignment: .bottomLeading) {
            PhotoTile(style: p, cornerRadius: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(eyebrow)
                    .font(Theme.serif(10))
                    .foregroundStyle(Color.white.opacity(0.85))
                Text(value)
                    .font(Theme.serif(14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(10)
        }
    }
}

/// Page 4 — concentric rings on the dark hero gradient.
struct FinalArt: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                .frame(width: 200, height: 200)
            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                .frame(width: 140, height: 140)
            Text("✦")
                .font(Theme.serif(48))
                .foregroundStyle(.white)
        }
        .frame(height: 280)
    }
}
