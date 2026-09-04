# PulseBar performance audit — 2026-09-04

## Scope and safeguards

- Measure **PulseBar's own process CPU**, as in Activity Monitor; 100% is one core.
- Preserve the approved layout/colors, real measurements, history capacity, and
  all 0.5 / 1 / 2 / 5-second choices (default remains 2 seconds).
- This Mac currently uses **1 second / 60 samples**, macOS 26.5, Apple M5 Pro.
- The pre-optimization runnable is `运行版/ColorOverview-20260904/PulseBar.app`.
  Its Debug build must be compared with Debug, not credited against Release.
- Before round 1: tag `codex/perf-round-1-before-20260904` at `41d52ac`;
  full working Sources/Tests/project backup in `运行版/Performance-baseline-haLNas/`.
- Existing uncommitted sensor and website experiments are preserved and excluded
  from clean exported native builds. Nothing is pushed or published.

## Measurement method

`Tools/measure_process_cpu.py` reads the target PID's cumulative user+system CPU
time via `ps`, divides the delta by monotonic elapsed time, and checks process
start identity. Three 20-second trials per state; fill all history first. No
build, profiler, or UI interaction during a measured interval. This has the same
one-core denominator as Activity Monitor, but not its exact rolling time window.
These short observations are not a guarantee on other hardware or workloads.

## Baseline review

- Confirmed exactly one app process, PID 24260, running the approved Debug app.
- Overview CPU: **8.497%, 8.146%, 8.645%; mean 8.429%** (60 seconds total).
- A separate 5-second stack sample found recurring main-thread SwiftUI/Charts
  layout and per-point mark work. Provider reads were a much smaller part of
  that sample. Nested stack counts are not summed into invented percentages.
- Closing-window attempts returned 8.228% and 9.045%, but subsequent automation
  still exposed the dashboard. Visibility was not independently established;
  those numbers are **not a verified background baseline**.
- Review found one central cancellable monitoring loop and existing counter-reset,
  overflow, unavailable-reading and cadence tests. No sampling changes justified.

## Round 1 — batch existing chart marks

- Replace individual `LineMark` nodes with `LinePlot` on macOS 15+, keeping the
  macOS 14 fallback, colors, 1.5pt stroke, monotone curves, scale and accessibility.
- Prepare finite, nonnegative series points once per input instead of evaluating
  value closures repeatedly during Chart content and scale construction.
- Apple reference: [Vectorized plots](https://developer.apple.com/videos/play/wwdc2024/10155/).
- Added tests for invalid/zero/extreme values, timestamps, ring order, and independent
  upload/download series. SwiftPM: 69 tests passed including 3 existing experimental
  tests. Clean Xcode Debug: 66 tests passed, strict concurrency and warnings-as-errors.
- Visually checked main overview: same layout, colors, labels and two network lines.
- The initial measurement started before all 60 samples filled; discard it and use
  the subsequent full-history measurements below.
- Runnable checkpoint: `运行版/PerfRound1-20260904/PulseBar.app`.
- Full-history CPU, PID 26107: **4.449%, 4.298%, 4.248%; mean 4.332%**,
  about 48.6% lower than baseline under the same Debug/1-second conditions.

## Round 2 — lightweight sparkline rendering

- Before changes: reviewed round-1 diff/tests, recorded its CPU results, committed
  `6b4eb16`, tagged `codex/perf-round-2-before-20260904`, and backed up the complete
  working native source to `运行版/Performance-round2-before-hlHnZS/`.
- A new 5-second sample still showed Chart layout work. The graphs intentionally
  hide axes/legends and have no per-point selection; a full chart layout engine is
  unnecessary for these compact sparklines.
- Replace the round-1 chart renderer with [SwiftUI Canvas](https://developer.apple.com/documentation/swiftui/canvas),
  drawing one path per series. This is supported on the existing macOS 14 target.
- Keep 1.5pt colored smooth strokes, actual timestamp spacing, all history samples,
  fixed percentage domains, shared network scale, and existing accessibility labels.
  Monotone cubic segments pass through the measured points and constrain control
  points to each segment's vertical range to avoid false peaks. Smoothing is not
  pixel-identical to Charts' private interpolation implementation.
- Invalid sizes/domains, duplicate or backward timestamps, nonfinite coordinates
  and too few points safely produce no invalid path/division. No Timer, Task,
  polling loop or cache is introduced by the renderer.
- All sampling services, scheduler, stored preferences, app scenes, and approved
  dashboard layout/color code remain unchanged.
- Added projection/interpolation edge tests. SwiftPM: **71 tests passed** including
  the 3 existing experimental tests. Clean Xcode Debug: **68 tests passed**, with
  strict concurrency and Swift warnings-as-errors enabled.
- Runnable: `运行版/PerfRound2-20260904/PulseBar.app`.
- Full-history CPU, PID 26871: **4.348%, 4.597%, 4.497%; mean 4.481%**.
  This is not an improvement over round 1's 4.332% and is within short-run noise.
  **Reject this experiment**: retain a checkpoint but restore the simpler tested
  round-1 renderer before the next round. The Canvas geometry/tests do not ship.

## Round 3 — isolate scene updates and deduplicate menu-bar rendering

- Round-2 experiment saved as `fafa48f` and tagged
  `codex/perf-round-2-experiment-20260904`. Only its own chart/test changes were
  reverted in `3f572ad`; round-1 chart and tests verified byte-identical.
- Before round 3: tag `codex/perf-round-3-before-20260904`, full native working
  backup in `运行版/Performance-round3-before-QKkU0t/`, and review of App ownership,
  monitoring lifecycle, menu-bar presentation/equality and stored-preference hooks.
- App previously observed every publication and recreated scene descriptions on
  each sample. App now owns the reference in `State`; Dashboard and the small
  `MonitoredMenuBarLabel` observe it directly. Reference lifetime remains app-owned.
  This use of State with Combine objects is documented by [Apple](https://developer.apple.com/documentation/swiftui/state).
- The inner menu-bar view is equatable using all rendered text/accessibility values.
  Hidden metrics and rounded-to-the-same-value readings no longer redraw its content.
  Visibility/unit preferences stay in the outer view, so changing them still works.
- No measurement service, refresh cadence or layout changes. No new asynchronous
  task, timer or notification subscription. The round-1 Charts renderer is retained.
- Added a regression test for hidden readings, visible changes and unit changes.
  SwiftPM: **70 tests** (including 3 preexisting experimental); clean Xcode Debug:
  **67 tests**, strict concurrency and Swift warnings-as-errors, all passed.
- Runnable: `运行版/PerfRound3-20260904/PulseBar.app`.
- The UI reported a transition from AC to battery before round 3. Workloads and
  power state are not controlled; treat percentage comparisons as observations,
  not a precise causal attribution for small differences.
- Full-history CPU, PID 27525: **3.748%, 3.748%, 3.698%; mean 3.731%**.
  This is 55.7% below the original 8.429% observation and 13.9% below round 1.
- During pre-measurement warmup, CPU details and return-to-overview navigation
  were checked. Overview retains its original layout, graphs, Disk pink and green
  battery fill with gray outline; readings continue changing.
