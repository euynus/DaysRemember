import SwiftUI

/// 还有 / 已经 above a count. Today has no label: the value says 今天.
struct CountLabel: View {
    let info: DayInfo

    var body: some View {
        Text(info.isPast ? String(localized: "countdown.since", defaultValue: "已经", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
             : String(localized: "countdown.ahead", defaultValue: "还有", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            .font(Theme.sans(13, weight: .bold))
            .foregroundStyle(Theme.onPastel)
    }
}
