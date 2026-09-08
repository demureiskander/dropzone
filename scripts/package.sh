#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/build.sh release
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
architecture=$(uname -m)
output="$PWD/build/releases"
mkdir -p "$output"
stem="Dropzone-${version}-macOS-${architecture}"
staging=$(mktemp -d "$PWD/build/package.XXXXXX")
trap 'rm -rf "$staging"' EXIT
ditto build/Dropzone.app "$staging/Dropzone.app"
ln -s /Applications "$staging/Applications"
ditto -c -k --sequesterRsrc --keepParent build/Dropzone.app "$output/$stem.zip"
hdiutil create -volname Dropzone -srcfolder "$staging" -ov -format UDZO "$output/$stem.dmg" >/dev/null
(cd "$output" && shasum -a 256 "$stem.zip" "$stem.dmg" > SHA256SUMS.txt)
echo "$output"
