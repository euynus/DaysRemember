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

`DayStore` (`Store/DayStore.swift`) is the single `@MainActor ObservableObject` source of truth for both `days: [Day]` and `categories: [CategoryDefinition]`. Each is JSON-encoded under its own key (`days.v1`, `categories.v1`) in **shared UserDefaults** via `SharedStorage.defaults` (App Group `group.com.shiguang.daysremember`, falling back to `.standard` if the entitlement isn't wired).

`DayStore.days.didSet` chains three side effects in order: `save()` → `rescheduleNotifications()` → `reloadWidgetTimelines()`. So *any* mutation — `add`, `update`, `delete`, `resetToSamples` — automatically persists, re-syncs `UNUserNotificationCenter`, and pokes `WidgetCenter`. `categories.didSet` only persists; notifications and widgets don't depend on it. `add(_:)` and `update(_:)` route through `normalized(_:)`, which reconciles the day's `categoryID` / `categoryLabel` against the current category list and clamps `coverFocusX/Y` into `[0, 1]`.

`AppSettings` is a separate `ObservableObject` of `@AppStorage` toggles (onboarding flag, per-offset reminders, quiet hours, daily `notificationHour`/`notificationMinute`, and `memoryEnabled` / `momentsEnabled` placeholder switches). It's wired to `DayStore` via `store.settings = settings` in `DaysRememberApp.swift`'s `.task` — that pattern avoids the circular dependency between the two `@StateObject`s.

### iCloud sync

`Store/ICloudSyncStore.swift` wraps `NSUbiquitousKeyValueStore` with a generic `Envelope { updatedAt, deviceID, value }` payload and three keys: `icloud.days.v1`, `icloud.categories.v1`, `icloud.settings.v1`. Both `DayStore.enableCloudSync()` and `AppSettings.enableCloudSync(onRemoteApply:)` fire from `DaysRememberApp.body.task` and:

1. Subscribe to `NSUbiquitousKeyValueStore.didChangeExternallyNotification` to pull newer values.
2. After every local mutation, push if the local timestamp is newer (last-writer-wins on `updatedAt`).
3. Mirror the remote timestamp at `icloud.localTimestamp.<key>` in shared defaults — `pull*IfNewer` reads this to decide whether to apply.

When applying a remote change, `applyCloudChange(key:updatedAt:)` flips `isApplyingCloudChange = true` so the resulting `didSet` doesn't push back into KVS and race the timestamp. Categories arriving from the cloud also re-`normalized()` every day — the **day** side is the source of truth for `categoryLabel`. Envelopes are capped at ~950 KB; pushes that exceed it silently drop (the KVS hard limit is 1 MB per key). The `com.apple.developer.ubiquity-kvstore-identifier` entitlement lives on **`DaysRemember.entitlements` only** — the widget reads through shared `UserDefaults` and does not need its own KVS entitlement.

### Navigation shell

`RootTabView` is a **custom** tab bar, not SwiftUI's `TabView`. The bar is a **floating pill** (`.regularMaterial` Capsule) laid over the content via `.overlay(alignment: .bottom) { TabBar(...).padding(.bottom, 30) }` — the active tab is an ink `Capsule` with icon + label, inactive tabs are icon-only and muted. Because the bar floats *over* content (it doesn't inset it), every tab screen's scroll content pads ~120pt at the bottom so the last row clears the bar. The four tabs are layered in a `ZStack` and switched via `.opacity` + `.allowsHitTesting` + `.accessibilityHidden` so each tab keeps its own navigation state when the user switches away and back. Home, Calendar, and Categories each own a `NavigationStack` + `NavigationPath` (`homePath`, `calendarPath`, `categoryPath`); Detail is pushed via `.navigationDestination(for: Day.self)`. Notifications renders flat. Every NavigationStack hides the system bar (`.toolbar(.hidden, for: .navigationBar)`) and the screens render their own header — this avoids the iOS 26 nav-bar height reservation that would push content down.

Two layout invariants every screen must follow:

1. The outer `VStack` ends with `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)` so it claims the full vertical area instead of intrinsic sizing.
2. Don't use `Image(systemName: "...").opacity(0)` as a layout-balance placeholder — without an explicit `.font()` the system Image's intrinsic size inflates the row and floats the screen toward the middle. Use `Color.clear.frame(width: 18, height: 18)` instead (see `NotificationsView.topBar`).

### Theme

The app is a **travel-scrapbook** aesthetic (the design's final landed direction — see `_design/days-remember/chats/chat1.md`): cool light-gray paper canvas, near-black bold headings, polaroid photo cards, pastel sticky notes clipped with paperclips, flat stickers, handwriting accents. It is **light-mode only** — locked via `Info.plist` `UIUserInterfaceStyle = Light` and `.preferredColorScheme(.light)` in `DaysRememberApp`.

`Theme/OKLCH.swift` does runtime OKLCH → sRGB conversion via the OKLab pipeline (Björn Ottosson). `Color(oklch: L, C, h)` and `Color(hex:)` are the standard constructors — they match the prototype's CSS values directly. `Theme/Tokens.swift` exposes the scrapbook tokens: canvas/ink (`Theme.bg`, `.ink`, `.ink2`, `.muted`), the sticky-note palette (`noteBlue`/`noteBlueInk`, `noteYellow`, `notePink`, `noteGreen`, `notePeach`), and the category sticker tints (`catLove`, `catFamily`, `catTravel`, `catWork`, `catLife`). The five `CategoryColorToken`/`DayCategory` color names (`rose`/`amber`/`dusty`/`sage`/`terracotta`) are kept (persisted in `categories.v1`) but **remapped** to those tints. Fonts are bundled (`Resources/Fonts/`, registered via `UIAppFonts`): `Theme.sans(_:weight:)` = Inter (headings/titles/meta/numbers — add `.monospacedDigit()` on countdowns), `Theme.hand(_:)` = Caveat (English date accents/eyebrows), `Theme.handCN(_:)` = Ma Shan Zheng (Chinese mood notes & sticky-note text). **Gotcha:** XcodeGen flattens bundled resources to the bundle root, so `UIAppFonts` must list bare filenames (`Caveat.ttf`), not `Fonts/Caveat.ttf`.

The reusable scrapbook kit lives in two files: `Views/Components/ScrapbookKit.swift` (`Sticker` — 13 flat icons drawn in a `Canvas` with a white outline + drop shadow; `StickyNote`, `Paperclip`, `Tape`, the `.polaroidCard()` frame modifier, and the `noteColorFor`/`stickerFor`/`enDate` helpers) and `Views/Components/ScrapbookControls.swift` (`FAB`, `PillButton`, `Chip`, `InfoChip`, `MetaRow`, `SectionHeader`, `NavHeader`, `CardList`/`RowDivider`, `SegPicker`, `ScrapToggle`/`ToggleCell`). `ScrapbookKit.swift` is also compiled into the widget target.

`PhotoStyle` (`Theme/PhotoStyle.swift`) is an enum of two flavors: 10 luminous "travel photo" gradients (`.wedding`, `.baby`, …) — a diagonal base + radial "sun bloom" + film grain, rendered by `GradientPhotoView`/`PhotoGrain` in `Theme/ScrapbookPhoto.swift` from the verbatim oklch values in `styles.css` `.photo-*` — and 9 hand-drawn Canvas scenes (`.sketchLove`, …) drawn by `HandDrawnPhotoBackground`. The first five sketch variants are exposed as `PhotoStyle.categorySketchPresets`. `PhotoTile` renders either a real `UIImage` from `Day.photoData` (framed by `coverFocusX/Y`) or the `PhotoStyle` background — call `PhotoTile(day:)` whenever you have a `Day` so user-picked photos take precedence over the preset palette.

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

`DaysRememberWidget/` is an `app-extension` target. `project.yml` adds **shared source paths** for `DaysRemember/Models`, `DaysRemember/Lunar`, `DaysRemember/Theme`, `DaysRemember/Store/SharedStorage.swift`, and `DaysRemember/Views/Components/ScrapbookKit.swift` (self-contained SwiftUI — gives the widget the same stickers/sticky-notes/polaroid frame) to both targets — no duplicate business logic. The bundled fonts (`Resources/Fonts/`) are also copied into the widget and registered in its `Info.plist` so the handwriting renders there too. The widget's `TimelineProvider` reads `[Day]` JSON from `SharedStorage.defaults` and refreshes at the next midnight (so countdowns tick down even between manual reloads).

Both targets carry the App Group entitlement (`DaysRemember/Resources/DaysRemember.entitlements`, `DaysRememberWidget/DaysRememberWidget.entitlements`). On the simulator the group works without provisioning.

When changing the data model in `Day.swift` or its persistence format, be aware: the widget reads the same JSON, and so does iCloud KVS. `Day.init(from:)` already supplies defaults for every field added after the initial schema (`recurring`, `lunar`, `categoryID`, `categoryLabel`, `coverFocusX/Y`, `reminderOffsets`, `note`, `location`, `pinned`); add new fields via `decodeIfPresent` with a sensible default, or bump `storageKey` / `icloud.*.v1`.

### OS integrations

| Layer | Entry point |
|---|---|
| `UNUserNotificationCenter` | `Store/NotificationManager.swift`. Identifier scheme `dr.day.<id>.pre.<offset>` lets a single day's pending requests be cancelled or replaced in isolation. Authorization requested in `DaysRememberApp.body`'s `.task` (skipped when `DebugLaunch.isAutomated` so `simctl` screenshots don't stall on the system prompt). Trigger time honors `AppSettings.notificationHour` / `notificationMinute`; quiet hours push any 22:00–08:00 trigger past 08:00 — see `NotificationManager.triggerDate(...)` (also covered by `UIUXModelTests`). |
| `NSUbiquitousKeyValueStore` | `Store/ICloudSyncStore.swift` — see *iCloud sync* above. Entitlement `com.apple.developer.ubiquity-kvstore-identifier` lives on `DaysRemember.entitlements` only; the widget reads through shared `UserDefaults`. |
| `PhotosUI.PhotosPicker` | `AddDayView.photosPickerTile`. Picked images are JPEG-recompressed to ≤ 1600px before being stored on `Day.photoData`. `coverFocusX/Y` (normalized 0–1) drives the framing in `PhotoTile`. |
| `ImageRenderer` + `UIActivityViewController` | `ShareCardView.renderCardImage()` + `Components/ShareSheet.swift`. The labelled buttons (微信 / 朋友圈 / 小红书 / 更多) all route to the same system share sheet; no per-app SDK integration. |
| `PHPhotoLibrary` | `Components/ShareSheet.swift::PhotoSaver`. Requires `NSPhotoLibraryAddUsageDescription` in `Info.plist`. |

## Conventions

- Commits use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `feat(scope):`, …). Each integration / discrete change is its own commit.
- Tests in `DaysRememberTests/` use `@testable import DaysRemember`. The target requires the main module to be built with `-enable-testing` (XcodeGen does this automatically for the test bundle).
- Sample data in `Models/SampleData.swift` is verbatim from `_design/days-remember/project/data.jsx` — keep them in sync if regenerating.
- Open `_design/days-remember/project/Days Remember.html` in a browser to compare any artboard against the running app.
