import SwiftUI

struct LocalizedRootView: View {
    let language: AppLanguage

    var body: some View {
        // Recreate localized view state without restarting storage/cloud setup.
        RootGate()
            .id(language)
            .environment(\.locale, AppLocalization.locale(for: language))
    }
}
