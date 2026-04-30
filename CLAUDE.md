# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project shape

Native SwiftUI iOS 17+ app — Chinese-language anniversary / countdown ("时光 · Days Remember"), built from the Anthropic Design handoff bundle in `_design/days-remember/`. The HTML/React prototype there is the source of truth for visual design; the Swift code recreates it pixel-faithfully. Two targets: the main app (`DaysRemember`) and a WidgetKit extension (`DaysRememberWidget`).

## Build & run

The Xcode project is **generated** from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen). `DaysRemember.xcodeproj/` is gitignored — never edit it directly. After any change to `project.yml`, file structure, or entitlements, regenerate.

```sh
brew install xcodegen          # one-time
xcodegen generate              # rewrites DaysRemember.xcodeproj
open DaysRemember.xcodeproj
```

CLI build (no Xcode UI). The simulator UDID is whichever iPhone 17/Pro is booted; query with `xcrun simctl list devices available`.

```sh
xcodebuild -project DaysRemember.xcodeproj -scheme DaysRemember \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath /tmp/dr-dd build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

Tests: `xcodebuild ... test` with the same flags. Single test class: append `-only-testing:DaysRememberTests/LunarTests`.

When SourceKit reports "Cannot find Theme / Day / DayInfo in scope" on a single file, that is **file-isolation** — there's no per-file build context outside the project. Run `xcodegen generate` and rely on `xcodebuild` for ground truth.

## Debug launch arguments

The app reads the following from `ProcessInfo.processInfo.arguments` / env (defined in `DaysRememberApp.swift::DebugLaunch`):

```sh
# Pin "today" to 2026-04-23 to match the prototype's hard-coded countdowns
SIMCTL_CHILD_DR_PIN_TODAY=1 xcrun simctl launch <UDID> com.shiguang.daysremember

# Land on a specific tab
xcrun simctl launch <UDID> com.shiguang.daysremember --tab calendar          # home | calendar | categories | notifications

# Bypass the tab shell entirely and open one screen
xcrun simctl launch <UDID> com.shiguang.daysremember --screen detail --day wedding
xcrun simctl launch <UDID> com.shiguang.daysremember --screen onboarding --page 2
# also: --screen add | share | widgets
```

`--day` accepts any sample id from `Models/SampleData.swift` (`wedding`, `baby`, `birthday`, `midautumn`, `japan`, `kaoyan`, `firstmet`, `work`, `dog`, `moved`).

## Architecture

### Data flow

`DayStore` (`Store/DayStore.swift`) is the single `@MainActor ObservableObject` source of truth for the user's days. JSON-encoded `[Day]` is persisted to **shared UserDefaults** via `SharedStorage.defaults` (App Group `group.com.shiguang.daysremember`, falling back to `.standard` if the entitlement isn't wired).

`DayStore.days.didSet` chains three side effects in order: `save()` → `rescheduleNotifications()` → `reloadWidgetTimelines()`. This means *any* mutation to the array — `add`, `update`, `delete`, even `resetToSamples` — automatically persists, re-syncs `UNUserNotificationCenter`, and pokes `WidgetCenter`.

`AppSettings` is a separate `ObservableObject` of `@AppStorage` toggles (onboarding flag, reminder offsets, quiet hours). It's passed into `DayStore` via the `store.settings = settings` assignment in `DaysRememberApp.swift`'s `.task` — that pattern avoids the circular dependency between the two `@StateObject`s.

### Navigation shell

`RootTabView` is a **custom** tab bar, not SwiftUI's `TabView`. It uses `.safeAreaInset(edge: .bottom) { TabBar(...) }` — earlier attempts with `ZStack(alignment: .bottom)` bottom-anchored short screens. Only the Home tab wraps in `NavigationStack` (for push to Detail); the other tabs render flat to avoid the iOS 26 nav-bar height reservation that pushes content down.

Two layout invariants every screen must follow:

1. The outer `VStack` ends with `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)` so it claims the full vertical area instead of intrinsic sizing.
2. Don't use `Image(systemName: "...").opacity(0)` as a layout-balance placeholder — without an explicit `.font()` the system Image's intrinsic size inflates the row and floats the screen toward the middle. Use `Color.clear.frame(width: 18, height: 18)` instead (see `NotificationsView.topBar`).

### Theme

`Theme/OKLCH.swift` does runtime OKLCH → sRGB conversion via the OKLab pipeline (Björn Ottosson). `Color(oklch: L, C, h)` and `Color.adaptive(lightOklch:darkOklch:)` are the standard constructors — they match the prototype's CSS values directly without hand-converting. `Theme/Tokens.swift` exposes the named tokens (`Theme.bg`, `Theme.terracotta`, `Theme.sage`, …) and font helpers (`Theme.serif(_:weight:)`, `Theme.sans(_:weight:)`) that prefer Noto Serif/Sans SC when bundled and degrade to Songti SC / PingFang SC otherwise.

`PhotoStyle` is an enum of 10 named gradients (`.wedding`, `.baby`, …) matching the prototype's CSS classes one-for-one. `PhotoTile` renders either a real `UIImage` from `Day.photoData` or the gradient — call `PhotoTile(day:)` whenever you have a `Day` so user-picked photos take precedence over the preset palette.

### Lunar calendar

`Lunar/` is a verbatim port of `_design/days-remember/project/lunar.jsx`. `LunarTable.info` is the 1900-2100 packed bitfield. All formatters live in `Lunar.swift`: `solarToLunar`, `lunarToSolar`, `fmt`, `fmtFull`. The calendar always uses `Asia/Shanghai`. `SolarTerms.swift` adds 24节气 + traditional holiday lookup.

`DayInfo.compute(_:today:)` (in `Models/DayInfo.swift`) is the recurrence logic:

- Non-recurring days → countdown to original date.
- Recurring (Gregorian) → next anniversary in current/next year.
- Recurring **lunar** → walk `today.year ... today.year + 2`, find the first lunar-anniversary `≥ today` via `lunarToSolar(year:, month:, day:, isLeap:)` using the original date's lunar components.

`Today.date` is `Date()` in production, but in DEBUG builds reads the `DR_PIN_TODAY` env var to pin to `2026-04-23` (the prototype's reference today). All countdown computations go through `Today.date`, never `Date()` directly.

### Widget extension & shared sources

`DaysRememberWidget/` is an `app-extension` target. `project.yml` adds **shared source paths** for `DaysRemember/Models`, `DaysRemember/Lunar`, `DaysRemember/Theme`, and `DaysRemember/Store/SharedStorage.swift` to both targets — no duplicate business logic. The widget's `TimelineProvider` reads `[Day]` JSON from `SharedStorage.defaults` and refreshes at the next midnight (so countdowns tick down even between manual reloads).

Both targets carry the App Group entitlement (`DaysRemember/Resources/DaysRemember.entitlements`, `DaysRememberWidget/DaysRememberWidget.entitlements`). On the simulator the group works without provisioning.

When changing the data model in `Day.swift` or its persistence format, be aware: the widget reads the same JSON. Either bump the `storageKey` or stay backward-compatible.

### OS integrations

| Layer | Entry point |
|---|---|
| `UNUserNotificationCenter` | `Store/NotificationManager.swift`. Identifier scheme `dr.day.<id>.pre.<offset>` lets a single day's pending requests be cancelled or replaced in isolation. Authorization requested in `DaysRememberApp.body`'s `.task`. Toggles in `NotificationsView` use `reactiveBinding(_:)` so flipping a reminder offset re-syncs the schedule immediately. |
| `PhotosUI.PhotosPicker` | `AddDayView.photosPickerTile`. Picked images are JPEG-recompressed to ≤ 1600px before being stored on `Day.photoData`. |
| `ImageRenderer` + `UIActivityViewController` | `ShareCardView.renderCardImage()` + `Components/ShareSheet.swift`. The labelled buttons (微信 / 朋友圈 / 小红书 / 更多) all route to the same system share sheet; no per-app SDK integration. |
| `PHPhotoLibrary` | `Components/ShareSheet.swift::PhotoSaver`. Requires `NSPhotoLibraryAddUsageDescription` in `Info.plist`. |

## Conventions

- Commits use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `feat(scope):`, …). Each integration / discrete change is its own commit.
- Tests in `DaysRememberTests/` use `@testable import DaysRemember`. The target requires the main module to be built with `-enable-testing` (XcodeGen does this automatically for the test bundle).
- Sample data in `Models/SampleData.swift` is verbatim from `_design/days-remember/project/data.jsx` — keep them in sync if regenerating.
- Open `_design/days-remember/project/Days Remember.html` in a browser to compare any artboard against the running app.
