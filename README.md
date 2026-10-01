# 时光 · Days Remember

A Chinese-language anniversary and countdown app built with SwiftUI, iOS 17+. Native tabs, a photo-led day feed, monthly agenda, custom categories, reminders, share cards, and WidgetKit layouts share one visual system. The original prototype remains in `_design/days-remember/` as a historical reference.

## OS integrations

| Capability | Wiring |
|---|---|
| **Local notifications** | `Store/NotificationManager.swift` schedules `dr.day.<id>.pre.<offset>` requests via `UNUserNotificationCenter`. Authorization is requested on first launch, schedule re-syncs on day add/edit/delete and on every reminder-toggle change in 提醒. Quiet-hours toggle pushes any 22:00–08:00 trigger past 08:00. |
| **WidgetKit** | `DaysRememberWidget/` extension target with Small / Medium / Large families. Reads days through the `group.com.shiguang.daysremember` App Group (`Store/SharedStorage.swift`); the app calls `WidgetCenter.shared.reloadAllTimelines()` on every day change. Refreshes at the next midnight. |
| **PhotosPicker** | `DayEditorView` offers artwork presets and a photo picker. Photos are JPEG-compressed (max 1600px), stored on `Day.photoData`, and framed using `coverFocusX/Y`. `PhotoTile(day:)` shares that crop across the app and widget. |
| **Share sheet** | `ShareCardView` renders one of four templates via `ImageRenderer`. 分享图片 opens `UIActivityViewController`; 保存 writes to Photos via `PHPhotoLibrary` (requires `NSPhotoLibraryAddUsageDescription`). |

Out of scope: WeChat-/小红书-specific SDK integrations are intentionally not wired — the system share sheet routes to whatever messaging apps the user has installed.

## Build

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate `DaysRemember.xcodeproj` from `project.yml`.

```sh
brew install xcodegen
xcodegen generate
open DaysRemember.xcodeproj
```

Then choose an available iPhone simulator (iOS 17+).

## UI and tests

`Theme/Tokens.swift` defines the light palette and scalable Inter/system typography. Shared controls live in `Views/Components/Controls.swift`; `Theme/DayWidgetCard.swift` is used by both WidgetKit and the in-app gallery. Persisted category and cover identifiers remain compatible with existing data.

`DaysRememberTests` covers dates, lunar recurrence, persistence, settings, image crops, share rendering, and widget rendering. `DaysRememberUITests` exercises navigation, search, day CRUD across relaunch, category editing, system sharing, widget previews, and large accessibility text. Run `xcodebuild test -project DaysRemember.xcodeproj -scheme DaysRemember -destination 'platform=iOS Simulator,id=<UDID>' CODE_SIGNING_ALLOWED=NO`.

## Debug launch arguments

For inspecting individual screens without manual navigation, the app reads a few launch arguments (debug only — production launches ignore them):

```sh
# Pin "today" to 2026-04-23 (the prototype's reference date) so countdowns match the design.
# (`SIMCTL_CHILD_*` env vars are forwarded to the launched app by simctl.)
SIMCTL_CHILD_DR_PIN_TODAY=1 xcrun simctl launch <device> com.shiguang.daysremember

# Open a specific tab on launch
xcrun simctl launch <device> com.shiguang.daysremember --tab calendar         # home | calendar | categories | notifications

# Open a specific screen directly (bypasses the tab shell)
xcrun simctl launch <device> com.shiguang.daysremember --screen detail --day wedding
xcrun simctl launch <device> com.shiguang.daysremember --screen add
xcrun simctl launch <device> com.shiguang.daysremember --screen share --day japan
xcrun simctl launch <device> com.shiguang.daysremember --screen widgets
xcrun simctl launch <device> com.shiguang.daysremember --screen onboarding
```

`--day` accepts any sample id from `Models/SampleData.swift` (`wedding`, `baby`, `birthday`, `midautumn`, `japan`, `kaoyan`, `firstmet`, `work`, `dog`, `moved`).
