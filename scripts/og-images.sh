#!/bin/bash
# Renders the product pages' 1200 x 630 share images (og:image, twitter:image) from
# scripts/og-image.html and the App Store screenshots, with headless Chrome in a throwaway
# profile. Run after scripts/screenshots.sh. Output: docs/assets/og/<language>.jpg.
set -euo pipefail

cd "$(dirname "$0")/.."

chrome="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
if [[ ! -x "$chrome" ]]; then
    printf 'Google Chrome not found; set CHROME to its binary\n' >&2
    exit 1
fi

profile="$(mktemp -d)"
trap 'rm -rf "$profile"' EXIT
mkdir -p build/og docs/assets/og

for language in zh-Hans zh-Hant en; do
    "$chrome" --headless=new --disable-gpu --no-first-run --no-default-browser-check \
        --user-data-dir="$profile" --hide-scrollbars --force-device-scale-factor=1 \
        --window-size=1200,630 --virtual-time-budget=3000 \
        --screenshot="$PWD/build/og/$language.png" \
        "file://$PWD/scripts/og-image.html?lang=$language" >/dev/null 2>&1
    sips -s format jpeg -s formatOptions 85 "build/og/$language.png" --out "docs/assets/og/$language.jpg" >/dev/null
done

sips -g pixelWidth -g pixelHeight docs/assets/og/*.jpg | grep -E 'pixel'
