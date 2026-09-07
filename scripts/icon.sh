#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/AppIcon.iconset
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Resources/AppIcon.png --out "build/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" Resources/AppIcon.png --out "build/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
