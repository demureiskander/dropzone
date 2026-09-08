First public alpha of the free, open-source Dropzone file shelf, licensed under Apache 2.0.

### Install with Homebrew

```sh
brew tap demureiskander/dropzone https://github.com/demureiskander/dropzone.git
brew trust --cask demureiskander/dropzone/demureiskander-dropzone
brew install --cask demureiskander/dropzone/demureiskander-dropzone
```

The `trust` command applies to Homebrew 6 and newer. On older Homebrew versions, skip that line.

### Downloads

- **DMG:** open it and drag Dropzone into Applications.
- **ZIP:** extract and move Dropzone.app into Applications.
- **SHA256SUMS.txt:** checksums of the DMG and ZIP.

### Included

- File/folder shelf with compact, grid and list views, Quick Look and copy-only drag-out.
- Shake activation, notch drop target, configurable shortcut, pointer following and animated visibility.
- English by default, optional Russian, close confirmation, donation and GitHub links.
- Author-provided blue app icon embedded in the application bundle.

### Requirements and limits

Apple Silicon (arm64), macOS 13 or newer. Tested on macOS 26.5.2 arm64; older macOS versions remain unverified. The build is ad-hoc signed, not Developer ID signed or notarized. macOS may block first launch; review the app through System Settings → Privacy & Security. No security settings are modified by the installer.

The shelf stores temporary references; quitting clears its contents, leaving originals intact. File promises, cloud sharing and text snippets are not included. This project is independent of Aptonic's Dropzone and Dropover.

22 automated tests pass. Full cross-application drag-and-drop and multi-display coverage remains in progress.
