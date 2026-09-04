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
- Saving this approval does not yet change the installed app icon. Production
  export and integration are tracked separately after image-processing approval.
- Before adoption: local rollback tag `codex/pre-glass-icon-20260904` at `ca97b74`.
  The working Xcode project, Info.plist and Package.swift were also copied to
  `运行版/GlassIcon-before-ELcZjn/`, preserving unrelated local experiments.

The reported missing menu-bar item is a separate investigation. The tester's
main window opens on macOS 26; no region-specific cause or overflow cause has
been established. Do not present this icon approval as a fix for that report.
