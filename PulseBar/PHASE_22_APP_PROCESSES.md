# Phase 22 — Application Process CPU List

## Scope

This phase advances the original roadmap's process-list item with a sandbox-compatible **application-process subset**. It is not a complete system process monitor. The dashboard shows up to five readable application processes, ranked by CPU usage, alongside resident memory. Battery code, battery presentation, battery sampling, and entitlements are unchanged.

Verified on 2026-09-03: macOS 26.5 (25F71), Apple M5 Pro, Xcode 26.6, macOS SDK 26.5, Swift 6.3.3. The deployment minimum remains macOS 14.

## Capability checks before implementation

- The existing GPU driver's statistics did not expose frequency, temperature, or power keys in the inspected payload. Those metrics remain unimplemented, not fabricated.
- A signed probe with the existing App Sandbox entitlement found full `proc_listallpids` enumeration denied (`EPERM`). Cross-process `proc_pid_rusage` was also denied; it was not adopted as the production backend.
- The public workspace application list plus public `proc_pidinfo` / `PROC_PIDTASKALLINFO` worked for many listed applications without changing entitlements. Exited or restricted processes were skipped.

These are observations on this machine, not promises about every macOS version or permission environment. No private framework, special entitlement, root process, shell-based production reader, or process-control operation was added.

## Data source and architecture

`AppProcessService` is an actor implementing `AppProcessProviding`. A short main-actor operation copies PIDs from [NSWorkspace.runningApplications](https://developer.apple.com/documentation/appkit/nsworkspace/runningapplications); native resource queries then run on the service actor. The workspace list represents running applications, not every daemon or child process.

The public SDK's `proc_taskallinfo` supplies BSD process identity and task counters together. The PID plus start seconds/microseconds identifies a process incarnation. Names come from that same BSD result, avoiding a name/counter mismatch if a workspace entry exits before the query.

CPU calculation is:

```text
(delta user ticks + delta system ticks)
    × mach_timebase_info.numer / mach_timebase_info.denom / 1e9
    ÷ actual elapsed seconds
```

Apple's [XNU task/BSD implementation](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/bsd_kern.c) supplies task totals in Mach time units. The implementation converts those units rather than assuming one tick equals one nanosecond. It uses `ContinuousClock` for each process's elapsed interval. A value of 1.0 is one occupied core, so the display intentionally allows values above 100%.

`pti_resident_size` is shown as **Resident**, using existing binary byte formatting. It is not the process memory footprint shown in Activity Monitor; process values are not summed into system memory usage.

The existing view model requests process samples at the user's selected refresh interval: **0.5, 1, 2, or 5 seconds**. Per the user's clarification, the default is **2 seconds**, not a mandatory minimum. Existing saved choices are preserved, and manual refresh also samples processes. `MonitoringRefreshInterval.standard` keeps the app, settings and view-model defaults consistent. There are no new timers or independent monitoring loops. `SystemSnapshot` stores only the top five rows and coverage counts; existing bounded history therefore stays bounded. Battery's pre-existing five-second throttling is unchanged.

## Correctness and rough review

- First sample, invalid interval/timebase, lower counters, or changed start identity produce unavailable CPU, not zero or a spike.
- Integer subtraction happens before floating-point conversion. User/system deltas are added as Double to avoid integer-sum overflow, and non-finite results are rejected.
- Exited/unreadable processes are removed from the baseline dictionary each completed sample. Reappearing entries must establish a fresh baseline.
- PIDs are deduplicated. Queries and retained baselines are capped at 1,024 candidates; a visible note identifies truncation. Only five rows enter each snapshot.
- Sorting uses CPU, resident bytes, then PID for stable ties. Before CPU baselines exist, rows are ordered by resident memory and CPU displays a dash.
- The card explicitly identifies application-only coverage, readable/listed counts, and the one-core percentage convention. Names truncate and retain a full-name/PID tooltip; colors remain system-adaptive.
- No additional concrete defect was found in the brief review of existing sampling/cancellation integration. Existing subsystem tests continue to pass. No unrelated refactor was performed.

## Verification

- Baseline before implementation: SwiftPM 40/40 tests pass.
- Final SwiftPM and Xcode Debug: **47/47 tests pass** with warnings-as-errors and complete Swift concurrency checking.
- Seven new tests cover timebase conversion, multi-core formatting, invalid inputs, large counters, ranking/deduplication, PID lifecycle, all four sampling choices/failure clearing, and live bounded reads. The existing interval tests also verify the new two-second default.
- Strict Swift formatting lint, project plist validation, and `git diff --check` pass.
- Xcode static analysis, SwiftPM Release build, and Xcode Release archive pass. The archive contains both `arm64` and `x86_64` slices.
- No Swift compiler/concurrency warnings. Xcode emits its non-Swift App Intents metadata warning because this app has no AppIntents dependency; no unrelated framework was added to suppress it.
- A signed sandbox probe built from the actual service performed three samples: 181 readable out of 192 listed application processes, five rows each time, unavailable CPU on the first sample and valid CPU on the following two. Observed query durations were approximately 6–8 ms; these are short probe observations, not a sustained performance guarantee.
- A separate 150 ms self-CPU check inside that probe compared converted task ticks with public `getrusage` time. The ratio was approximately 0.99997, confirming the timebase conversion on this Apple Silicon machine.
- After the refresh-option clarification, the sandbox probe was repeated with 0.5-second and 1-second intervals. Both returned valid CPU results (185 readable out of 196 listed, five rows); the conversion ratio was approximately 0.99999. SwiftPM/Xcode tests, analysis and Release builds were rerun for the final default/interval code.

## Remaining limitations

- Full system process enumeration is still deferred. Application helpers only appear if the workspace lists them, and related processes are not aggregated by app. Protected/exited entries may be absent.
- BSD names can already be truncated by the kernel. Resident memory differs from physical footprint and can include shared pages. No cross-process footprint, process control, or per-process GPU data is implemented.
- The first CPU result needs a second sample. Later results are interval averages, not instantaneous percentages; short-lived processes can disappear between samples.
- Intel compiles but was not physically tested. macOS 14 and future releases need their own runtime check.
- Light/Dark appearance, long names and accessibility text sizes still need a manual popover check. Long-running Instruments, sleep/wake, distribution signing, notarization, TestFlight and Launch at Login checks remain outside this short phase.
- Battery is deliberately untouched. CPU/GPU frequency, temperature, fan and power work remain separate future tasks.

## Files changed

- New: `Sources/PulseBar/Services/AppProcessService.swift`, `Tests/PulseBarTests/AppProcessTests.swift`, this report.
- Models/protocols: `MonitoringReadings.swift`, `SystemSnapshot.swift`, `MonitoringProtocols.swift`.
- Integration/presentation: `SystemMonitorViewModel.swift`, `PlaceholderMonitoringServices.swift`, `DashboardView.swift`, `MetricFormatter.swift`.
- Refresh default: `MonitoringRefreshInterval.swift`, `PulseBarApp.swift`, `SettingsView.swift`.
- Test/build registration: `PulseBarTests.swift`, `PulseBar.xcodeproj/project.pbxproj`.
- Progress documents: `README.md`, `AUDIT.md`.

Phase checkpoint: `codex/phase-22-app-processes`. Previous checkpoint: `codex/phase-21-gpu-monitoring`.
