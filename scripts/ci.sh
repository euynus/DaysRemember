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
    # The logs, coverage and result bundle are kept; the build products aren't needed after the run.
    rm -rf "$output_dir/DerivedData"
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

# A test that fails is run up to twice more, so a UI interaction that misses once (the system
# document picker is another process) doesn't fail the run; one that fails all three times does.
run_tests() {
    local bundle="$1"
    shift
    xcodebuild test \
        -project DaysRemember.xcodeproj \
        -scheme DaysRememberCI \
        -destination "platform=iOS Simulator,id=$simulator_id" \
        -derivedDataPath "$output_dir/DerivedData" \
        -resultBundlePath "$bundle" \
        -parallel-testing-enabled NO \
        -test-timeouts-enabled YES \
        -default-test-execution-time-allowance 300 \
        -maximum-test-execution-time-allowance 300 \
        -retry-tests-on-failure \
        -test-iterations 3 \
        "$@" \
        2>&1 | tee -a "$output_dir/tests.log"
}

if ! run_tests "$output_dir/Tests.xcresult"; then
    # GitHub's macOS runners sometimes can't start the UI test runner ("Timed out while loading
    # Accessibility"), and then no UI test runs at all. When that is the only failure, run the UI
    # tests once more and merge both result bundles; any failing test still fails the run.
    if grep -q 'failed to initialize for UI testing' "$output_dir/tests.log" \
        && ! grep -q '^Failing tests:' "$output_dir/tests.log"; then
        printf '\nThe UI test runner did not start; running the UI tests again.\n' | tee -a "$output_dir/tests.log"
        # -only-testing can override the scheme's skip list, so name its manual widget test again.
        run_tests "$output_dir/UITests.xcresult" -only-testing:DaysRememberUITests \
            -skip-testing:DaysRememberUITests/WidgetHomeUITests
        mv "$output_dir/Tests.xcresult" "$output_dir/FirstRun.xcresult"
        xcrun xcresulttool merge "$output_dir/FirstRun.xcresult" "$output_dir/UITests.xcresult" \
            --output-path "$output_dir/Tests.xcresult"
        rm -rf "$output_dir/FirstRun.xcresult" "$output_dir/UITests.xcresult"
    else
        exit 1
    fi
fi

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
