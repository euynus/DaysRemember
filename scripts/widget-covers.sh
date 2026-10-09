#!/usr/bin/env bash
# Regenerates the widget's cover catalog from the app's covers. Widgets decode covers at
# no more than 720 px (`DayWidgetCard` → `PhotoTile.maximumPixelSize`), so the full-size
# artwork would only add weight to the extension. Run after adding or changing a cover.
set -euo pipefail

cd "$(dirname "$0")/.."
source=DaysRemember/Resources/Assets.xcassets
target=DaysRememberWidget/Assets.xcassets

mkdir -p "$target"
find "$target" -name '*.imageset' -prune -exec rm -r {} +
printf '{\n  "info" : { "author" : "xcode", "version" : 1 }\n}\n' > "$target/Contents.json"

for imageset in "$source"/Cover*.imageset; do
  name=$(basename "$imageset")
  mkdir "$target/$name"
  sips -Z 720 -s format jpeg -s formatOptions 90 "$imageset/cover.png" \
    --out "$target/$name/cover.jpg" > /dev/null
  printf '{\n  "images" : [{ "filename" : "cover.jpg", "idiom" : "universal" }],\n  "info" : { "author" : "xcode", "version" : 1 }\n}\n' \
    > "$target/$name/Contents.json"
done

echo "Wrote $(find "$target" -name '*.imageset' | wc -l | tr -d ' ') covers to $target"
