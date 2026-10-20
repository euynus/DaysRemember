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
    # Where this run's output starts in tests.log, for latest_run.
    touch "$output_dir/tests.log"
    log_start=$(( $(wc -l < "$output_dir/tests.log") + 1 ))
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

# The output of the latest run_tests. Checks read all of it: a reader that stops early would fail
# the pipeline with SIGPIPE.
latest_run() {
    tail -n "+$log_start" "$output_dir/tests.log"
}

# Whether the UI test runner never started in the latest run and no test failed.
runner_did_not_start() {
    latest_run | awk '
        /failed to initialize for UI testing/ { runner = 1 }
        /^Failing tests:/ { failing = 1 }
        END { exit !(runner && !failing) }'
}

# Prints Target/Class/method for each failing test of the latest run when every one of them went
# past its execution time allowance, and nothing otherwise. Only the hang's line names the target.
hung_tests() {
    latest_run | awk '
        /exceeded execution time allowance/ && match($0, /-\[[A-Za-z0-9_]+\.[A-Za-z0-9_]+ [A-Za-z0-9_]+\]/) {
            split(substr($0, RSTART + 2, RLENGTH - 3), name, /[. ]/)
            hung[name[2] "/" name[3]] = name[1] "/" name[2] "/" name[3]
        }
        /^Failing tests:$/ { listing = 1; next }
        listing && /^\t/ { sub(/^\t/, ""); sub(/\(\)$/, ""); sub(/\./, "/"); failing[++count] = $0; next }
        { listing = 0 }
        END {
            for (i = 1; i <= count; i++) if (!(failing[i] in hung)) exit
            for (i = 1; i <= count; i++) print hung[failing[i]]
        }'
}

# Merges the result bundle of a further run into Tests.xcresult.
merge_results() {
    mv "$output_dir/Tests.xcresult" "$output_dir/Earlier.xcresult"
    xcrun xcresulttool merge "$output_dir/Earlier.xcresult" "$1" --output-path "$output_dir/Tests.xcresult"
    rm -rf "$output_dir/Earlier.xcresult" "$1"
}

tests_passed=true
run_tests "$output_dir/Tests.xcresult" || tests_passed=false

# GitHub's macOS runners sometimes can't start the UI test runner ("Timed out while loading
# Accessibility"), and then no UI test runs at all. When that is the only failure, run the UI
# tests once more and merge both result bundles; any failing test still fails the run.
if ! $tests_passed && runner_did_not_start; then
    printf '\nThe UI test runner did not start; running the UI tests again.\n' | tee -a "$output_dir/tests.log"
    tests_passed=true
    # -only-testing can override the scheme's skip list, so name its manual widget test again.
    run_tests "$output_dir/UITests.xcresult" -only-testing:DaysRememberUITests \
        -skip-testing:DaysRememberUITests/WidgetHomeUITests || tests_passed=false
    merge_results "$output_dir/UITests.xcresult"
fi

# A UI test sometimes hangs in XCTest rather than in the app: it waits a minute at every step for
# animations that never report complete ("App animations complete notification not received"), or
# stalls launching the app, until the test goes past its time allowance. The runner then restarts
# and moves on without retrying it, so when only such tests failed, run them once more and merge
# the results; one that hangs again, or any other failing test, still fails the run.
if ! $tests_passed; then
    hung="$(hung_tests)"
    [[ -n "$hung" ]] || exit 1
    printf '\nOnly tests that hung failed; running them again:\n%s\n' "$hung" | tee -a "$output_dir/tests.log"
    tests_passed=true
    only_testing=()
    for name in $hung; do only_testing+=("-only-testing:$name"); done
    run_tests "$output_dir/HungTests.xcresult" "${only_testing[@]}" || tests_passed=false
    merge_results "$output_dir/HungTests.xcresult"
    $tests_passed || exit 1
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
