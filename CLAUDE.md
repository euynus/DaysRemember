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
  -derivedDataPath /tmp/dr-dd build
```

Keep simulator ad-hoc signing enabled as configured in `project.yml`; App Group and widget integration require it. Use `bash scripts/ci.sh` for the full CI suite and Release build on a disposable simulator. The `DaysRememberCI` scheme excludes only the manually configured Home Screen widget test. Single test class on a dedicated test device: `xcodebuild ... test -only-testing:DaysRememberTests/LunarTests`. UI fixtures reset their simulator's library, so never use a simulator containing user data.

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
# also: --screen add | share | widgets | settings
```

`--day` accepts any sample id from `Models/SampleData.swift` (`wedding`, `baby`, `birthday`, `midautumn`, `japan`, `kaoyan`, `firstmet`, `work`, `dog`, `moved`).

## Architecture

### Data flow

`DayStore` (`Store/DayStore.swift`) is the single `@MainActor @Observable` source of truth for both `days: [Day]` and `categories: [CategoryDefinition]`. Categories and active-day metadata use `categories.v1` / `days.v2` in **shared UserDefaults** via `SharedStorage.defaults` (App Group `group.com.shiguang.daysremember`). `PhotoFileStore` supplies the local Codable context that writes photos to content-addressed App Group files; plain Codable encoders keep inline photos for portable backups. Recently deleted days (`deletedDays.v1`) and replaced sync versions (`syncConflicts.v1`) use the same file-backed encoding and expire after `DayStore.retention` (30 days); older inline records still decode. The original `days.v1` remains unchanged and is read only when `days.v2` is absent. A corrupt current record or missing photo must not fall back to stale legacy data. Custom test stores can inject a photo directory or omit it for inline-only persistence.

`DayStore.days.didSet` chains three side effects in order: `save()` → `rescheduleNotifications()` → `reloadWidgetTimelines()`. So *any* mutation — `add`, `update`, `delete`, `resetToSamples` — automatically persists, re-syncs `UNUserNotificationCenter`, and pokes `WidgetCenter`. `categories.didSet` only persists; notifications and widgets don't depend on it. `add(_:)` and `update(_:)` route through `normalized(_:)`, which reconciles the day's `categoryID` / `categoryLabel` against the current category list and clamps `coverFocusX/Y` into `[0, 1]`.

`AppSettings` (`Store/AppSettings.swift`) is a separate `@Observable` class backed by `UserDefaults.standard` (onboarding flag, per-offset reminders, daily `notificationHour`/`notificationMinute`, plus `momentsEnabled` (每日问候 — a repeating greeting at `greetingHour`/`greetingMinute`, default 08:00) and `memoryEnabled` (时光回忆 — a yearly "想起这一天" for past days); both are scheduled in `NotificationManager.sync`). Quiet hours were removed: `AppSettingsSnapshot` still encodes `quietHours: false`, and decodes a missing greeting time as 08:00, for older devices. It's wired to `DayStore` via `store.settings = settings` in `DaysRememberApp.swift`'s `.task` — that pattern avoids a circular dependency between the two objects.

### iCloud sync

Days and categories sync through `Store/CloudLibrarySync.swift`: native `CKSyncEngine`, a private custom zone in `iCloud.com.shiguang.daysremember`, separate day/category records and `CKAsset` photos, with record mapping and the locally checkpointed `CloudLibraryState` in `CloudLibraryRecord.swift`. `DayStore.persist` forwards each saved snapshot through `CloudLibrarySync.shared.updateLocal`; remote changes arrive in `DayStore.applyCloudUpdate`, which merges by record ID and keeps every replaced local version as a `SyncConflict` (restorable in 数据与同步). Automated and simulator launches do not connect to CloudKit.

Only settings still use `Store/ICloudSyncStore.swift`: an `NSUbiquitousKeyValueStore` envelope `{ updatedAt, deviceID, value }` under `icloud.settings.v1`, last-writer-wins on `updatedAt`, with the remote timestamp mirrored at `icloud.localTimestamp.<key>`. Applying a remote snapshot suppresses the resulting push and cancels any pending debounced one. The legacy `icloud.days.v1` / `icloud.categories.v1` keys are never written; 导入旧版 iCloud 数据 appends unseen records once. The KVS entitlement lives on `DaysRemember.entitlements` only — the widget reads through shared `UserDefaults`.

### Navigation shell

`RootTabView` uses SwiftUI `TabView` with four labelled tabs. Home, Calendar, and Categories each retain a `NavigationStack` and `NavigationPath`; detail destinations are typed as `DayRoute` (a day ID — `DetailView` reads the live record and closes itself when a sync deletes the day), category destinations as `CategoryRoute`. Notifications renders flat. Root screens supply their own headers and hide the system navigation bar; pushed screens (day detail, category day list) keep it, because a hidden bar disables the interactive edge swipe, and put their actions in toolbar items. The home header's gear opens `SettingsView`, which presents language, widgets, and data & sync as sheets. Native tab safe areas replace the old floating-bar padding. Category lists derive their contents from the live store rather than keeping a stale array.

Two layout invariants every screen must follow:

1. The outer `VStack` ends with `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)` so it claims the full vertical area instead of intrinsic sizing.
2. Don't use `Image(systemName: "...").opacity(0)` as a layout-balance placeholder — without an explicit `.font()` the system Image's intrinsic size inflates the row and floats the screen toward the middle. Use `Color.clear.frame(width: 18, height: 18)` instead.

### Theme

The app uses an editorial journal style: off-white canvas, ink headings, vermilion actions, fine separators, and colorful hand-drawn default covers with loose black outlines. User-selected photos retain their original rendering. Avoid heavy shadows, nested cards, and decorative illustration overlays. It remains **light-mode only** via `Info.plist` and `.preferredColorScheme(.light)`. Dynamic Type is supported; fixed seven-column date cells and the editor action bar cap scaling at XXXL. Printed share previews and fixed-size widgets constrain their internal text scale independently of app controls.

`Theme/Tokens.swift` defines colors, scalable Inter/system text, and Baskerville countdown numerals via `Theme.number`. The five persisted `CategoryColorToken` names (`rose`/`amber`/`dusty`/`sage`/`terracotta`) remain stable. Non-category meanings use semantic tokens (`Theme.solarTerm`, `Theme.danger`, `Theme.coverPaper`), never category colors. XcodeGen flattens bundled resources, so `UIAppFonts` must use bare filenames rather than `Fonts/` paths.

Reusable navigation, filters, metadata, grouped rows, native pickers, and toggles live in `Views/Components/Controls.swift`. Category icons use SF Symbols; `CategoryDefinition.symbolName` maps legacy stored sticker names to their equivalent symbols.

`PhotoStyle` keeps existing raw identifiers but maps them to the twelve bundled AI-generated hand-drawn assets in `PhotoStyle.pickerOptions` through `assetName`. The editor compares asset names when highlighting a preset so legacy aliases remain selected. `PhotoTile` renders `Day.photoData` first, using `coverFocusX/Y`, then falls back to the preset. Default illustrations fit fully inside the frame on `Theme.coverPaper`, with edges feathered by `PhotoTile.featheredEdges` so the paper texture shows no seam; user photos fill and crop as before. A new day's cover follows its system category (`PhotoStyle.defaultCover(forCategoryID:)`) until a template or photo is picked. Both drawing and hit-testing are constrained to its frame. Always use `PhotoTile(day:)` when a `Day` is available.

Photo decoding uses ImageIO downsampling before allocating the display bitmap. `PhotoDecodeCache` shares size-specific results using full-content SHA-256 keys, with a 32 MiB `NSCache` cost limit (an eviction hint, not a hard process-memory ceiling). Compact rows use 192/256px thumbnails and category tiles 512px; full covers default to 1600px. List rows pass `decodesAsynchronously: true` to decode uncached photos off the main actor; widgets and `ImageRenderer` exports must keep synchronous decoding, since their tasks never run. Import downsampling and JPEG encoding run off the main actor. Pixel limits must not be multiplied by the device screen scale. `RenderingTests.testPhotoImportPixelBudgetAndBenchmark` compares the old renderer path with the new import on the same 12MP fixture.

### Categories

`DayCategory` (`Models/Category.swift`) is the original five-value enum (`.love`, `.family`, `.travel`, `.work`, `.life`) and remains on every `Day` for backwards compat — the widget and older snapshots still decode it. Custom categories layer on top via `CategoryDefinition` (id / name / icon / `colorToken: CategoryColorToken` / `isSystem`), persisted under `categories.v1`. Each `Day` carries `categoryID` (a free-form string for custom categories, or the system enum's raw value) and a `categoryLabel` snapshot of the name at write time.

`DayStore.updateCategory` rewrites the `categoryLabel` on every day that referenced a renamed custom category. `deleteCategory(id:migrateTo:)` requires a migration target and rewrites `categoryID` / `categoryLabel` / `category` on each affected day in one pass. System categories (`isSystem == true`) cannot be renamed or deleted; they're merged back into the persisted list on every load via `normalizedCategories(_:)`, so a missing system category in stored JSON is self-healing.

Unknown category IDs and label snapshots survive normalization because cloud days may arrive before their category definitions. Appearance-only category edits do not rewrite days. Settings record their local timestamp immediately, before the debounced cloud push, and a newer accepted remote snapshot cancels that pending push.

### Lunar calendar

`Lunar/` retains the table and conversion semantics from `_design/days-remember/project/lunar.jsx`. `LunarTable.info` is the 1900-2100 packed bitfield; immutable cumulative year offsets avoid repeatedly summing it during conversion. `LunarTests` checks all 73,412 supported days and records a 2,000-round-trip benchmark. All formatters live in `Lunar.swift`: `solarToLunar`, `lunarToSolar`, `fmt`, `fmtFull`. The app calendar uses `Asia/Shanghai`; lunar table arithmetic uses fixed UTC+8. `SolarTerms.swift` solves the 24 节气 from the truncated VSOP87 series in `VSOP87.swift` (plus nutation, aberration and ΔT), dates them in Beijing time and caches each year; `LunarTests` pins published equinox/solstice instants to within two minutes. Traditional festivals skip leap months and include 除夕.

`DayInfo.compute(_:today:)` (in `Models/DayInfo.swift`) is the recurrence logic:

- Non-recurring days → countdown to original date.
- Recurring (Gregorian) → next anniversary in current/next year.
- Recurring **lunar** → search Gregorian years for the first occurrence `≥ today`. `DayInfo.occurrences(of:inGregorianYear:)` is shared with the calendar and checks both adjacent lunar years, preserving January anniversaries and years containing two occurrences. Gregorian February 29 normalizes to March 1 in non-leap years in both views.

`Today.date` is `Date()` in production. In DEBUG, it reads the `DR_PIN_TODAY` env var: `"1"` pins to `2026-04-23` (the prototype's reference today), or any `yyyy-MM-dd` string pins to that date — useful for date-sensitive test runs. All countdown computations go through `Today.date`, never `Date()` directly.

### Widget extension & shared sources

`DaysRememberWidget/` is an `app-extension` target. `project.yml` shares Models, Lunar, Theme, SharedStorage, PhotoTile, fonts, and localization with the app. The widget's own `Assets.xcassets` holds 720px JPEG copies of the covers under the same names; run `bash scripts/widget-covers.sh` after adding or changing a cover. `DayWidgetCard` supplies all three widget sizes and the exact in-app preview layouts. `SelectWidgetDay` uses App Intents for per-widget day selection; leaving it empty selects the nearest upcoming day without a one-year cutoff, or the most recent past day when nothing is ahead. `WidgetDay.resolve` is shared with the in-app preview. A deleted selected day renders an empty state, never an unrelated replacement. The provider decodes metadata only (`SharedStorage.loadLibrary()`) and reads photos just for displayed days (`Library.withPhoto`; none for Lock Screen families), then requests a refresh at the next midnight; the entry date is passed into the card for its countdown. The in-app picker is only a preview; actual instances are configured through the system Edit Widget menu.

Both targets carry the App Group entitlement (`DaysRemember/Resources/DaysRemember.entitlements`, `DaysRememberWidget/DaysRememberWidget.entitlements`). On the simulator the group works without provisioning.

Widget photos use `PhotoTile.maximumPixelSize` (512 for small, 720 otherwise). WidgetKit archives the bitmap itself; resizing its SwiftUI frame does not avoid the image-area limit. Keep the pixel-bound regression test, including Retina image scales, and verify a real Home Screen widget rather than only the in-app gallery.

When changing the data model in `Day.swift` or its persistence format, be aware: the widget reads the same JSON, and CloudKit records carry the same day metadata. `Day.init(from:)` already supplies defaults for every field added after the initial schema (`recurring`, `lunar`, `categoryID`, `categoryLabel`, `coverFocusX/Y`, `reminderOffsets`, `note`, `location`, `pinned`); add new fields via `decodeIfPresent` with a sensible default, or bump `storageKey` / `icloud.*.v1`.

### OS integrations

| Layer | Entry point |
|---|---|
| `UNUserNotificationCenter` | `Store/NotificationManager.swift`. Identifier scheme `dr.day.<id>.pre.<offset>` lets a single day's pending requests be cancelled or replaced in isolation. Authorization is requested when a day with reminders is saved or reminders are enabled (skipped when `DebugLaunch.isAutomated` so `simctl` screenshots don't stall on the system prompt). Reminders fire on their own day at `AppSettings.notificationHour` / `notificationMinute` or the day's `reminderTime` — see `NotificationManager.triggerDate(...)`; the daily greeting uses `greetingHour` / `greetingMinute`. |
| `CKSyncEngine` | `Store/CloudLibrarySync.swift` — see *iCloud sync* above. |
| `NSUbiquitousKeyValueStore` | `Store/ICloudSyncStore.swift`, settings only — see *iCloud sync* above. Entitlement `com.apple.developer.ubiquity-kvstore-identifier` lives on `DaysRemember.entitlements` only; the widget reads through shared `UserDefaults`. |
| `PhotosUI.PhotosPicker` | `DayEditorView.photosPickerTile`. Picked images are downsampled and JPEG-recompressed off the main actor to ≤ 1600px before being stored on `Day.photoData`. Cancelled selections never overwrite the current cover. `coverFocusX/Y` (normalized 0–1) drives the framing in `PhotoTile`. |
| `ImageRenderer` + `UIActivityViewController` | `ShareCardView.renderImage(card:ratio:scale:)` (card height or 3:4, at least 3x) + `Components/ShareSheet.swift`. 分享图片 presents the rendered image using an item-driven sheet; no per-app SDK integration. |
| `PHPhotoLibrary` | `Components/ShareSheet.swift::PhotoSaver`. Requires `NSPhotoLibraryAddUsageDescription` in `Info.plist`. |

Per-day reminder offsets use `nil` for global settings and `[]` for no day reminders. Ordinary reminders and yearly memories share the same time: the day's override, else the global time.

## Conventions

- Commits use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `feat(scope):`, …). Each integration / discrete change is its own commit.
- Tests in `DaysRememberTests/` use `@testable import DaysRemember`. The target requires the main module to be built with `-enable-testing` (XcodeGen does this automatically for the test bundle).
- Sample data in `Models/SampleData.swift` is verbatim from `_design/days-remember/project/data.jsx` — keep them in sync if regenerating.
- Validate UI changes with simulator screenshots and the rendering/UI tests, including compact screens and large accessibility text.
- `docs/` is the public GitHub Pages site (product page in three languages, privacy policy, support page) and holds the App Store screenshots. Everything there is published, and its claims must match the app; update the pages when a described feature, setting name or data practice changes. `SettingsView.siteURL` links to it.
