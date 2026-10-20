#!/bin/bash
# Runs scripts/ci.sh against stub Xcode tools in scratch copies of the repo and checks what a run
# leaves behind (the logs, coverage and result bundle, but not its DerivedData) and how it handles
# a UI test runner that never starts and tests that hang.
# Usage: bash scripts/ci-tests/ci.test.sh
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/bin"

# Each stub records nothing it doesn't need; xcodebuild fills the paths it is given. STUB_TESTS lists
# what each `xcodebuild test` does in turn: pass, runner (the UI test runner never starts), fail (a
# test fails), hang (a UI and a unit test go past their time allowance), runner+fail or hang+fail.
cat > "$scratch/bin/xcodebuild" <<'STUB'
#!/bin/bash
action="$1"
echo "$*" >> "$STUB_STATE/xcodebuild-calls"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -derivedDataPath) mkdir -p "$2/Build/Products"; touch "$2/Build/Products/app"; shift ;;
        -resultBundlePath) mkdir -p "$2"; touch "$2/Info.plist"; shift ;;
    esac
    shift
done
echo "stub xcodebuild $action"
[[ "$action" == test ]] || exit 0
count=$(( $(cat "$STUB_STATE/test-count" 2>/dev/null || echo 0) + 1 ))
echo "$count" > "$STUB_STATE/test-count"
runner='DaysRememberUITests-Runner (1) encountered an error (The test runner failed to initialize for UI testing. (Underlying Error: Timed out while loading Accessibility.))'
hung() { echo "Test Case '-[$1 $2]' exceeded execution time allowance of 5 minutes. The test may have hung."; }
hang() {
    hung DaysRememberUITests.SwiftUIEditorUITests testFailedPhotoSaveKeepsEditorDraft
    hung DaysRememberTests.LunarTests testBenchmark
    echo 'Restarting after unexpected exit, crash, or test timeout; summary will include totals from previous launches.'
}
case "$(echo "${STUB_TESTS:-pass}" | cut -d, -f"$count")" in
    runner) echo "$runner"; echo '** TEST FAILED **'; exit 65 ;;
    fail) printf 'Failing tests:\n\tLunarTests.testRoundTrip()\n** TEST FAILED **\n'; exit 65 ;;
    hang)
        hang
        printf 'Failing tests:\n\tLunarTests.testBenchmark()\n\tSwiftUIEditorUITests.testFailedPhotoSaveKeepsEditorDraft()\n'
        printf '\n** TEST FAILED **\n'; exit 65 ;;
    runner+fail) echo "$runner"; printf 'Failing tests:\n\tLunarTests.testRoundTrip()\n** TEST FAILED **\n'; exit 65 ;;
    hang+fail)
        hang
        printf 'Failing tests:\n\tLunarTests.testBenchmark()\n\tLunarTests.testRoundTrip()\n'
        printf '\tSwiftUIEditorUITests.testFailedPhotoSaveKeepsEditorDraft()\n\n** TEST FAILED **\n'; exit 65 ;;
esac
STUB
cat > "$scratch/bin/xcrun" <<'STUB'
#!/bin/bash
case "$1 $2" in
    "simctl create") echo "STUB-SIMULATOR" ;;
    "xccov view") echo "{}" ;;
    "xcresulttool merge")
        echo "$*" >> "$STUB_STATE/merges"
        while [[ $# -gt 0 ]]; do
            if [[ "$1" == --output-path ]]; then mkdir -p "$2"; touch "$2/Info.plist"; fi
            shift
        done ;;
esac
STUB
printf '#!/bin/bash\necho "stub $(basename "$0")"\n' > "$scratch/bin/xcodegen"
cp "$scratch/bin/xcodegen" "$scratch/bin/jq"
chmod +x "$scratch/bin/"*

failed=0
check() { if eval "$2"; then echo "ok - $1"; else echo "not ok - $1"; failed=1; fi; }

# Runs ci.sh with the given STUB_TESTS in a fresh copy; sets $run, $state and $status.
run_ci() {
    local case_dir="$scratch/$1"
    mkdir -p "$case_dir/repo/scripts" "$case_dir/state"
    cp "$repo/scripts/ci.sh" "$case_dir/repo/scripts/ci.sh"
    state="$case_dir/state"
    status=0
    PATH="$scratch/bin:$PATH" IOS_RUNTIME=stub-runtime STUB_STATE="$state" STUB_TESTS="$2" \
        bash "$case_dir/repo/scripts/ci.sh" > "$case_dir/ci.log" 2>&1 || status=$?
    run="$(echo "$case_dir"/repo/build/ci/run.*)"
}

run_ci pass pass
check "a passing run succeeds" '[[ $status == 0 ]]'
check "the run keeps its logs" '[[ -f "$run/tests.log" && -f "$run/release.log" && -f "$run/setup.log" ]]'
check "the run keeps coverage and results" '[[ -f "$run/coverage.json" && -d "$run/Tests.xcresult" ]]'
check "the run removes its DerivedData" '[[ ! -e "$run/DerivedData" ]]'
check "a failing test gets two more tries" 'grep -q -- "-retry-tests-on-failure -test-iterations 3" "$state/xcodebuild-calls"'

run_ci runner runner,pass
check "a UI runner that never starts gets one more run" '[[ $status == 0 && $(cat "$state/test-count") == 2 ]]'
check "that run is only the UI tests, without the manual widget test" \
    'tail -n +2 "$state/xcodebuild-calls" | grep "^test " | grep -q -- "-only-testing:DaysRememberUITests -skip-testing:DaysRememberUITests/WidgetHomeUITests"'
check "both runs' results are merged into Tests.xcresult" \
    '[[ $(wc -l < "$state/merges") -eq 1 && -d "$run/Tests.xcresult" && ! -e "$run/UITests.xcresult" && ! -e "$run/Earlier.xcresult" ]]'

run_ci fail fail
check "a failing test fails the run without another run" '[[ $status != 0 && $(cat "$state/test-count") == 1 ]]'

run_ci runner-and-fail runner+fail
check "a failing test beside a stuck runner still fails the run" '[[ $status != 0 && $(cat "$state/test-count") == 1 ]]'

run_ci runner-twice runner,runner
check "a runner that never starts twice fails the run" '[[ $status != 0 && $(cat "$state/test-count") == 2 ]]'
check "a failed UI test rerun's results are still merged into Tests.xcresult" \
    '[[ -s "$state/merges" && -d "$run/Tests.xcresult" && ! -e "$run/UITests.xcresult" ]]'

hung_only='-only-testing:DaysRememberTests/LunarTests/testBenchmark -only-testing:DaysRememberUITests/SwiftUIEditorUITests/testFailedPhotoSaveKeepsEditorDraft$'
run_ci hang hang,pass
check "tests that hang get one more run" '[[ $status == 0 && $(cat "$state/test-count") == 2 ]]'
check "that run is only the tests that hung, each in its own target" \
    'grep "^test " "$state/xcodebuild-calls" | tail -n 1 | grep -q -- "$hung_only"'
check "the hung tests' results are merged into Tests.xcresult" \
    '[[ $(wc -l < "$state/merges") -eq 1 && -d "$run/Tests.xcresult" && ! -e "$run/HungTests.xcresult" && ! -e "$run/Earlier.xcresult" ]]'

run_ci hang-and-fail hang+fail
check "a failing test beside hung tests still fails the run" '[[ $status != 0 && $(cat "$state/test-count") == 1 ]]'

run_ci hang-twice hang,hang
check "tests that hang twice fail the run" '[[ $status != 0 && $(cat "$state/test-count") == 2 ]]'
check "a failed rerun of hung tests is still merged into Tests.xcresult" \
    '[[ -s "$state/merges" && -d "$run/Tests.xcresult" && ! -e "$run/HungTests.xcresult" ]]'

run_ci runner-then-hang runner,hang,pass
check "tests that hang after the UI runner starts again get one more run" \
    '[[ $status == 0 && $(cat "$state/test-count") == 3 && $(wc -l < "$state/merges") -eq 2 ]]'
check "that run is only the tests that hung" 'grep "^test " "$state/xcodebuild-calls" | tail -n 1 | grep -q -- "$hung_only"'

exit "$failed"
