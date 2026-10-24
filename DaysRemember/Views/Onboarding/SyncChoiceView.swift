import SwiftUI

/// Says what iCloud sync uploads before anything is, and offers to keep everything on this device.
/// The last step of onboarding.
struct SyncChoiceView: View {
    var onChoose: (SyncChoice) -> Void
    /// One width for every symbol, so the lines of text start together.
    @ScaledMetric(relativeTo: .body) private var symbolWidth: CGFloat = 28

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("要用 iCloud 同步吗？")
                    .font(Theme.sans(30, weight: .heavy, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 18) {
                    point("tray.full", String(localized: "同步的内容：日子、分类、笔记、地点、照片和提醒设置。", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                    point("lock.icloud", String(localized: "保存在你自己 iCloud 账户的私有空间，由 Apple 存储和传输，开发者无法访问。", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                    point("iphone", String(localized: "选择「仅本机使用」，所有内容只保存在这台设备上。", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                    point("gearshape", String(localized: "之后可以在「我的 › 数据与同步」中随时更改，或删除 iCloud 中的数据。", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                PillButton(title: String(localized: "使用 iCloud 同步", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                           fill: true, height: 56) { onChoose(.iCloud) }
                    .accessibilityIdentifier("syncChoice.iCloud")
                PillButton(title: String(localized: "仅本机使用", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                           style: .ghost, fill: true, height: 56) { onChoose(.localOnly) }
                    .accessibilityIdentifier("syncChoice.localOnly")
            }
            .padding(20)
            .background(Theme.bg)
        }
        .background(Theme.bg)
    }

    private func point(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text)
                .font(Theme.sans(16))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
                .font(Theme.symbol(18, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: symbolWidth)
        }
    }
}
