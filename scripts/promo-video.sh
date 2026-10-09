#!/bin/bash
# Renders the promotional video: 9:16 (1080 x 1920), 30 fps, H.264, silent, with Simplified Chinese
# captions, from the App Store screenshots in docs/screenshots/zh-Hans and the app's cover
# illustrations (scripts/promo/render.swift). Run scripts/screenshots.sh first when the app changes.
# Output: build/promo/days-remember-promo-zh-Hans.mp4, and contact-sheet.png with one frame a second.
set -euo pipefail

cd "$(dirname "$0")/.."

output_dir="$PWD/build/promo"
mkdir -p "$output_dir"
# The AVAssetWriter calls it uses are deprecated in the macOS 27 SDK, but they are the ones Xcode 26 has.
swiftc -O -swift-version 5 -suppress-warnings scripts/promo/render.swift -o "$output_dir/render"
"$output_dir/render" "$PWD" "$output_dir/days-remember-promo-zh-Hans.mp4" --sheet "$output_dir/contact-sheet.png"
