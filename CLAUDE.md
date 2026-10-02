# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project shape

Native SwiftUI iOS 17+ app — Chinese-language anniversary / countdown ("时光 · Days Remember"). The current UI uses native tabs, a photo-led feed, a monthly agenda, and shared app/widget layouts. `_design/days-remember/` preserves the historical prototype, not the current visual specification. Two targets: the main app (`DaysRemember`) and a WidgetKit extension (`DaysRememberWidget`).

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
xcrun simctl launch <UDID> com.shiguang.daysremember --screen onboarding
# also: --screen add | share | widgets
```

`--day` accepts any sample id from `Models/SampleData.swift` (`wedding`, `baby`, `birthday`, `midautumn`, `japan`, `kaoyan`, `firstmet`, `work`, `dog`, `moved`).

## Architecture

### Data flow

`DayStore` (`Store/DayStore.swift`) is the single `@MainActor ObservableObject` source of truth for both `days: [Day]` and `categories: [CategoryDefinition]`. Each is JSON-encoded under its own key (`days.v1`, `categories.v1`) in **shared UserDefaults** via `SharedStorage.defaults` (App Group `group.com.shiguang.daysremember`, falling back to `.standard` if the entitlement isn't wired).

`DayStore.days.didSet` chains three side effects in order: `save()` → `rescheduleNotifications()` → `reloadWidgetTimelines()`. So *any* mutation — `add`, `update`, `delete`, `resetToSamples` — automatically persists, re-syncs `UNUserNotificationCenter`, and pokes `WidgetCenter`. `categories.didSet` only persists; notifications and widgets don't depend on it. `add(_:)` and `update(_:)` route through `normalized(_:)`, which reconciles the day's `categoryID` / `categoryLabel` against the current category list and clamps `coverFocusX/Y` into `[0, 1]`.

`AppSettings` is a separate `ObservableObject` of `@AppStorage` toggles (onboarding flag, per-offset reminders, quiet hours, daily `notificationHour`/`notificationMinute`, plus `momentsEnabled` (每日晨间问候 — a repeating 08:00 greeting) and `memoryEnabled` (时光回忆 — a yearly "想起这一天" for past days); both are scheduled in `NotificationManager.sync`). It's wired to `DayStore` via `store.settings = settings` in `DaysRememberApp.swift`'s `.task` — that pattern avoids the circular dependency between the two `@StateObject`s.

### iCloud sync

`Store/ICloudSyncStore.swift` wraps `NSUbiquitousKeyValueStore` with a generic `Envelope { updatedAt, deviceID, value }` payload and three keys: `icloud.days.v1`, `icloud.categories.v1`, `icloud.settings.v1`. Both `DayStore.enableCloudSync()` and `AppSettings.enableCloudSync(onRemoteApply:)` fire from `DaysRememberApp.body.task` and:

1. Subscribe to `NSUbiquitousKeyValueStore.didChangeExternallyNotification` to pull newer values.
2. After every local mutation, push if the local timestamp is newer (last-writer-wins on `updatedAt`).
3. Mirror the remote timestamp at `icloud.localTimestamp.<key>` in shared defaults — `pull*IfNewer` reads this to decide whether to apply.

When applying a remote change, `applyCloudChange(key:updatedAt:)` flips `isApplyingCloudChange = true` so the resulting `didSet` doesn't push back into KVS and race the timestamp. Categories arriving from the cloud also re-`normalized()` every day — the **day** side is the source of truth for `categoryLabel`. Envelopes are capped at ~950 KB; pushes that exceed it silently drop (the KVS hard limit is 1 MB per key). The `com.apple.developer.ubiquity-kvstore-identifier` entitlement lives on **`DaysRemember.entitlements` only** — the widget reads through shared `UserDefaults` and does not need its own KVS entitlement.

### Navigation shell

`RootTabView` uses SwiftUI `TabView` with four labelled tabs. Home, Calendar, and Categories each retain a `NavigationStack` and `NavigationPath`; detail destinations are typed as `Day`, category destinations as `CategoryRoute`. Notifications renders flat. Screens supply their own headers and hide the system navigation bar. Native tab safe areas replace the old floating-bar padding. Category lists derive their contents from the live store rather than keeping a stale array.

Two layout invariants every screen must follow:

1. The outer `VStack` ends with `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)` so it claims the full vertical area instead of intrinsic sizing.
2. Don't use `Image(systemName: "...").opacity(0)` as a layout-balance placeholder — without an explicit `.font()` the system Image's intrinsic size inflates the row and floats the screen toward the middle. Use `Color.clear.frame(width: 18, height: 18)` instead (see `NotificationsView.topBar`).

### Theme

The app uses an editorial photo-journal style: off-white canvas, ink headings, vermilion actions, fine separators, and photographic covers. Avoid heavy shadows, nested cards, and decorative illustration overlays. It remains **light-mode only** via `Info.plist` and `.preferredColorScheme(.light)`. Dynamic Type is supported; fixed seven-column date cells and the editor action bar cap scaling at XXXL. Printed share previews and fixed-size widgets constrain their internal text scale independently of app controls.

`Theme/Tokens.swift` defines colors, scalable Inter/system text, and Baskerville countdown numerals via `Theme.number`. The five persisted `CategoryColorToken` names (`rose`/`amber`/`dusty`/`sage`/`terracotta`) remain stable. XcodeGen flattens bundled resources, so `UIAppFonts` must use bare filenames rather than `Fonts/` paths.

Reusable navigation, filters, metadata, grouped rows, native pickers, and toggles live in `Views/Components/Controls.swift`. Category icons use SF Symbols; `CategoryDefinition.symbolName` maps legacy stored sticker names to their equivalent symbols.

`PhotoStyle` keeps existing raw identifiers but maps them to five bundled AI-generated photographic assets through `assetName`. The editor compares asset names when highlighting a preset so legacy aliases remain selected. `PhotoTile` renders `Day.photoData` first, using `coverFocusX/Y`, then falls back to the preset. Both drawing and hit-testing are constrained to its frame. Always use `PhotoTile(day:)` when a `Day` is available.

Photo decoding uses ImageIO downsampling before allocating the display bitmap. `PhotoDecodeCache` shares size-specific results using full-content SHA-256 keys, with a 32 MiB `NSCache` cost limit (an eviction hint, not a hard process-memory ceiling). Compact rows use 192/256px thumbnails; full covers default to 1600px. Import downsampling and JPEG encoding run off the main actor. Pixel limits must not be multiplied by the device screen scale. `RenderingTests.testPhotoImportPixelBudgetAndBenchmark` compares the old renderer path with the new import on the same 12MP fixture.

### Categories

`DayCategory` (`Models/Category.swift`) is the original five-value enum (`.love`, `.family`, `.travel`, `.work`, `.life`) and remains on every `Day` for backwards compat — the widget and older snapshots still decode it. Custom categories layer on top via `CategoryDefinition` (id / name / icon / `colorToken: CategoryColorToken` / `isSystem`), persisted under `categories.v1`. Each `Day` carries `categoryID` (a free-form string for custom categories, or the system enum's raw value) and a `categoryLabel` snapshot of the name at write time.

`DayStore.updateCategory` rewrites the `categoryLabel` on every day that referenced a renamed custom category. `deleteCategory(id:migrateTo:)` requires a migration target and rewrites `categoryID` / `categoryLabel` / `category` on each affected day in one pass. System categories (`isSystem == true`) cannot be renamed or deleted; they're merged back into the persisted list on every load via `normalizedCategories(_:)`, so a missing system category in stored JSON is self-healing.

### Lunar calendar

`Lunar/` is a verbatim port of `_design/days-remember/project/lunar.jsx`. `LunarTable.info` is the 1900-2100 packed bitfield. All formatters live in `Lunar.swift`: `solarToLunar`, `lunarToSolar`, `fmt`, `fmtFull`. The calendar always uses `Asia/Shanghai`. `SolarTerms.swift` adds 24节气 + traditional holiday lookup.

`DayInfo.compute(_:today:)` (in `Models/DayInfo.swift`) is the recurrence logic:

- Non-recurring days → countdown to original date.
- Recurring (Gregorian) → next anniversary in current/next year.
- Recurring **lunar** → walk `today.year ... today.year + 2`, find the first lunar-anniversary `≥ today` via `lunarToSolar(year:, month:, day:, isLeap:)` using the original date's lunar components.

`Today.date` is `Date()` in production. In DEBUG, it reads the `DR_PIN_TODAY` env var: `"1"` pins to `2026-04-23` (the prototype's reference today), or any `yyyy-MM-dd` string pins to that date — useful for date-sensitive test runs. All countdown computations go through `Today.date`, never `Date()` directly.

### Widget extension & shared sources

`DaysRememberWidget/` is an `app-extension` target. `project.yml` shares Models, Lunar, Theme, SharedStorage, PhotoTile, fonts, and image assets with the app. `DayWidgetCard` supplies all three widget sizes and the exact in-app preview layouts. `SelectWidgetDay` uses App Intents for per-widget day selection; leaving it empty selects the nearest upcoming day without a one-year cutoff. `WidgetDay.resolve` is shared with the in-app preview. A deleted selected day renders an empty state, never an unrelated replacement. The provider reads `[Day]` JSON from shared defaults and requests a refresh at the next midnight; the entry date is passed into the card for its countdown. The in-app picker is only a preview; actual instances are configured through the system Edit Widget menu.

Both targets carry the App Group entitlement (`DaysRemember/Resources/DaysRemember.entitlements`, `DaysRememberWidget/DaysRememberWidget.entitlements`). On the simulator the group works without provisioning.

Widget photos use `PhotoTile.maximumPixelSize` (512 for small, 720 otherwise). WidgetKit archives the bitmap itself; resizing its SwiftUI frame does not avoid the image-area limit. Keep the pixel-bound regression test, including Retina image scales, and verify a real Home Screen widget rather than only the in-app gallery.

When changing the data model in `Day.swift` or its persistence format, be aware: the widget reads the same JSON, and so does iCloud KVS. `Day.init(from:)` already supplies defaults for every field added after the initial schema (`recurring`, `lunar`, `categoryID`, `categoryLabel`, `coverFocusX/Y`, `reminderOffsets`, `note`, `location`, `pinned`); add new fields via `decodeIfPresent` with a sensible default, or bump `storageKey` / `icloud.*.v1`.

### OS integrations

| Layer | Entry point |
|---|---|
| `UNUserNotificationCenter` | `Store/NotificationManager.swift`. Identifier scheme `dr.day.<id>.pre.<offset>` lets a single day's pending requests be cancelled or replaced in isolation. Authorization requested in `DaysRememberApp.body`'s `.task` (skipped when `DebugLaunch.isAutomated` so `simctl` screenshots don't stall on the system prompt). Trigger time honors `AppSettings.notificationHour` / `notificationMinute`; quiet hours push any 22:00–08:00 trigger past 08:00 — see `NotificationManager.triggerDate(...)` (also covered by `UIUXModelTests`). |
| `NSUbiquitousKeyValueStore` | `Store/ICloudSyncStore.swift` — see *iCloud sync* above. Entitlement `com.apple.developer.ubiquity-kvstore-identifier` lives on `DaysRemember.entitlements` only; the widget reads through shared `UserDefaults`. |
| `PhotosUI.PhotosPicker` | `DayEditorView.photosPickerTile`. Picked images are downsampled and JPEG-recompressed off the main actor to ≤ 1600px before being stored on `Day.photoData`. Cancelled selections never overwrite the current cover. `coverFocusX/Y` (normalized 0–1) drives the framing in `PhotoTile`. |
| `ImageRenderer` + `UIActivityViewController` | `ShareCardView.renderCardImage()` + `Components/ShareSheet.swift`. 分享图片 presents the rendered image using an item-driven sheet; no per-app SDK integration. |
| `PHPhotoLibrary` | `Components/ShareSheet.swift::PhotoSaver`. Requires `NSPhotoLibraryAddUsageDescription` in `Info.plist`. |

## Conventions

- Commits use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `feat(scope):`, …). Each integration / discrete change is its own commit.
- Tests in `DaysRememberTests/` use `@testable import DaysRemember`. The target requires the main module to be built with `-enable-testing` (XcodeGen does this automatically for the test bundle).
- Sample data in `Models/SampleData.swift` is verbatim from `_design/days-remember/project/data.jsx` — keep them in sync if regenerating.
- Validate UI changes with simulator screenshots and the rendering/UI tests, including compact screens and large accessibility text.
