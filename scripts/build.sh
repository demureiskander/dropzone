#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-debug}"
if [[ "$configuration" != debug && "$configuration" != release ]]; then
    echo "Usage: scripts/build.sh [debug|release]" >&2
    exit 1
fi
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
swift build --configuration "$configuration"
bin_path="$(swift build --configuration "$configuration" --show-bin-path)"
app_path="$PWD/build/Dropzone.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_path/Dropzone" "$app_path/Contents/MacOS/Dropzone"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
if [[ -f Resources/AppIcon.icns ]]; then cp Resources/AppIcon.icns "$app_path/Contents/Resources/AppIcon.icns"; fi
cp LICENSE "$app_path/Contents/Resources/LICENSE"
cp NOTICE "$app_path/Contents/Resources/NOTICE"
codesign --force --sign - "$app_path"
echo "$app_path"
