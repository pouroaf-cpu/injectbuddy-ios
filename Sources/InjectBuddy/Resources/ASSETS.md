# Assets

- **AppIcon.appiconset** — single 1024×1024 universal iOS icon slot, intentionally **empty** so the
  project builds without art. Before submission, drop a `1024x1024` PNG (no alpha/transparency) into
  `Assets.xcassets/AppIcon.appiconset/`, then add its `"filename"` to that set's `Contents.json` image
  entry (or just drag it onto the AppIcon well in Xcode). App Store requires the 1024 icon.
- **AccentColor.colorset** — brand teal `#0FBCAD` (sRGB), light + dark. Wired via
  `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor` in `project.yml`. Matches `Theme.accent`.
