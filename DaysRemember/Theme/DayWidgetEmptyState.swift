import SwiftUI

/// A Home Screen widget with no day to show: none yet, or its chosen day was deleted.
struct DayWidgetEmptyState: View {
    let selectionMissing: Bool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.title)
                .foregroundStyle(Theme.ink2)
            Text(selectionMissing
                 ? String(localized: "日子已删除", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                 : String(localized: "还没有日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                .font(Theme.sans(13))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
        }
        // A widget has fixed physical bounds, as for the card.
        .dynamicTypeSize(...DynamicTypeSize.large)
    }
}
