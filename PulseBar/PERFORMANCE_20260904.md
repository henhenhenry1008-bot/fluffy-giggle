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
