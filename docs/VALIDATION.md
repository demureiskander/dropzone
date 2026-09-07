# Alpha validation — 2026-09-08

Environment: macOS 26.5.2 (25F84), arm64, Xcode 26.6 (17F113), Swift 6.3.3. This document records observed results, not a claim that all MVP acceptance criteria are complete.

## Passed

- Debug and release builds, `.app` packaging, ad-hoc signature verification, Info.plist lint, native application launch.
- 17 XCTest cases: file-reference deduplication, equal filenames in different folders, safe removal/clear, missing originals, bookmark resolution after rename, directory references, intentional shake vs jitter/straight drags, gesture reset, direction hysteresis, proximity pause, screen bounds, smooth stepping, inertial acceleration/braking, continuous reversal and settling.
- The native accessibility tree exposes Settings, compact/grid shelf views, follow toggle, file content and file menu controls.
- After restarting the updated release build, an empty test TXT was imported through the macOS open-file event. Screenshots of both compact and expanded grid views confirm the system text-document icon rather than a white rectangle and the correct singular file-count label.
- The author confirmed the initial application runs, accepts a TXT file, displays expanded content and follows the pointer. Their screenshot exposed the menu-anchor and blank-text-thumbnail bugs addressed in this revision.
- Generated icon copied into the project and converted into an ICNS with transparency; private reference screenshots excluded from Git.

## Fixes after the first hands-on feedback

- The menu is anchored to an NSView occupying the actual ellipsis button; its position no longer assumes the hosting view's coordinate orientation.
- Document icons come from NSWorkspace. Quick Look thumbnails are requested only for images/movies, avoiding blank page previews for empty TXT files.
- Following uses continuous velocity with capped speed, soft proximity braking and gradual acceleration after the existing pause delay. Actual interaction still fixes the target in place.
- Russian file-count labels use singular/few/many forms.

## Remaining manual coverage

- Recheck the exact visual menu position and icon appearance in the refreshed build; re-tune motion by feel if needed.
- Finder-to-shelf-to-Finder copies of multiple files, cancellation, rejected destinations and external volumes, including checksum comparison.
- Notch proximity/drop feedback on physical hardware; no-notch display behavior and hot-plug/sleep/wake.
- Full-screen applications, multiple displays/scales and Stage Manager.
- Keyboard remapping conflicts, Launch at Login approval and minimum macOS/Intel compatibility.
- VoiceOver, Reduce Motion/Transparency and sustained idle CPU/memory measurements; the numeric MVP performance budgets are not yet measured.

Computer Use initially encountered ScreenCaptureKit error -3811; after restarting the app, screenshots of compact and grid views succeeded. Capturing the open NSMenu remained unavailable, so exact menu-placement visual verification is still pending despite the native anchor fix. Unit tests do not establish cross-application drag-and-drop compatibility.

## Commands

```sh
swift test
scripts/build.sh release
codesign --verify --deep --strict build/Dropzone.app
plutil -lint Resources/Info.plist
git diff --check
```
