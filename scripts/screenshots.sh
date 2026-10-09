#!/bin/bash
# Captures the App Store screenshots (6.9-inch, 1320 x 2868) in Simplified Chinese,
# Traditional Chinese and English on a disposable simulator, with translated sample days
# and "today" pinned to 2026-04-23 (the calendar to a month with days in it).
# Output: docs/screenshots/<language>/NN-screen.jpg, without the alpha channel that
# App Store Connect rejects. Raw captures stay in build/screenshots.
set -euo pipefail

cd "$(dirname "$0")/.."

for command in xcodebuild xcrun xcodegen jq sips; do
    if ! command -v "$command" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$command" >&2
        exit 1
    fi
done

output_dir="$PWD/build/screenshots"
docs_dir="$PWD/docs/screenshots"
bundle_id=com.shiguang.daysremember
simulator_id=""

cleanup() {
    local status=$?
    trap - EXIT
    if [[ -n "$simulator_id" ]]; then
        xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true
        if ! xcrun simctl delete "$simulator_id"; then
            printf 'Could not delete screenshot simulator: %s\n' "$simulator_id" >&2
            status=1
        fi
    fi
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

xcodegen generate --quiet
xcodebuild build \
    -project DaysRemember.xcodeproj \
    -scheme DaysRemember \
    -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$output_dir/DerivedData" \
    -quiet

runtime="${IOS_RUNTIME:-$(xcrun simctl list runtimes --json | jq -er '
    [.runtimes[]
     | select(.isAvailable and (.identifier | startswith("com.apple.CoreSimulator.SimRuntime.iOS-")))]
    | sort_by(.version | split(".") | map(tonumber))
    | last.identifier // error("No available iOS simulator runtime")
')}"
device_type="${IOS_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max}"
simulator_id="$(xcrun simctl create "DaysRememberScreenshots" "$device_type" "$runtime")"
xcrun simctl boot "$simulator_id"
xcrun simctl bootstatus "$simulator_id" -b >/dev/null
xcrun simctl status_bar "$simulator_id" override --time 9:41 --dataNetwork wifi --wifiMode active \
    --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl install "$simulator_id" "$output_dir/DerivedData/Build/Products/Debug-iphonesimulator/时光.app"

capture() {
    local language=$1 locale=$2 today=$3 name=$4
    shift 4
    xcrun simctl terminate "$simulator_id" "$bundle_id" >/dev/null 2>&1 || true
    SIMCTL_CHILD_DR_PIN_TODAY="$today" xcrun simctl launch "$simulator_id" "$bundle_id" \
        -AppleLanguages "($language)" -AppleLocale "$locale" \
        --seed-sample-data --localized-samples "$@" >/dev/null
    # Long enough for the launch transition to finish.
    sleep "${SCREENSHOT_DELAY:-6}"
    xcrun simctl io "$simulator_id" screenshot "$output_dir/$language/$name.png" >/dev/null 2>&1
    sips -s format jpeg -s formatOptions 90 "$output_dir/$language/$name.png" \
        --out "$docs_dir/$language/$name.jpg" >/dev/null
}

for entry in zh-Hans:zh_CN zh-Hant:zh_TW en:en_US; do
    language=${entry%%:*}
    locale=${entry#*:}
    mkdir -p "$output_dir/$language" "$docs_dir/$language"
    # The first launch also stores the translated days that the --screen views read.
    capture "$language" "$locale" 1 01-home --tab home
    capture "$language" "$locale" 1 02-detail --screen detail --day wedding
    capture "$language" "$locale" 2026-07-08 03-calendar --tab calendar
    capture "$language" "$locale" 1 04-widgets --screen widgets --widget-size large
    capture "$language" "$locale" 1 05-share --screen share --day japan
    capture "$language" "$locale" 1 06-categories --tab categories
done

sips -g pixelWidth -g pixelHeight -g hasAlpha "$docs_dir/zh-Hans/01-home.jpg" | tail -3
printf 'Screenshots: %s\n' "$docs_dir"
