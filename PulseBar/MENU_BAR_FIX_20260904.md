# Menu-bar rendering and scene lifecycle fix — 2026-09-04

## Scope and findings

The user approved fixing both the multi-selection display bug and the unsupported
menu-bar initializer used alongside the dashboard window. Monitoring, preferences,
sampling intervals, metric colors and the dashboard layout are unchanged.

- On macOS 26.5, an isolated reproduction of the old `HStack` / `ForEach` label
  generated only the first native `NSStatusBarButton.title`. Removing the
  `Equatable` optimization did not fix it; one combined `Text` did.
- `MenuBarPresentationView` now renders its existing complete `presentation.title`
  in one `Text`, preserving the selection order, monospaced digits, accessibility
  description and formatted-value equality optimization. No selection still
  displays `PulseBar`; unavailable readings remain visible as dashes.
- `PulseBarApp` now uses `MenuBarExtra(isInserted:content:label:)` with session
  `@State` initialized to `true`. It is appropriate for an app with other window
  scenes and does not persist accidental removal across launches. It respects
  removal during the current session; this is not an always-visible override.
- The tester's missing item has NOT been reproduced on their Mac. This fixes the
  identified lifecycle risk, not a confirmed regional or macOS-version cause.

Apple documentation:
- https://developer.apple.com/documentation/swiftui/menubarextra/init(content:label:)
- https://developer.apple.com/documentation/swiftui/menubarextra/init(isinserted:content:label:)

## Verification

- Working-tree SwiftPM tests: 72 passed, including the 3 existing local sensor tests.
- Clean native snapshot, `xcodebuild test`: 69 passed, 0 failures or skipped tests.
- Native Debug tests and universal Release build succeeded with
  `SWIFT_STRICT_CONCURRENCY=complete` and `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`.
- Universal executable contains `arm64` and `x86_64`; strict ad-hoc signature
  verification passed. Intel was compiled, not tested on Intel hardware.
- New unit test covers all 32 menu-bar selection combinations, including missing
  readings and no selections. Existing redraw-equality tests still pass.
- `Tools/MenuBarRenderingCheck.swift` compiles with the actual production label
  and model sources, excluding the normal app entry point. In a separately
  identified diagnostic app on macOS 26.5, all 6 native checks passed:
  1. Three selected metrics: `CPU 23%  MEM 51%  ↓ 2.5MB`.
  2. All five: `CPU 23%  MEM 51%  ↓ 2.5MB  ↑ 820KB  BAT 83%`.
  3. None selected: `PulseBar`.
  4. Missing readings: `CPU —  MEM —  ↓ —  ↑ —  BAT —`.
  5. Removing the item using its binding does not terminate the window-based app.
  6. Re-enabling the binding reinserts an item with the correct native title.
- The developer-only probe instruments the public AppKit status-item factory
  inside its own process and keeps weak references. An earlier probe incorrectly
  used `NSWindow.isVisible`; the final probe checks `NSStatusItem.isVisible`.
  This instrumentation is NOT compiled into the distributed app.
- Reviewed the scoped diff and whitespace. No new timers, monitoring tasks,
  sampling subscriptions or production dependencies were added.

## Runnable and rollback

- New runnable: `运行版/MenuBarFix-20260904/PulseBar.app`.
  This is an ad-hoc-signed local test build, not a notarized public release.
- Old `运行版/UnitsNotice-20260904/PulseBar.app` remains unchanged.
- Quit all previous PulseBar instances before opening the new runnable. Both an
  old ColorUICheckpoint Debug process and the UnitsNotice runnable were present
  during diagnosis; they were not stopped or replaced automatically.
- Local rollback tag: `codex/pre-menubar-fix-20260904` at
  `797351db2d1b9ecba7c337799981d6d02fa4467c`.
- Original working files (including the unfinished App sensor conditional) are
  copied to `运行版/MenuBar-before-ObonGJ/`.
- GitHub rollback branch: `codex/pre-menubar-fix-20260904` at
  `3c26f4f1e07732e7845d8e67b834be860c137a61`. Its tree matches the local pre-fix
  commit: `80c2f01058cb033b99e0bd0a62034db21e7ae0a6`.
- Fix branch: `codex/menubar-fix-20260904`. GitHub API and local commit metadata
  differ; verify the tree SHA for source equivalence.
- Recover the previous runnable or use a separate worktree at the rollback tag;
  do not reset this dirty working directory. Existing sensor/website experiments
  are preserved locally and excluded from the fix commit and clean release build.

## Remaining validation

- Retest the new runnable on the originally affected Mac. Menu-bar crowding,
  notch space, third-party item-hiding utilities and other OS versions remain
  external factors; insertion does not guarantee on-screen visibility.
- Public distribution signing/notarization and production icon integration are
  separate work. No main-branch merge or GitHub binary release was performed.
