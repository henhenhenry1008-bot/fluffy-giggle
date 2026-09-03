# Phase 15 Project Audit

## Scope

The complete PulseBar MVP was reviewed for compiler and concurrency warnings, crashes, optional handling, task and timer lifetime, integer overflow, CPU and network counter behavior, hardware assumptions, Apple Silicon compatibility, menu-bar layout, and Dark Mode use.

## Issues found and fixed

1. The CPU delta helper assumed every supplied counter fit the 32-bit `natural_t` range returned by Mach. A malformed wider value could underflow during wrap calculation. The helper now rejects out-of-range snapshots while retaining correct UInt32 wrap behavior.
2. Network rate calculation validated its interval but could still produce infinity from an extreme counter delta divided by a tiny positive interval. Non-finite calculated rates are now rejected before they reach snapshots, formatters, or charts.

Both fixes are limited to invalid edge inputs and do not change normal hardware readings.

## Review findings

- Monitoring uses one cancellable task, prevents overlapping samples, coalesces manual refreshes, and does not create UI-owned timers.
- Providers are actors or immutable `Sendable` values; the view model publishes only on the main actor.
- Mach and IOKit ownership is balanced, and unavailable metrics remain optional rather than fabricated.
- History uses a bounded ring buffer, with no unbounded monitoring collections.
- UI colors and materials are adaptive for Light and Dark Mode. Fixed-width metric text uses truncation or compact formatting where appropriate.
- The project contains no force unwraps, forced casts, `try!`, detached tasks, unchecked sendability, or unresolved TODO/FIXME markers.

## Verification

- Swift formatting lint passes in strict mode.
- SwiftPM Debug tests pass with warnings treated as errors: 30/30.
- Xcode Debug tests pass with Swift and Clang warnings treated as errors: 30/30.
- Address Sanitizer and Thread Sanitizer both pass all 30 tests without findings.
- SwiftPM Release build and Xcode static analysis pass.
- The Xcode Release archive succeeds as a universal `arm64` and `x86_64` application.

## Remaining limitations

- The menu-bar-only app launches successfully, but the desktop automation interface cannot attach to its popover because it has no ordinary application window. Light/Dark appearance and clipping still need a short manual check on the target Mac, especially with larger accessibility text sizes and all menu-bar metrics enabled.
- Launch at Login requires a normally signed installed build for an end-to-end check.
- TestFlight/App Store signing, notarization, app icon assets, localization, and UI automation are not configured yet.
- A long Instruments session covering idle operation, sleep/wake, and network-interface changes remains recommended before release.
- Temperature, GPU, fan, power, and process monitoring belong to the later advanced-feature plan.

# Phase 20 Battery Details — Completion Review

Reviewed on 2026-09-03. This is a short follow-up review, not a release certification or a long-running profiling session.

## Progress

- Battery health text and estimated time to empty/full now flow from the existing battery service through the snapshot to the dashboard.
- The implementation uses the public IOPowerSources health and time keys, retains the existing five-second battery sampling cadence, and adds no timers or monitoring tasks. See Apple's [health key documentation](https://developer.apple.com/documentation/iokit/kiopsbatteryhealthkey) and [time-to-empty documentation](https://developer.apple.com/documentation/iokit/kiopstimetoemptykey).
- Missing or calculating estimates remain optional. Discharge time is hidden on AC power; charging time is hidden when charging is paused or complete. Health strings are trimmed, with a nonempty condition preferred over the general estimate.

## Issues found and fixed

- Chart Y-axis padding could overflow when multiplying a very large but finite sample by 1.1. It now falls back to the unpadded finite maximum. A regression test covers the largest finite Double, ordinary values, and invalid inputs.
- The unfinished battery changes lacked direct coverage for unknown estimates and AC power without active charging. Added coverage for missing values, the -1 sentinel, zero minutes, normal estimates, paused charging, and completed charging.
- The quick review found no additional concrete defects in CPU deltas, network/device counter resets, byte formatting, optional ownership, or refresh-task lifetime. No unrelated refactor was performed.

## Verification

- Strict Swift formatting lint and `git diff --check` pass.
- SwiftPM Debug tests: 37/37 pass, with warnings treated as errors and complete strict concurrency checking.
- Xcode Debug tests: 37/37 pass under the same Swift warning/concurrency checks and Clang warnings-as-errors.
- Xcode static analysis and SwiftPM Release build pass.
- Xcode Release archive succeeds; `lipo` confirms both `arm64` and `x86_64` slices.
- No Swift compiler or concurrency warnings were reported by these checks.
- Address/Thread Sanitizer runs recorded above belong to Phase 15; they were not rerun in this short follow-up.

## Files changed

- `Sources/PulseBar/Services/BatteryService.swift`
- `Sources/PulseBar/Services/PlaceholderMonitoringServices.swift`
- `Sources/PulseBar/Models/MonitoringReadings.swift`
- `Sources/PulseBar/Models/SystemSnapshot.swift`
- `Sources/PulseBar/ViewModels/SystemMonitorViewModel.swift`
- `Sources/PulseBar/Utilities/MetricFormatter.swift`
- `Sources/PulseBar/Views/Dashboard/DashboardView.swift`
- `Sources/PulseBar/Views/Components/MetricChart.swift`
- `Tests/PulseBarTests/PulseBarTests.swift`
- `README.md` and `AUDIT.md`

## Remaining limitations

- Health is the system-reported status text, not a battery-health percentage. Cycle count and power measurements are not implemented.
- Time estimates may be absent while the system is calculating or withholding them; no estimate is fabricated.
- Tests ran on the current Apple Silicon Mac. The Intel slice compiles but was not exercised on an Intel Mac, and macOS 14 was not separately tested.
- Dashboard clipping and Light/Dark appearance still need a brief manual check, particularly for long health strings and accessibility text sizes.
- This unsigned archive does not validate Launch at Login, TestFlight distribution, signing, or notarization. Long-running Instruments checks remain deferred.

Phase checkpoint: `codex/phase-20-battery-health-estimates`. The preceding checkpoint remains `codex/phase-19-disk-throughput`.

# Phase 21 GPU Follow-up

The experimental, read-only GPU implementation and its short completion review are recorded in [PHASE_21_GPU.md](PHASE_21_GPU.md). SwiftPM and Xcode tests now pass 40/40, and a sandboxed probe using the actual GPU service returned valid live readings on macOS 26.5 / Apple M5 Pro. The earlier reviews remain historical records; GPU driver compatibility and the remaining UI/runtime checks are described in the Phase 21 report.

# Phase 22 Application Processes Follow-up

The sandbox-compatible application-process subset and its short review are recorded in [PHASE_22_APP_PROCESSES.md](PHASE_22_APP_PROCESSES.md). SwiftPM and Xcode tests pass 47/47. Timebase conversion, PID reuse, disappearing processes, counter resets, bounded ranking, and sampling cadence are covered. A sandboxed probe confirmed actual readings and checked CPU time conversion against `getrusage`. Full system process enumeration remains deferred. Battery implementation, UI logic, refresh cadence and sandbox entitlements are unchanged.

# Battery Charged-Flag Compatibility Fix

Reviewed on 2026-09-03, following the Phase 22 checkpoint. This is a targeted bug fix, not a new feature or full-project audit.

## Issues found and fixed

- Requiring `kIOPSIsChargedKey` discarded otherwise valid internal-battery descriptions when the system omitted that field. The user's 75/100, charging, AC-power example reproduced the failure in a deterministic test before the fix.
- The service now preserves an explicitly reported charged flag, including `false`. If absent, it infers full charge from capacity only while connected to AC power. Apple's [charged-key documentation](https://developer.apple.com/documentation/iokit/kiopsischargedkey) requires external power for this status; a just-unplugged battery at 100% must not be inferred as charged.
- The live battery test previously passed silently on `nil`. It now independently checks for a present internal battery and requires a service reading when one is detected. Batteryless Macs remain supported.
- Dictionary parsing was extracted only to exercise the actual IOPowerSources boundary in tests. Dashboard rendering, battery sampling cadence, other monitoring services, and refresh settings are unchanged.

## Verification

- Three dictionary-level regression tests cover the missing flag, explicit true/false precedence, capacity boundaries, unplugged full capacity, absent batteries, and invalid required fields. The missing-field tests fail before the production fix and pass afterward.
- SwiftPM and Xcode Debug tests: 50/50 pass each, with complete strict concurrency checking and Swift/Clang warnings treated as errors where applicable.
- Strict Swift formatting lint and `git diff --check` pass. No Swift compiler or concurrency warnings were reported. Xcode still emits the unrelated App Intents metadata-skipping warning because the app does not depend on AppIntents.
- Xcode Release build succeeds for both `arm64` and `x86_64`. The local runnable app was updated and its ad-hoc signature verified.
- The computer-use skill was used to open the rebuilt sandboxed application and inspect the actual dashboard. Battery showed 80% and On AC Power on this Mac; the missing-field scenario is guaranteed by the synthetic regression tests, not by assuming the live system always omits the key.

## Files changed and limitations

- Changed `Services/BatteryService.swift`, `Tests/PulseBarTests/PulseBarTests.swift`, and this audit record.
- The capacity fallback is deliberately conservative and does not reproduce every optimized-charging policy. Other missing required fields still produce an unavailable reading, and optional health/time fields remain system-dependent.
- Runtime checks used the current Apple Silicon Mac; Intel was compile-checked only. Long-running profiling, older macOS testing, and distribution signing were not performed for this fix.

# Phase 23 CPU Core Composition Follow-up

The next advanced CPU increment and its rough review are recorded in
[PHASE_23_CPU_TOPOLOGY.md](PHASE_23_CPU_TOPOLOGY.md). The previous 50-test baseline
and final 59-test SwiftPM/Xcode suites pass. The sandboxed runnable app displays
the live 6 Super / 12 Performance breakdown and physical/logical totals. Hardware
counts are validated and cached; no P/E-to-core-index mapping is assumed. Light
and Dark appearance were checked through the computer-use skill. Existing battery
behavior, refresh choices/default, and entitlements remain unchanged. The phase
report lists the exact files changed and remaining hardware/runtime limitations.
