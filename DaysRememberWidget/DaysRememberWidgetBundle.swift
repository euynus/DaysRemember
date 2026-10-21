import WidgetKit
import SwiftUI

@main
struct DaysRememberWidgetBundle: WidgetBundle {
    var body: some Widget {
        DaysRememberWidget()
        DaysListWidget()
        NewDayControl()
    }
}
