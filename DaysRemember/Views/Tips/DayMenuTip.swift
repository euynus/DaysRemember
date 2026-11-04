import SwiftUI
import TipKit

/// Pinning, sharing and deleting live in a day card's long-press menu, which nothing else shows.
struct DayMenuTip: Tip {
    var title: Text {
        Text(String(localized: "长按日子卡片", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
    }

    var message: Text? {
        Text(String(localized: "长按即可置顶、编辑、分享或删除。置顶的日子会排在首页最前，并优先展示在小组件中。",
                    bundle: AppLocalization.bundle, locale: AppLocalization.locale))
    }

    var image: Image? { Image(systemName: "hand.tap") }
}
