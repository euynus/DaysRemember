#!/bin/bash
# Runs scripts/ci.sh against stub Xcode tools in a scratch copy of the repo and checks what a run
# leaves behind: the logs, coverage and result bundle, but not its DerivedData.
# Usage: bash scripts/ci-tests/ci.test.sh
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/repo/scripts" "$scratch/bin"
cp "$repo/scripts/ci.sh" "$scratch/repo/scripts/ci.sh"

# Each stub records nothing it doesn't need; xcodebuild fills the paths it is given.
cat > "$scratch/bin/xcodebuild" <<'STUB'
#!/bin/bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        -derivedDataPath) mkdir -p "$2/Build/Products"; touch "$2/Build/Products/app"; shift ;;
        -resultBundlePath) mkdir -p "$2"; touch "$2/Info.plist"; shift ;;
    esac
    shift
done
echo "stub xcodebuild"
STUB
cat > "$scratch/bin/xcrun" <<'STUB'
#!/bin/bash
case "$1 $2" in
    "simctl create") echo "STUB-SIMULATOR" ;;
    "xccov view") echo "{}" ;;
esac
STUB
printf '#!/bin/bash\necho "stub $(basename "$0")"\n' > "$scratch/bin/xcodegen"
cp "$scratch/bin/xcodegen" "$scratch/bin/jq"
chmod +x "$scratch/bin/"*

PATH="$scratch/bin:$PATH" IOS_RUNTIME=stub-runtime bash "$scratch/repo/scripts/ci.sh" > "$scratch/ci.log" 2>&1 || {
    cat "$scratch/ci.log"; echo "FAIL: ci.sh exited with an error"; exit 1
}

run="$(echo "$scratch"/repo/build/ci/run.*)"
failed=0
check() { if eval "$2"; then echo "ok - $1"; else echo "not ok - $1"; failed=1; fi; }
check "the run keeps its logs" '[[ -f "$run/tests.log" && -f "$run/release.log" && -f "$run/setup.log" ]]'
check "the run keeps coverage and results" '[[ -f "$run/coverage.json" && -d "$run/Tests.xcresult" ]]'
check "the run removes its DerivedData" '[[ ! -e "$run/DerivedData" ]]'
exit "$failed"
