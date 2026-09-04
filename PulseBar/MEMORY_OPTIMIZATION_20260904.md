# Memory optimization — 2026-09-04

## Safety and scope

- Before changes: local tag `codex/pre-memory-optimization-20260904` at
  `54bb8c53bbc8c0743b27ccd2dce1ba886ad7184f` and GitHub branch with the same name
  at the tree-equivalent remote commit `eb652c7468969b95a3be0fc35a3de1ec31bbf6a0`.
- The entire working Sources, Tests, project and configuration were separately
  copied to `运行版/Memory-before-FDn7Cs/`. This preserves the unrelated, uncommitted
  sensor/website work, which is deliberately not included in this change.
- The previous runnable app remains at `运行版/MenuBarFix-20260904/PulseBar.app`.
  Quit the new version before opening it. No preferences are reset.
- Scope: chart implementation and regression tests only. No changes to sampling,
  CPU/network/memory calculations, history capacity, hardware support, menu-bar
  lifecycle, colors, layout or settings. 0.5 s / 1 s remain available; default 2 s
  is unchanged. The actual current user setting of 1 s was used for measurements.

## Review and chosen change

The history is already bounded and the sampling task already has cancellation
and weak ownership. Short observations did not establish an unbounded application
leak. A large portion of the physical footprint is graphics-related, rather than
the few hundred historical readings themselves.

The small charts have no axes, legend, selection or per-point interaction. Replace
their Swift Charts view/layout machinery with two directly drawn Canvas paths.
All samples, timestamps, colors, domains and accessibility descriptions remain.
Monotone interpolation is tested to hit samples and not invent peaks; smoothing
may differ slightly from Apple's Charts implementation, not pixel-identical.
There are no added timers, tasks, global caches or observation subscriptions.

The old Canvas experiment was rejected earlier for CPU alone, before the app-root
observation fix. This round retests it against the current menu-bar-fixed Release
build and measures memory as well; the previous negative result is not erased.

An autorelease-pool experiment around GPU enumeration was also tried in a
standalone probe: 200 real Metal/IORegistry enumerations retained about 3.97 MB
without a pool versus 3.95 MB with one. That is not a useful demonstrated saving,
so no speculative GPU-service edit was made.

## Measurements and limitations

Machine: Apple M5 Pro, 48 GiB installed RAM, macOS 26.5 (25F71). One hardware app
at a time, optimized Release, overview visible, 1 s refresh, 120 samples. CPU is
process CPU time divided by wall time, where 100% is one core, measured by
`Tools/measure_process_cpu.py`; two 15 s runs after filling the history.

| Run | Mean CPU | RSS (MiB) |
| --- | ---: | ---: |
| Old app after earlier detail navigation | 4.763% | 136.8 |
| Freshly restarted old app, filled history | 3.931% | 109.6 |
| First Canvas run, filled history | 2.698% | 102.7 |
| Repeated fresh Canvas run, about five minutes | 3.332% | 98.9 |

`vmmap -summary` observations (tool's M units, not the application's decimal GB):

- Old app after earlier navigation: physical footprint 146.9–226.2 M depending
  on view/window state; default malloc allocated about 23–29 M.
- Fresh old overview: 130.8 M early, 160.9 M at about 4 min 46 s, with allocated
  default malloc growing from 14.8 M to 25.5 M. A single early snapshot understates
  the warmed graph cost.
- First Canvas run: physical footprint 124.1–128.4 M in the later snapshots;
  default malloc allocated 12.9–13.0 M.
- Repeated fresh Canvas run at about five minutes: physical footprint 128.7 M,
  default malloc allocated 13.7 M. Against the warmed fresh old run's 160.9 M,
  this snapshot is about 20% lower. CPU improvement across repeated runs was
  smaller than the initial comparison, so retain both results rather than only
  quoting the best run.

These are short, sequential on-device observations, not a fixed memory guarantee
or a controlled multi-hour benchmark. Graphics backing stores/occlusion cause
large changes, so do not claim a percentage saving from unmatched peak values.
No background-close, Intel runtime, macOS 14 runtime or long-duration leak claim
is made. The read-only `leaks` inspection of the hardened old app explicitly
reported limited access; its small system-framework cycles do not establish an
application leak or prove the whole process leak-free.

## Verification

- SwiftPM: 74 tests passed, including the 3 pre-existing local sensor tests.
- Clean native Xcode snapshot: 71 tests passed, including the 2 added geometry
  tests, with strict Swift concurrency and Swift warnings as errors.
- Universal Release (`arm64 x86_64`) built with strict concurrency and Swift
  warnings as errors. The first sandboxed test attempt could not contact Xcode's
  test service; the permitted rerun passed. This was an environment restriction,
  not a test assertion failure.
- Native overview inspected with real, updating CPU, memory, GPU, network, disk
  and battery data. No card layout or settings changes.
- Icon integration is a separate subsequent checkpoint, so it can be reverted
  independently of the chart optimization.
- The signed, memory-only Release app is preserved separately at
  `运行版/MemoryRound1-20260904/PulseBar.app`; the original app is not overwritten.
