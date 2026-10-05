#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

for command in xcodebuild xcrun xcodegen jq; do
    if ! command -v "$command" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$command" >&2
        exit 1
    fi
done

mkdir -p build/ci
output_dir="$(mktemp -d "$PWD/build/ci/run.XXXXXX")"
simulator_id=""

cleanup() {
    local status=$?
    trap - EXIT
    if [[ -n "$simulator_id" ]]; then
        xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true
        if ! xcrun simctl delete "$simulator_id"; then
            printf 'Could not delete CI simulator: %s\n' "$simulator_id" >&2
            status=1
        fi
    fi
    printf 'CI artifacts: %s\n' "$output_dir"
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

{
    xcodebuild -version
    xcodegen --version
    xcodegen generate
} 2>&1 | tee "$output_dir/setup.log"

# Keep assignments outside logging pipelines so the EXIT trap owns the ID.
runtime="${IOS_RUNTIME:-$(xcrun simctl list runtimes --json | jq -er '
    [.runtimes[]
     | select(.isAvailable and (.identifier | startswith("com.apple.CoreSimulator.SimRuntime.iOS-")))]
    | sort_by(.version | split(".") | map(tonumber))
    | last.identifier // error("No available iOS simulator runtime")
')}"
device_type="${IOS_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17}"
printf 'Runtime: %s\nDevice type: %s\n' "$runtime" "$device_type" | tee -a "$output_dir/setup.log"
simulator_id="$(xcrun simctl create "DaysRememberCI-$(basename "$output_dir")" "$device_type" "$runtime")"
printf 'CI simulator: %s\n' "$simulator_id" | tee -a "$output_dir/setup.log"
xcrun simctl boot "$simulator_id" 2>&1 | tee -a "$output_dir/setup.log"
xcrun simctl bootstatus "$simulator_id" -b 2>&1 | tee -a "$output_dir/setup.log"

xcodebuild test \
    -project DaysRemember.xcodeproj \
    -scheme DaysRememberCI \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    -derivedDataPath "$output_dir/DerivedData" \
    -resultBundlePath "$output_dir/Tests.xcresult" \
    -parallel-testing-enabled NO \
    -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 300 \
    -maximum-test-execution-time-allowance 300 \
    2>&1 | tee "$output_dir/tests.log"

xcrun xccov view --report --json "$output_dir/Tests.xcresult" > "$output_dir/coverage.json"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    jq -r '"### Coverage\n", (.targets[] | "- \(.name): \((.lineCoverage * 10000 | round) / 100)% (\(.coveredLines)/\(.executableLines) lines)")' \
        "$output_dir/coverage.json" >> "$GITHUB_STEP_SUMMARY"
fi

xcodebuild build \
    -project DaysRemember.xcodeproj \
    -scheme DaysRemember \
    -configuration Release \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$output_dir/DerivedData" \
    2>&1 | tee "$output_dir/release.log"
