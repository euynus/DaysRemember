#!/bin/bash
# Writes the product pages' WebP copies of the App Store screenshots into docs/assets/screens/:
# 900 px wide, enough for the hero phone (19rem) on a 3x screen, at a fraction of the JPEGs' size.
# The JPEGs in docs/screenshots stay for App Store Connect, the share images and the promo video.
# Run after scripts/screenshots.sh. Needs cwebp (brew install webp).
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v cwebp >/dev/null; then
    printf 'cwebp not found; brew install webp\n' >&2
    exit 1
fi

for source in docs/screenshots/*/*.jpg; do
    language="$(basename "$(dirname "$source")")"
    name="$(basename "$source" .jpg)"
    mkdir -p "docs/assets/screens/$language"
    cwebp -quiet -q 80 -resize 900 0 -metadata none "$source" -o "docs/assets/screens/$language/$name.webp"
done

du -ch docs/screenshots/*/*.jpg | tail -1 | sed 's/total/JPEG/'
du -ch docs/assets/screens/*/*.webp | tail -1 | sed 's/total/WebP/'
