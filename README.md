# 时光 · Days Remember

A warm, emotional Chinese-language anniversary & countdown iOS app — SwiftUI, iOS 17+. Implementation of the Anthropic Design handoff bundle in `_design/days-remember/`.

## Build

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate `DaysRemember.xcodeproj` from `project.yml`.

```sh
brew install xcodegen
xcodegen generate
open DaysRemember.xcodeproj
```

Then run on the iPhone 15 simulator (iOS 17.5+).

## Fonts (optional)

The app falls back to **Songti SC** (serif) and **PingFang SC** (sans), both bundled with iOS, so it will render correctly without any extra setup. For pixel-faithful match with the design, drop the following TTFs into `DaysRemember/Resources/Fonts/` and add them to `UIAppFonts` in `Info.plist`:

- `NotoSerifSC-Regular.ttf`, `NotoSerifSC-Medium.ttf`, `NotoSerifSC-SemiBold.ttf`
- `NotoSansSC-Regular.ttf`, `NotoSansSC-Medium.ttf`, `NotoSansSC-SemiBold.ttf`

`Theme.serif()` / `Theme.sans()` already prefer Noto when present and degrade silently when not.

## Layout

See `/Users/suny/.claude/plans/fetch-this-design-file-optimized-lagoon.md` (the approved plan) for the full file map and design-token correspondence to the prototype CSS.

## Comparing against the design

Open the prototype at `_design/days-remember/project/Days Remember.html` in any browser to see the source artboards side-by-side with the running app.

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
xcrun simctl launch <device> com.shiguang.daysremember --screen onboarding --page 2
```

`--day` accepts any sample id from `Models/SampleData.swift` (`wedding`, `baby`, `birthday`, `midautumn`, `japan`, `kaoyan`, `firstmet`, `work`, `dog`, `moved`).
