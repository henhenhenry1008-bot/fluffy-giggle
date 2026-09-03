# Phase 23 — CPU Core Composition

## Scope and roadmap

This phase continues the original conversation's advanced CPU core-type item after
the Phase 22 application-process list and battery compatibility fix. It adds
hardware composition, not per-type CPU usage, frequency, or temperature.

The CPU card now shows physical/logical totals and a system-reported breakdown by
performance level. On this Mac the actual result is **18 physical / 18 logical**,
with **Super: 6 cores** and **Performance: 12 cores**. No Efficiency level is
invented. Other chips can report Performance/Efficiency, one symmetric level, more
levels, or no available breakdown.

Verified on 2026-09-03: macOS 26.5 (25F71), Apple M5 Pro, Xcode 26.6 (17F113).
The deployment minimum remains macOS 14. No OS update, private framework,
privileged helper, special entitlement, or new dependency was added.

## API evidence and data flow

- Apple's [Determining system capabilities](https://developer.apple.com/documentation/kernel/1387446-sysctlbyname/determining_system_capabilities)
  documents `hw.physicalcpu_max`, `hw.logicalcpu_max`, `hw.nperflevels`, and the
  per-level `physicalcpu_max` / `logicalcpu_max` fields. These describe hardware
  totals, not active or currently scheduled cores. Lower level indices indicate
  higher-performance types, not a guaranteed P/E naming or core-index mapping.
- The optional `hw.perflevelN.name` fields are exposed by Apple's
  [XNU implementation](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/kern_mib.c).
  Their vocabulary is not a stable API contract. Names are displayed as reported;
  absent or invalid names become `Level N`, without losing valid counts.
- `CPUTopologyService` is an actor using native `sysctlbyname`, not a shell command.
  Successful hardware readings are cached for the app session; failed total reads
  remain unavailable and can be retried by the existing sampler.
- `CPUTopologyProviding` feeds `SystemMonitorViewModel` through the same structured
  sampling operation. `SystemSnapshot.cpuTopology` carries the result to the CPU
  card and bounded history. Publication remains a single main-actor snapshot.
- No new timer or independent monitoring task was introduced. The 0.5 / 1 / 2 / 5
  second options and two-second default are unchanged. Existing saved choices,
  including this Mac's one-second setting, are preserved.

## Validation and rough review

- Before implementation, all 50 existing tests passed. The previous battery fix,
  per-core tick calculation, process timebase conversion, and central sampling
  changes were briefly reviewed; no additional concrete defect was identified.
- Require positive physical counts and logical counts at least as large. A
  partially missing, inconsistent, or oversized breakdown keeps valid global
  totals but reports core types unavailable. Level sums must match global totals.
- Bound enumeration to 32 levels and string buffers to 256 bytes. Validate C-int
  result sizes, string lengths, NUL termination, UTF-8, and optional label content.
  Subtraction-before-addition guards prevent integer overflow when summing levels.
- Do not assign P/E labels to Mach processor indices or calculate type-specific
  usage from an assumed ordering. Existing per-core bars are unchanged.
- Nine new tests cover hybrid layouts, Super/Performance and future layouts, SMT,
  missing/invalid fields, overflow, bounded enumeration, labels, central-snapshot
  integration/failure clearing, and live cached readings.
- SwiftPM and Xcode Debug: **59/59 tests pass**, zero failures/skips in the Xcode
  result. Complete strict concurrency and warnings-as-errors checks pass. Strict
  formatting lint, project plist validation, and `git diff --check` pass.
- Xcode Release builds for both `arm64` and `x86_64`. No Swift compiler/concurrency
  warnings; Xcode retains its unrelated App Intents metadata-skipping warning.
- Updated and ad-hoc-signed `运行版/PulseBar.app` with the unchanged App Sandbox
  entitlement. The computer-use skill inspected the actual sandboxed dashboard:
  both levels and totals were visible in Light/Dark appearance without clipping
  on this display. Battery remained readable. The original System appearance and
  saved refresh choice were retained after checking.

## Files changed

- New: `Sources/PulseBar/Services/CPUTopologyService.swift`,
  `Tests/PulseBarTests/CPUTopologyTests.swift`, this phase report.
- Models/protocols: `MonitoringReadings.swift`, `SystemSnapshot.swift`,
  `MonitoringProtocols.swift`.
- Integration/UI: `SystemMonitorViewModel.swift`, `DashboardView.swift`,
  `PlaceholderMonitoringServices.swift`.
- Test/build registration: `PulseBarTests.swift`, `AppProcessTests.swift`,
  `PulseBar.xcodeproj/project.pbxproj`.
- Progress: `README.md`, `AUDIT.md`.

## Remaining limitations and next boundary

- This completes the core-composition subset, not P/E-specific load charts. Exact
  mapping from Mach logical-core indices to performance levels is not established.
- A valid totals-only or partially named reading is cached until the app restarts.
  Name changes or previously unavailable optional fields can be rechecked then.
- Intel compiles but was not physically tested. Other chips, older macOS versions,
  large accessibility text, and long-running profiling need separate validation.
- CPU/GPU frequency, temperature, fan RPM, and power remain unimplemented. Their
  next phase must begin with read-only capability checks and explicit permission
  if private frameworks, privileged helpers, or entitlement changes are needed.
- Login-item registration and distribution signing remain outside this local,
  ad-hoc-signed test build.

Phase checkpoint: `codex/phase-23-cpu-topology`. Prior checkpoint:
`codex/phase-22-app-processes`, battery fix commit `5477ad9`.
