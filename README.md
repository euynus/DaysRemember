# 时光 · Days Remember

A Chinese-language anniversary and countdown app built with SwiftUI, iOS 17+. Native tabs, a photo-led day feed, monthly agenda, custom categories, reminders, share cards, and WidgetKit layouts share one visual system. The original prototype remains in `_design/days-remember/` as a historical reference.

## OS integrations

| Capability | Wiring |
|---|---|
| **Local notifications** | `Store/NotificationManager.swift` schedules date-specific requests via `UNUserNotificationCenter`. Permission is requested when saving a day with reminders or explicitly enabling reminders, not on launch. Gregorian/lunar occurrences are planned up to five years ahead, retaining the earliest 64 requests including the optional daily greeting. The reminder page reads actual pending requests and their latest date; opening the app replenishes this finite schedule. Quiet hours move 22:00+ to the following morning and pre-08:00 to the same morning. |
| **iCloud / backup** | `CloudLibrarySync` uses native `CKSyncEngine`, a private custom zone, separate day/category records, and `CKAsset` photos. Pending edits, record change tags, and the engine cursor are checkpointed locally. Data management offers JSON export/import, a pre-replacement recovery copy, and local recently deleted records. |
| **WidgetKit** | `DaysRememberWidget/` extension target with Small / Medium / Large families. Native Edit Widget configuration selects a specific day (including past days), or defaults to the nearest upcoming day. Reads days through the `group.com.shiguang.daysremember` App Group; each timeline includes the next seven midnights and resolves automatic selection for each date. The app reloads timelines when records change. |
| **PhotosPicker** | `DayEditorView` offers artwork presets and a photo picker. Photos are JPEG-compressed (max 1600px), stored on `Day.photoData`, and framed using `coverFocusX/Y`. `PhotoTile(day:)` shares that crop across the app and widget. |
| **Share sheet** | `ShareCardView` renders one of four templates via `ImageRenderer`; private notes are excluded unless explicitly enabled. 分享图片 opens `UIActivityViewController`; 保存 writes to Photos via `PHPhotoLibrary` (requires `NSPhotoLibraryAddUsageDescription`). |

Out of scope: WeChat-/小红书-specific SDK integrations are intentionally not wired — the system share sheet routes to whatever messaging apps the user has installed.

## Build

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate `DaysRemember.xcodeproj` from `project.yml`.

```sh
brew install xcodegen
xcodegen generate
open DaysRemember.xcodeproj
```

Then choose an available iPhone simulator (iOS 17+).

## Data and CloudKit

New installations start empty; daily greetings and annual memories are opt-in. Existing local records, photos, categories, and saved preferences are retained. Recurring days show both elapsed days from the original date (starting at zero) and the next anniversary.

The app refreshes its shared calendar day at midnight, on foreground entry, and after significant system time changes. Countdown, calendar, category, share, and widget-preview views observe that date without resetting navigation or in-progress editor state.

Editors with unsaved changes or a photo import in progress block swipe dismissal. Cancel offers an explicit discard confirmation; unchanged drafts close directly. Drafts remain local to the open editor and are not promised to survive app termination.

Active photos are stored as immutable SHA-256-addressed files in the App Group. `days.v2` contains only metadata and photo references; the original `days.v1` bytes remain untouched for recovery. The widget reads the same files. Missing or modified photo files stop normal writes and remain available through original-data export. Failed saves keep the editor open. CloudKit checkpoints use the same local photo-file format in their own directory, preserving the old checkpoint. Portable JSON backups still contain complete photos, including trash and retained sync versions.

`PersistencePerformanceTests` measures 10/100/1000 distinct 126 KiB JPEGs in isolated storage. On the QA simulator (Debug, three-run medians), 100-record title updates changed from 68.4 ms to 3.9 ms and warm loads from 54.7 ms to 19.4 ms. At 1000 records, updates changed from 892.4 ms to 129.8 ms and loads from 579.8 ms to 194.3 ms; one-time photo migration took 776.2 ms. These are local warm-storage measurements, not device launch or fsync guarantees. The 1000-photo backup exceeds the existing 100 MiB limit and is refused. Old preference snapshots and unreferenced immutable photos are intentionally retained; disk compaction is not part of this change.

Before enabling CloudKit, the app preserves a local migration backup. Legacy `NSUbiquitousKeyValueStore` day/category keys remain untouched and are no longer written. The data page can explicitly append unseen legacy records without overwriting matching IDs; upgrade all devices before further edits. This is a one-way migration, not ongoing interoperability with old clients. Small notification preferences continue using KVS.

Cloud updates merge by record ID. Before replacing conflicting local content, the app keeps a recoverable local snapshot. Account changes pause uploads until explicitly confirmed; a deleted server zone is not automatically recreated. Recently deleted records and recovery copies are device-local. Exported JSON includes photos and is not encrypted; the current backup size limit is 100 MB. Invalid imports or unreadable local data do not silently reset the library.

Local versions replaced by cloud records are retained separately by record and version, so later remote changes cannot overwrite them. Data management can preview, restore, or discard a single saved version without rolling back other records. Backup format v2 includes these device-local versions and still imports v1 backups.

For real iCloud operation, set `DEVELOPMENT_TEAM` in `project.yml`, enable the App Group, iCloud/CloudKit and Push Notifications capabilities, and associate `iCloud.com.shiguang.daysremember` with the app identifier. The project includes remote-notification background mode. Follow Apple's [CKSyncEngine sample setup](https://github.com/apple/sample-cloudkit-sync-engine), then deploy the CloudKit schema to Production before distributing a production build. Simulator builds intentionally do not connect to CloudKit and display a configuration notice; local features remain available. Simulator/unit checks do not verify provisioning, APNs, production schema, or two-device delivery; validate these on signed devices using the intended iCloud account.

## UI and tests

The visual system uses an off-white canvas, ink typography, restrained vermilion accents, and an editorial layout. `Theme/Tokens.swift` provides scalable Inter/system text and Baskerville countdown numerals. Five bundled AI-generated colorful hand-drawn presets use loose black outlines and clean backgrounds: flowers, celebration, coast, journal, and everyday life. User-selected photos still take precedence. Shared controls live in `Views/Components/Controls.swift`; `Theme/DayWidgetCard.swift` is used by both WidgetKit and the in-app gallery. Persisted category and cover identifiers remain compatible with existing data.

`DaysRememberTests` covers dates, lunar recurrence, persistence, settings, image crops, share rendering, and widget rendering. `DaysRememberUITests` exercises navigation, search, day CRUD across relaunch, category editing, system sharing, widget previews, and large accessibility text. Run `xcodebuild test -project DaysRemember.xcodeproj -scheme DaysRemember -destination 'platform=iOS Simulator,id=<UDID>'`. Simulator builds use local ad-hoc signing; do not disable signing for integration tests, because App Group registration and App Intents widgets depend on the simulated entitlements. This does not replace developer provisioning for physical devices.

Use a dedicated test simulator: UI fixtures deliberately reset its library. Backup, migration, CloudKit record/state, and notification planning tests run without a live cloud account. Automated debug launches suppress cloud operations and notification permission prompts.

## Debug launch arguments

For inspecting individual screens without manual navigation, the app reads a few launch arguments (debug only — production launches ignore them):

```sh
# Pin "today" to 2026-04-23 (the prototype's reference date) so countdowns match the design.
# (`SIMCTL_CHILD_*` env vars are forwarded to the launched app by simctl.)
SIMCTL_CHILD_DR_PIN_TODAY=1 xcrun simctl launch <device> com.shiguang.daysremember

# Open a specific tab on launch
xcrun simctl launch <device> com.shiguang.daysremember --tab calendar         # home | calendar | categories | notifications

# Dedicated test simulators only: replace the library with explicit fixtures
xcrun simctl launch <device> com.shiguang.daysremember --seed-sample-data --tab home
xcrun simctl launch <device> com.shiguang.daysremember --empty-library --show-onboarding

# Open a specific screen directly (bypasses the tab shell)
xcrun simctl launch <device> com.shiguang.daysremember --screen detail --day wedding
xcrun simctl launch <device> com.shiguang.daysremember --screen add
xcrun simctl launch <device> com.shiguang.daysremember --screen share --day japan
xcrun simctl launch <device> com.shiguang.daysremember --screen widgets
xcrun simctl launch <device> com.shiguang.daysremember --screen onboarding
```

`--day` accepts any sample id from `Models/SampleData.swift` (`wedding`, `baby`, `birthday`, `midautumn`, `japan`, `kaoyan`, `firstmet`, `work`, `dog`, `moved`).
