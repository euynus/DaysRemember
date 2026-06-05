import SwiftUI

/// Paged scrapbook onboarding: a tilted-polaroid art area over a copy block
/// (handwritten eyebrow, big bold title, sub paragraph), page dots and a dark
/// pill advance button. The final page's "开始记录" CTA calls `onFinish`.
struct OnboardingView: View {
    @State private var page: Int
    var onFinish: () -> Void = {}

    init(initialPage: Int = 0, onFinish: @escaping () -> Void = {}) {
        _page = State(initialValue: initialPage)
        self.onFinish = onFinish
    }

    private struct PageDef {
        var kind: Kind
        var eyebrow: String
        var title: String
        var sub: String
        enum Kind { case welcome, count, collage, start }
    }

    private let pages: [PageDef] = [
        .init(kind: .welcome, eyebrow: "Days Remember",
              title: "把重要的日子\n做成手账",
              sub: "结婚纪念、宝宝出生、一场说走就走的旅行，\n都贴进你的时光手账。"),
        .init(kind: .count, eyebrow: "Countdown",
              title: "倒数，\n或者纪念",
              sub: "过去的可以回望，未来的值得期待。"),
        .init(kind: .collage, eyebrow: "Collage",
              title: "照片、贴纸、\n便利贴",
              sub: "每一天都值得被认真装点。"),
        .init(kind: .start, eyebrow: "Let’s go",
              title: "现在，\n贴上第一张",
              sub: "我们陪你一起记住。"),
    ]

    var body: some View {
        let isStart = (page == pages.count - 1)

        VStack(spacing: 0) {
            // Swipeable art area.
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    artView(pages[index].kind)
                        .padding(.horizontal, 28)
                        .padding(.top, 70)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityHidden(true)   // decorative collage
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Copy + controls.
            VStack(alignment: .leading, spacing: 0) {
                Text(pages[page].eyebrow)
                    .font(Theme.hand(26))
                    .foregroundStyle(Theme.catTravel)
                    .padding(.bottom, 10)
                Text(pages[page].title)
                    .font(Theme.sans(34, weight: .heavy))
                    .tracking(-1.0)
                    .lineSpacing(34 * 0.1)
                    .foregroundStyle(Theme.ink)
                Text(pages[page].sub)
                    .font(Theme.sans(15, weight: .medium))
                    .lineSpacing(15 * 0.6)
                    .foregroundStyle(Theme.ink2)
                    .padding(.top, 14)

                HStack {
                    pageDots
                    Spacer()
                    advanceButton(isStart: isStart)
                }
                .padding(.top, 28)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 30)
            .padding(.bottom, 44)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: page)
    }

    @ViewBuilder
    private func artView(_ kind: PageDef.Kind) -> some View {
        switch kind {
        case .welcome: WelcomeArt()
        case .count: CountArt()
        case .collage: CollageArt()
        case .start: StartArt()
        }
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(pages.indices, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Theme.ink : Theme.hairlineStrong)
                    .frame(width: i == page ? 22 : 7, height: 7)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("进度")
        .accessibilityValue("第 \(page + 1) 页，共 \(pages.count) 页")
    }

    @ViewBuilder
    private func advanceButton(isStart: Bool) -> some View {
        if isStart {
            PillButton(title: "开始记录", style: .dark,
                       trailingSystemName: "arrow.right", action: onFinish)
        } else {
            // Compact 56-wide dark pill with just an arrow.
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { page += 1 }
            } label: {
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 48)
                    .background(Capsule().fill(Theme.accent))
                    .shadow(color: Color(hex: 0x15171C).opacity(0.26), radius: 9, x: 0, y: 6)
            }
            .buttonStyle(PressScale())
        }
    }
}
