# Compact overview — 2026-09-04

## Scope

- Menu-bar content and the opening dashboard now use four summary cards: CPU,
  Memory, Disk and Network. Clicking a card opens its existing detailed readings;
  Overview (or Escape in a detail view) returns to the summary.
- The standalone window retains All metrics. The menu-bar header retains its
  Open dashboard window button. Settings remain separate.
- CPU is blue, memory green, disk orange, network cyan and GPU purple. System,
  Light and Dark appearance continue using native semantic colors and materials.
- Summary cards show one primary value, supporting text and a small chart or
  capacity bar. GPU and battery have secondary detail buttons; a missing battery
  is not displayed as a fabricated percentage. Unknown data remains unavailable.
- The disk summary's decorative progress bar is hidden from accessibility so
  the whole card correctly exposes a button, not a progress-indicator role.

No sensor, CPU/network calculation, formatter, refresh cadence, preferences,
permissions, website, or distribution change is included. The default remains
2 seconds, with 0.5/1/2/5-second choices; existing user choices are preserved.
The chart history and monitor are shared with the full dashboard, with no new
sampling task or timer. LIVE describes sampling, not a hardware-health verdict.

## Verification

- Working tree: 67 existing Swift tests passed; Xcode Debug build/test passed.
- Independent clean checkpoint (excluding pre-existing experimental sensor
  files): 64 tests passed with both SwiftPM and Xcode.
- Builds used complete Swift concurrency checking and warnings-as-errors.
- Native window checked in dark/system and light appearance: no evident
  clipping at the standard 390-point width. CPU/network/disk drill-down,
  Overview/Escape and All metrics navigation were checked. The disk summary
  was confirmed to expose a clickable accessibility button in the final build.
- App signature verification passed for the local Debug bundle.
- Appearance was restored to System; the user's existing 1-second preference
  was not changed.

The system-menu-bar automation timed out. The overview's shared native view was
verified in the standalone window; physical menu-bar placement/closing behavior
still needs a quick click-through on the user's desktop. No separate Intel,
macOS 14, formal contrast audit, VoiceOver end-to-end, or localization pass was
performed. This is a local testing build, not a signed/notarized public release.

## Immediate rollback without touching source

1. Quit the new PulseBar instance.
2. Open the preserved previous App:
   `运行版/ReleasePreflight-f2df9c0-20260904/PulseBar.app`.

New local App: `运行版/CompactOverview-20260904/PulseBar.app`.
Both builds use the same preference keys; no migration or reset is required.
Do not run both instances simultaneously.

## Source rollback checkpoints

- Before this change: Git tag `codex/pre-compact-ui-20260904` (`c52550a`).
- After this change: Git tag `codex/compact-ui-20260904`.
- Pre-edit copies of Sources, Tests, the Xcode project and Package.swift,
  including existing uncommitted experiments, are retained locally in
  `运行版/CompactUI-baseline-eHGbtX/` (ignored by Git).

To inspect/build the previous committed version without resetting this dirty
working tree, run from the repository root:

```sh
git worktree add --detach ../PulseBar-before-compact-ui codex/pre-compact-ui-20260904
```

Use an unused destination if that folder already exists. Do not use a hard reset
or overwrite the current Sources folder: the original experimental sensor work,
phase-22 document edits and website work remain outside this UI checkpoint.

## Files in this change

- `Sources/PulseBar/App/PulseBarApp.swift`
- `Sources/PulseBar/Views/Dashboard/DashboardView.swift`
- `Sources/PulseBar/Views/Components/MetricCard.swift`
- `UI_COMPACT_OVERVIEW.md`
