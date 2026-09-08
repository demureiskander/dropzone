# Alpha validation — 2026-09-08

Environment: macOS 26.5.2 (25F84), arm64, Xcode 26.6 (17F113), Swift 6.3.3. This document records observed results, not a claim that all MVP acceptance criteria are complete.

## Passed

- Debug and release builds, `.app` packaging, ad-hoc signature verification, Info.plist lint, native application launch.
- 20 XCTest cases: strict close threshold and toggle, responsive follow convergence, file-reference deduplication, equal filenames in different folders, safe removal/clear, missing originals, bookmark resolution after rename, directory references, intentional shake vs jitter/straight drags, gesture reset, direction hysteresis, proximity pause, screen bounds, smooth stepping, inertial acceleration/braking, continuous reversal and settling.
- The native accessibility tree exposes Settings, compact/grid shelf views, follow toggle, file content and file menu controls.
- After restarting the updated release build, an empty test TXT was imported through the macOS open-file event. Screenshots of both compact and expanded grid views confirm the system text-document icon rather than a white rectangle and the correct singular file-count label.
- The author confirmed the initial application runs, accepts a TXT file, displays expanded content and follows the pointer. Their screenshot exposed the menu-anchor and blank-text-thumbnail bugs addressed in this revision.
- Generated icon copied into the project and converted into an ICNS with transparency; private reference screenshots excluded from Git.

## Fixes after the first hands-on feedback

- The menu is anchored to an NSView occupying the actual ellipsis button; its position no longer assumes the hosting view's coordinate orientation.
- Document icons come from NSWorkspace. Quick Look thumbnails are requested only for images/movies, avoiding blank page previews for empty TXT files.
- Following uses continuous velocity with a critically damped spring and no speed cap, soft proximity braking and gradual acceleration after the existing pause delay. Actual interaction still fixes the target in place.
- Russian file-count labels use singular/few/many forms.

## Closing revision checks

- Release rebuilt and launched with simplified transparent icon (`sips` confirms alpha).
- ⌘, opened Settings through Computer Use. The handler matches hardware key code rather than layout-dependent characters; a physical multi-layout keyboard check remains pending.
- Behavior settings expose the enabled confirmation toggle and threshold 5.
- Six generated test TXT files produced the confirmation dialog when clicking ×. Cancel preserved all six references; confirming cleared the shelf. Their source contents remained intact.
- 20 XCTest cases passed, including >5 boundary, custom threshold, disabled confirmation, velocity continuity and >95% target convergence within 300 ms.

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

## Language and closer pause revision

21 XCTest cases pass, including no pause at 30 pt and pause at 15 pt. Release build and signature verification passed. Computer Use confirmed English on launch, the General → Language selector, and immediate Russian shelf/settings text after choosing Русский. Further UI actions encountered repeated external-state changes and ScreenCaptureKit failures; the last observed language was Russian. System-provided symbols, file icons and OS error descriptions may follow the macOS language.

## Shake and visibility revision

22 XCTest cases pass, including rejection of the old low-amplitude shake at 0.35 and acceptance of twice that amplitude. Release build, signature verification and diff whitespace checks passed. Visibility fades are implemented with a common-run-loop timer that is invalidated on reversal and completion; animation feel and rapid-toggle behavior still need hands-on verification.

## Release and Homebrew — 0.1.0

- Author-provided PNG converted to ICNS; installed bundle icon matches the source ICNS byte-for-byte.
- Official Apache-2.0 LICENSE and NOTICE included in the bundle; installed LICENSE matches the repository.
- DMG and ZIP published with SHA256SUMS in GitHub release v0.1.0 (alpha / prerelease).
- Homebrew 6.0.22 successfully tapped this repository, trusted the single cask, downloaded the release with SHA-256 verification and installed `/Applications/Dropzone.app`. `brew list --cask --versions` reports 0.1.0.
- Installed ad-hoc signature verification passed. Developer ID signing and Apple notarization remain unavailable; Intel is not included in this arm64 release.
- Cask token is `demureiskander-dropzone` to avoid the existing commercial product's token.

## Range selection — 0.1.1

25 XCTest cases pass: Shift anchor creation, inclusive ranges, reverse selection, range contraction, Command toggling and deleted/cleared anchor fallback. Release build and signature validation passed. Grid and list share the same native click handler.

## Menu bar and Dock fixes — 0.1.3

- The status item uses an `NSStatusBarButton` template image; the transparent drag target no longer draws a fixed-color symbol over it.
- Dock visibility updates both `NSApplication.ActivationPolicy` and the process presentation type on the main queue.
- With Show in Dock disabled, both the installed 0.1.2 process and the test 0.1.3 process reported activation policy `accessory` (`rawValue == 1`). Two copies were running during diagnosis; release testing must leave only the installed copy active.
- Debug tests (25), release build, ad-hoc signature validation, cask syntax and DMG checksum passed.

## Drag-out completion and immediate interaction — 0.1.4

- 28 XCTest cases pass, including fast pointer movement aimed at the shelf, movement away from it and small pointer jitter.
- A successful native dragging session removes the exact set of accessible exported references. A cancelled or rejected session reports an empty operation and keeps the shelf intact.
- Mouse-down fixes the shelf synchronously. Fast approach prediction stops follow motion before the pointer reaches the shelf, reducing the chance that the target moves away during a rapid grab.
- Cross-application drag-out still requires hands-on verification because unit tests cannot establish destination behavior in Finder and every third-party application.
