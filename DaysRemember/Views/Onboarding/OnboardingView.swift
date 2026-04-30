import SwiftUI

struct OnboardingView: View {
    @State private var page: Int
    var onFinish: () -> Void = {}

    init(initialPage: Int = 0, onFinish: @escaping () -> Void = {}) {
        _page = State(initialValue: initialPage)
        self.onFinish = onFinish
    }

    private struct PageDef {
        var kind: Kind
        var eyebrow: String? = nil
        var title: String
        var sub: String?
        enum Kind { case hero, count, photo, final }
    }

    private let pages: [PageDef] = [
        .init(kind: .hero, eyebrow: "时光",
              title: "记住那些\n重要的日子",
              sub: "结婚纪念、宝宝出生、一场旅行，\n让时间被温柔地记录。"),
        .init(kind: .count,
              title: "倒数，或者纪念",
              sub: "过去的可以回望，\n未来的值得期待。"),
        .init(kind: .photo,
              title: "加上一张照片\n让日子有温度",
              sub: "一张图胜过千言万语。"),
        .init(kind: .final,
              title: "让时间被好好珍藏",
              sub: "现在开始，记录你的第一个日子。"),
    ]

    var body: some View {
        let cur = pages[page]
        let isFinal = (page == pages.count - 1)
        let textColor: Color = isFinal ? .white : Theme.ink
        let subColor: Color = isFinal ? Color.white.opacity(0.8) : Theme.ink2

        ZStack {
            background(isFinal: isFinal)

            VStack(spacing: 0) {
                Spacer().frame(height: 80)

                VStack(alignment: .leading, spacing: 0) {
                    Group {
                        switch cur.kind {
                        case .hero: HeroArt()
                        case .count: CountDemoArt()
                        case .photo: PhotoDemoArt()
                        case .final: FinalArt()
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        if let eyebrow = cur.eyebrow {
                            Text(eyebrow)
                                .font(Theme.serif(14))
                                .tracking(5.6) // ≈ 0.4em at 14pt
                                .foregroundColor(Theme.terracotta)
                        }
                        Text(cur.title)
                            .font(Theme.serif(32, weight: .semibold))
                            .lineSpacing(32 * 0.3)
                            .foregroundColor(textColor)
                        if let sub = cur.sub {
                            Text(sub)
                                .font(Theme.sans(15))
                                .lineSpacing(15 * 0.7)
                                .foregroundColor(subColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 36)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 24) {
                    HStack(spacing: 6) {
                        ForEach(pages.indices, id: \.self) { i in
                            Capsule()
                                .fill(dotColor(i: i, isFinal: isFinal))
                                .frame(width: i == page ? 22 : 6, height: 6)
                                .animation(.easeInOut(duration: 0.18), value: page)
                        }
                    }
                    if !isFinal {
                        HStack {
                            Button("跳过") { page = pages.count - 1 }
                                .font(Theme.sans(14, weight: .medium))
                                .foregroundStyle(Theme.muted)
                                .buttonStyle(.plain)
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { page += 1 }
                            } label: {
                                HStack(spacing: 4) {
                                    Text("下一步")
                                    Text("→")
                                }
                                .font(Theme.sans(15, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                                .background(Theme.terracotta)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Button(action: onFinish) {
                            Text("开始记录 ✨")
                                .font(Theme.sans(16, weight: .semibold))
                                .foregroundStyle(Color(oklch: 0.45, 0.09, 25))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(isFinal ? .dark : nil)
        .ignoresSafeArea()
    }

    private func dotColor(i: Int, isFinal: Bool) -> Color {
        let active = i == page
        if isFinal { return active ? .white : Color.white.opacity(0.3) }
        return active ? Theme.terracotta : Theme.hairlineStrong
    }

    @ViewBuilder
    private func background(isFinal: Bool) -> some View {
        if isFinal {
            LinearGradient(
                colors: [Color(oklch: 0.55, 0.11, 30), Color(oklch: 0.35, 0.08, 20)],
                startPoint: UnitPoint(x: 0.4, y: 0),
                endPoint: UnitPoint(x: 0.6, y: 1)
            )
            .ignoresSafeArea()
        } else {
            Theme.bg.ignoresSafeArea()
        }
    }
}
