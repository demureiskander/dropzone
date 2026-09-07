# App icon

## Simplified revision — 2026-09-08

The current `AppIcon.png` and `AppIcon.icns` replace the initial glossy version at the author's request. Edited with built-in ImageGen, with a second pass to produce genuine alpha transparency (verified with `sips`). The icon retains the tray/file mark with matte surfaces and shallow depth.

Style edit prompt:

> Use case: style-transfer. Asset type: Dropzone native macOS application icon. Input image is the edit target. Simplify this existing icon substantially while preserving its recognizable centered receiving tray and single white file tile with blue down arrow, dark navy rounded-square base, and blue accent palette. Make it restrained, matte, clean, with shallow subtle dimensionality and very soft short shadows. Remove ALL neon glow, luminous edges, bright rim, glass gloss, chrome reflections, specular hotspots, inflated/puffy bevels, and excessive depth. Use a plain dark navy squircle base, calm medium blue tray, off-white flat file tile, crisp simple blue downward arrow. Front-facing, clear silhouette at small sizes, no text or additional elements. Genuinely transparent background outside the squircle with even margins. One square 1024x1024 icon only.

Transparency correction prompt:

> Use case: background-extraction. Edit target: the simplified Dropzone icon in the input image. Preserve the navy rounded-square icon and all its contents exactly. Remove the checkerboard background outside the rounded square completely and replace it with genuine transparent alpha pixels. The checkerboard must not be painted into the result. Do not change the matte style, colors, composition, or geometry of the icon. Output one PNG with real transparency outside the squircle.

## Initial version (history)

`AppIcon.png` was generated for this project on 2026-09-08 using the built-in ImageGen tool. `AppIcon.icns` is its macOS icon bundle, created using `scripts/icon.sh`. The original has a transparent background. No Dropover screenshot is embedded in the asset.

Generation prompt:

> Use case: stylized-concept. Asset type: native macOS app icon for Dropzone, a temporary drag and drop file shelf. Generate one square 1024x1024 app icon on a genuinely transparent background outside the icon. Center a dark midnight navy rounded-square macOS squircle tile with a beveled electric blue rim and subtle glass/ceramic depth. Main symbol: an original minimal open-top receiving tray in luminous cobalt blue with one pearly white rounded rectangular file tile hovering just above it, a small downward notch/arrow embossed on the white tile, conveying drop into shelf. Elegant precise premium 3D rendering, restrained highlights, depth, strong silhouette legible at 32px, front-facing slight top view of tray, soft studio lighting. Tile occupies about 84 percent of canvas with even transparent margins. No text, no letters, no logo from another application, no document text lines, no scene, no mockup, no multiple icons. Save as transparent PNG.

The tool returned a 1254×1254 PNG; `icon.sh` resamples it to standard macOS icon sizes. The source and bundled icon are included under the project's MIT license to the extent applicable.
