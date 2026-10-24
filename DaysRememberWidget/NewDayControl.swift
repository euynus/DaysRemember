import AppIntents
import SwiftUI
import WidgetKit

/// A Control Center, Lock Screen and Action button control that opens a new day's editor.
struct NewDayControl: ControlWidget {
    static let kind = "dev.gooday.days.newDay"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: NewDayIntent()) {
                Label(String(localized: "新建日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                      systemImage: "calendar.badge.plus")
            }
        }
        .displayName(LocalizedStringResource("intent.newDay.title", defaultValue: "新建日子"))
        .description(LocalizedStringResource("intent.newDay.description", defaultValue: "打开「时光」，记下一个新的日子。"))
    }
}
