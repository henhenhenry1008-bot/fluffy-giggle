# Decimal-unit notice — 2026-09-04

## Change

- Add `ⓘ Units: 1000` next to the battery in the compact overview's bottom row,
  shared by the menu-bar panel and dashboard window. It remains available on Macs
  without a battery.
- Clicking opens an explanation of KB/MB/GB/TB, the 48 × 1024³ byte memory example
  (51.54 decimal GB, rounded to 52 GB), unchanged usage percentages, and bits versus
  bytes. A tooltip and accessibility label identify the button.
- Use existing semantic colors and native popover styling. The notice owns only
  its presentation state; no polling, timer, task or monitoring subscription added.
- No changes to sensors, unit conversion, sampling frequency, history or the
  existing battery colors. Unfinished website/sensor work is excluded from the
  saved native commit and clean build.

## Validation

- SwiftPM: 71 tests passed, including 3 preexisting experimental sensor tests.
- Clean native Xcode target: 68 tests passed, 0 failures/skips (xcresult summary).
- Strict concurrency and Swift warnings-as-errors enabled for both checks.
- Universal Release build passed; arm64 and x86_64 slices and strict code-signature
  verification passed. Xcode emitted its AppIntents metadata-extraction warning
  because this app has no AppIntents dependency; no Swift/compiler concurrency warning.
- Reviewed the scoped diff: the only production change is the unit-notice view and
  its insertion beside the battery. The added test keeps the explanation's memory
  example consistent with the current formatter.
- Interactive layout, popover and Light/Dark appearance checks are **pending**:
  the Mac was locked and computer-use tools could not unlock it. Do not treat the
  new app as visually verified or already launched.

## Runnable and rollback

- New local runnable: `运行版/UnitsNotice-20260904/PulseBar.app` (ad-hoc signed, not a
  notarized distribution release). Quit the old PulseBar before opening it.
- Existing `运行版/PerformanceOptimized-20260904/PulseBar.app` is retained unchanged.
- Before-change local tag: `codex/pre-units-notice-20260904` at `1665627`.
- Original working DashboardView and test file, including existing uncommitted
  content, are backed up in `运行版/UnitsNotice-before-24LIrr/`.
- GitHub before-change branch: `codex/checkpoint/pre-units-notice-20260904` at
  `0b3b992118d381da6e0b0bdd995e19e739470e62`, whose tree matches local `1665627`.
- This change is saved separately on `codex/units-notice-20260904` on GitHub. As in
  the earlier checkpoints, compare tree SHAs for content equivalence because GitHub
  API commit metadata differs. No main merge or binary release is requested.
- Recover source in a separate checkout/worktree. Do not hard-reset the working
  directory, which still contains unrelated uncommitted experiments.
