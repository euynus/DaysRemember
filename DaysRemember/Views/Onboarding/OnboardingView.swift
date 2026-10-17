import SwiftUI

struct OnboardingView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var onFinish: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("时光")
                    .font(Theme.sans(17, weight: .heavy))
                    .foregroundStyle(Theme.ink2)
                if !dynamicTypeSize.isAccessibilitySize { collage }
                VStack(alignment: .leading, spacing: 10) {
                    Text("值得记住的每一天")
                        .font(Theme.sans(30, weight: .heavy, relativeTo: .largeTitle))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("从今天开始。")
                        .font(Theme.sans(17))
                        .foregroundStyle(Theme.ink2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            PillButton(title: String(localized: "开始记录", bundle: AppLocalization.bundle, locale: AppLocalization.locale), trailingSystemName: "arrow.right", fill: true, height: 56, action: onFinish)
                .padding(20)
                .background(Theme.bg)
        }
        .background(Theme.bg)
    }

    /// Pastel tiles of the cover illustrations, one per category colour.
    private var collage: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                tile(.birthday, tint: Theme.notePink)
                    .frame(height: 226)
                VStack(spacing: 10) {
                    tile(.voyage, tint: Theme.noteBlue).frame(height: 108)
                    tile(.home, tint: Theme.noteYellow).frame(height: 108)
                }
            }
            GridRow {
                tile(.homecoming, tint: Theme.notePeach).frame(height: 120)
                tile(.study, tint: Theme.noteGreen).frame(height: 120)
            }
        }
        .accessibilityHidden(true)
    }

    private func tile(_ style: PhotoStyle, tint: Color) -> some View {
        FlatCover(style: style)
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(tint, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}
