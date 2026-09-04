# Approved PulseBar icon — GLASS

The user selected the four frosted-blue glass modules on 2026-09-04.

- `approved-glass-reference.png` is an exact copy of the user-attached image,
  including the presentation text. SHA-256:
  `d2bc2b54e62889d9e2abcc3a76e9724aea6692ddfe7af8dee896e14f3dfe453b`.
- Keep this reference unchanged. Production exports must remove the presentation
  text and retain the approved geometry, colors, texture and raised top-right tile.
- The initial built-in image-generation extraction attempts produced opaque
  checkerboard pixels (`sips` reported `hasAlpha: no`), not real transparency.
  Those outputs were rejected and are not app resources or GitHub assets.
- Production export was subsequently approved explicitly: crop the original with
  local image tools, do not regenerate or redraw the four glass modules.
- Before adoption: local rollback tag `codex/pre-glass-icon-20260904` at `ca97b74`.
  The working Xcode project, Info.plist and Package.swift were also copied to
  `运行版/GlassIcon-before-ELcZjn/`, preserving unrelated local experiments.

The reported missing menu-bar item is a separate investigation. The tester's
main window opens on macOS 26; no region-specific cause or overflow cause has
been established. Do not present this icon approval as a fix for that report.

## Production export and integration

- `PulseBar-Glass-1024.png`: genuine RGBA master. The lower presentation text is
  excluded; the warm exterior background is flood-masked from the image edges.
  A two-pixel alpha defringe removes the light presentation-background halo.
  The navy tile, raised top-right module, colors and glass textures are retained.
- `../../Resources/PulseBar.icns`: standard macOS representations from 16 px to
  1024 px. Xcode copies it into the app and `CFBundleIconFile` identifies it.
- The native dashboard header uses the system-cached application icon instead
  of loading the large reference image each update. The menu-bar metric label
  and the recent menu-bar lifecycle fix are not changed.
- Plain `swift run` is not an app bundle and does not install the Finder icon;
  verify the Xcode-built `.app`, not the command-line executable.

Reproduce with Python 3 + Pillow, from the PulseBar directory (output is a build
directory, not the source reference):

```sh
python3 Tools/export_glass_icon.py Design/ApprovedIcon/approved-glass-reference.png /tmp/pulsebar-icon-export
iconutil -c icns /tmp/pulsebar-icon-export/PulseBar.iconset -o /tmp/pulsebar-icon-export/PulseBar.icns
```

The exporter validates the exact source SHA-256, dimensions and transparent
corners, so a different source image is rejected. No image-generation service is
used for this export. Keep both the untouched approved reference and the script.

Before this integration: local tag `codex/pre-glass-icon-integration-20260904`
at `b849d492a9fc368a8c0aac38b8d1f1105f45fbff`; GitHub branch
`codex/memory-optimization-20260904` at the tree-equivalent
`56bf9d429a5d4d8e5fa0ada67a254bac1247155b`.
The memory-only runnable app remains at `运行版/MemoryRound1-20260904/PulseBar.app`.
The original pre-memory app remains at `运行版/MenuBarFix-20260904/PulseBar.app`.
Quit the current app before opening either rollback app; preferences are retained.

Validation: native Xcode tests 72/72 passed (including icon declaration and
decodable 16 px / 1024 px representations); universal `arm64 x86_64` Release
build succeeded with strict Swift concurrency and Swift warnings as errors.
Workspace SwiftPM tests also passed 74/74, including the existing local sensor
tests. The native-only icon test is intentionally excluded from SwiftPM because
its executable does not have the native application's resource bundle.
The ICNS in the built bundle exactly matches the committed resource (SHA-256
`94ecf19aafe70589113b8c9ccd9bf8ddd9420d45fd3ef7fdd79b6a5edbf2c891`).
The new header icon and unchanged live overview were visually checked on macOS
26.5. The signed local test build is `运行版/MemoryGlass-20260904/PulseBar.app`.
This is an ad-hoc-signed local test app, not a notarized public release or an
App Store submission. No existing runnable version was overwritten.
