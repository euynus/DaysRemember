#!/bin/bash
# Archives 时光 for the App Store, exports the signed IPA and checks it before anything is uploaded:
# the push and iCloud environments are production, the app and widget carry the same version and
# build number, the App Group is on both, and the marketing icon has no alpha channel.
#
#   bash scripts/archive.sh              # archive and export build/archive/export/时光.ipa
#   bash scripts/archive.sh --upload     # the same, then upload to App Store Connect
#   bash scripts/archive.sh --unsigned   # archive without signing, to check the device build (CI)
#
# Signing needs the Team ID (DEVELOPMENT_TEAM in project.yml, or TEAM_ID=…) and an Xcode account
# that can manage that team's certificates and profiles. The build number defaults to the number of
# commits on HEAD, so each upload from a new commit is higher; set BUILD_NUMBER=… to repeat one.
set -euo pipefail

cd "$(dirname "$0")/.."

mode="export"
case "${1:-}" in
    "") ;;
    --upload) mode="upload" ;;
    --unsigned) mode="unsigned" ;;
    *) printf 'Usage: %s [--upload | --unsigned]\n' "$0" >&2; exit 64 ;;
esac

fail() { printf 'archive: %s\n' "$1" >&2; exit 1; }
setting() { sed -nE "s/^[[:space:]]*$1: \"?([^\"]*)\"?[[:space:]]*\$/\1/p" project.yml | head -1; }

team="${TEAM_ID:-$(setting DEVELOPMENT_TEAM)}"
version="$(setting MARKETING_VERSION)"
build="${BUILD_NUMBER:-$(git rev-list --count HEAD)}"
[[ "$build" =~ ^[0-9]+$ ]] || fail "build number '$build' is not a whole number"

if [[ "$mode" != "unsigned" ]]; then
    [[ "$team" =~ ^[A-Z0-9]{10}$ ]] || fail "set DEVELOPMENT_TEAM in project.yml, or TEAM_ID=…, to the 10-character Team ID"
    # The build number comes from the commit count, which says nothing about uncommitted changes.
    [[ -z "$(git status --porcelain)" || -n "${ALLOW_DIRTY:-}" ]] || fail "commit or stash changes first (ALLOW_DIRTY=1 to override)"
    # App Store Connect refuses builds from beta Xcode.
    [[ "$(xcode-select -p)" != *[Bb]eta* ]] || fail "select a release Xcode, not $(xcode-select -p)"
fi

output="build/archive"
archive="$output/DaysRemember.xcarchive"
rm -rf "$output"
mkdir -p "$output"
printf 'Archiving %s (%s), %s\n' "$version" "$build" "$mode" | tee "$output/archive.log"

xcodegen generate --quiet

signing=(DEVELOPMENT_TEAM="$team" -allowProvisioningUpdates)
if [[ "$mode" == "unsigned" ]]; then
    signing=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="")
fi
xcodebuild archive \
    -project DaysRemember.xcodeproj \
    -scheme DaysRemember \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$archive" \
    CURRENT_PROJECT_VERSION="$build" \
    "${signing[@]}" \
    2>&1 | tee -a "$output/archive.log" | grep -E '^(\*\*|error:)' || true
[[ -d "$archive" ]] || fail "archive failed; see $output/archive.log"

# Checks that hold for any build of the app found at $1.
check_bundle() {
    local app="$1" widget="$1/PlugIns/DaysRememberWidget.appex"
    [[ -d "$widget" ]] || fail "no widget in $app"
    for key in CFBundleShortVersionString CFBundleVersion; do
        local app_value widget_value
        app_value="$(/usr/libexec/PlistBuddy -c "Print :$key" "$app/Info.plist")"
        widget_value="$(/usr/libexec/PlistBuddy -c "Print :$key" "$widget/Info.plist")"
        [[ "$app_value" == "$widget_value" ]] || fail "$key is $app_value in the app but $widget_value in the widget"
    done
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Info.plist")" == "$build" ]] || fail "build number isn't $build"
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :ITSAppUsesNonExemptEncryption' "$app/Info.plist")" == "false" ]] \
        || fail "ITSAppUsesNonExemptEncryption isn't false"
}

# The marketing icon goes to the App Store as is; it must be opaque.
sips -g hasAlpha DaysRemember/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png | grep -q 'hasAlpha: no' \
    || fail "AppIcon.png has an alpha channel"

archived_app="$(find "$archive/Products/Applications" -maxdepth 1 -name '*.app' | head -1)"
check_bundle "$archived_app"

if [[ "$mode" == "unsigned" ]]; then
    printf 'Unsigned archive checks passed: %s\n' "$archive"
    exit 0
fi

options="$output/ExportOptions.plist"
cp scripts/ExportOptions.plist "$options"
plutil -replace teamID -string "$team" "$options"
xcodebuild -exportArchive \
    -archivePath "$archive" \
    -exportOptionsPlist "$options" \
    -exportPath "$output/export" \
    -allowProvisioningUpdates \
    2>&1 | tee "$output/export.log" | grep -E '^(\*\*|error:)' || true
ipa="$(find "$output/export" -maxdepth 1 -name '*.ipa' | head -1)"
[[ -n "$ipa" ]] || fail "export failed; see $output/export.log"

# Distribution signing turns the source's development entitlements into production ones.
payload="$output/payload"
unzip -q "$ipa" -d "$payload"
app="$(find "$payload/Payload" -maxdepth 1 -name '*.app' | head -1)"
check_bundle "$app"
entitlement() { /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || true; }
codesign -d --entitlements - --xml "$app" > "$output/app.entitlements" 2>/dev/null
codesign -d --entitlements - --xml "$app/PlugIns/DaysRememberWidget.appex" > "$output/widget.entitlements" 2>/dev/null
[[ "$(entitlement "$output/app.entitlements" aps-environment)" == "production" ]] || fail "aps-environment isn't production"
[[ "$(entitlement "$output/app.entitlements" com.apple.developer.icloud-container-environment)" == "Production" ]] \
    || fail "the iCloud container environment isn't Production"
for file in app widget; do
    entitlement "$output/$file.entitlements" com.apple.security.application-groups | grep -q group.com.shiguang.daysremember \
        || fail "the $file is missing the App Group"
done
printf 'Exported and checked: %s\n' "$ipa"

if [[ "$mode" == "upload" ]]; then
    plutil -replace destination -string upload "$options"
    xcodebuild -exportArchive \
        -archivePath "$archive" \
        -exportOptionsPlist "$options" \
        -exportPath "$output/upload" \
        -allowProvisioningUpdates \
        2>&1 | tee "$output/upload.log" | grep -E '^(\*\*|error:)' || true
    grep -q 'EXPORT SUCCEEDED' "$output/upload.log" || fail "upload failed; see $output/upload.log"
    printf 'Uploaded %s (%s) to App Store Connect\n' "$version" "$build"
fi
