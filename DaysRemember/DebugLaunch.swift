#if DEBUG
import SwiftUI

/// `xcrun simctl launch ... --screen detail|add|share|onboarding [--day <id>]`
/// DEBUG-only — never compiled into the App Store / Release build.
@MainActor
enum DebugLaunch {
    /// Arguments that set up the library a launch starts from.
    private static let fixtureArguments = ["--seed-sample-data", "--empty-library", "--ui-polish-fixture",
                                           "--simulate-photo-save-failure"]

    private static var isFixture: Bool {
        let args = ProcessInfo.processInfo.arguments
        return fixtureArguments.contains { args.contains($0) }
    }

    /// `DaysRememberApp` builds its store first, so the language is reset before anything reads it.
    static func makeStore() -> DayStore {
        resetLanguage()
        if ProcessInfo.processInfo.arguments.contains("--ui-polish-fixture") {
            let name = "UIPolishUITests.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: name) else {
                preconditionFailure("Unable to create isolated UI test storage")
            }
            let store = DayStore(defaults: defaults)
            let category = CategoryDefinition(id: "ui-polish-custom", name: "Journeys and the people we meet along the way",
                                              icon: "camera", colorToken: .dusty, isSystem: false)
            store.categories = [category] + CategoryDefinition.system
            let calendar = CNDate.calendar
            let featured = Day(id: "ui-polish-featured", title: "和朋友去看海",
                               date: calendar.date(byAdding: .day, value: 10, to: Today.date)!,
                               category: .travel, photo: .japan)
            let long = Day(id: "ui-polish-long",
                           title: "Long-term memories from a summer journey together, with every little moment kept close to our hearts",
                           date: calendar.date(byAdding: .day, value: -12_000, to: Today.date)!,
                           category: .travel, photo: .japan, categoryID: category.id,
                           note: "Every day has a story worth remembering.", pinned: true, categoryLabel: category.name)
            store.days = [featured, long] + SampleData.days
            return store
        }
        guard ProcessInfo.processInfo.arguments.contains("--simulate-photo-save-failure") else {
            return DayStore()
        }
        // The failure fixture never reads or writes the real App Group library.
        let name = "EditorSaveUITests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else {
            preconditionFailure("Unable to create isolated editor test storage")
        }
        let directory = URL.temporaryDirectory.appending(path: name)
        let day = Day(id: "save-failure-fixture", title: "Save failure fixture", date: Today.date,
                      category: .life, photo: .systemDefault,
                      photoData: Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII="))
        do {
            defaults.set(try JSONEncoder().encode([day]), forKey: SharedStorage.legacyDaysKey)
            try Data("blocked photo directory".utf8).write(to: directory)
        } catch {
            preconditionFailure("Unable to prepare editor save failure: \(error)")
        }
        return DayStore(defaults: defaults, photoDirectory: directory)
    }

    /// Fixture launches and unit tests start from the system language, so a run stopped before
    /// it restored the language can't leave later runs in another one. A launch that needs one
    /// passes `-app.language.v1 <code>`, which overrides the stored choice; a relaunch without a
    /// fixture argument keeps the language its test chose.
    private static func resetLanguage() {
        guard isFixture || isUnitTesting else { return }
        SharedStorage.defaults.removeObject(forKey: AppLocalization.languageKey)
    }

    enum Screen: String {
        case onboarding, detail, add, share, widgets, settings
        case syncChoice = "sync-choice"

        @MainActor
        @ViewBuilder
        func makeView(store: DayStore) -> some View {
            switch self {
            case .onboarding:
                OnboardingView()
            case .syncChoice:
                SyncChoiceView { _ in }
            case .detail:
                NavigationStack { DetailView(day: DebugLaunch.day(store: store)) }.dayEditorHost()
            case .add:
                AddDayView()
            case .share:
                ShareCardView(day: DebugLaunch.day(store: store))
            case .widgets:
                WidgetsPreviewView()
            case .settings:
                NavigationStack { MeView().toolbarVisibility(.hidden, for: .navigationBar) }.categoryEditorHost()
            }
        }
    }

    /// True when launched with any debug arg or pinned-today env var — i.e. an
    /// automated screenshot session that can't dismiss system popups.
    static var isAutomated: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--screen") || args.contains("--tab") || isFixture { return true }
        if args.contains("--localized-samples") || args.contains("--seed-sync-conflicts") { return true }
        if ProcessInfo.processInfo.environment["DR_PIN_TODAY"] != nil { return true }
        return false
    }

    static var isUnitTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    static var showOnboarding: Bool { ProcessInfo.processInfo.arguments.contains("--show-onboarding") }

    static var screenOverride: Screen? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--screen"), i + 1 < args.count else { return nil }
        return Screen(rawValue: args[i + 1])
    }

    static func day(store: DayStore) -> Day {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--day"), i + 1 < args.count,
           let match = (store.days + SampleData.days).first(where: { $0.id == args[i + 1] }) {
            return match
        }
        return store.days.first ?? SampleData.days.first(where: { $0.id == "wedding" }) ?? SampleData.days[0]
    }

}
#endif
