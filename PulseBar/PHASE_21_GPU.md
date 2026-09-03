# Phase 21 — Experimental GPU Monitoring

## Scope and current environment

This phase adds per-device GPU usage and history, using the read-only undocumented driver fields discussed with the user. It does not add GPU frequency, temperature, memory usage, power, fan control, private frameworks, or privileged helpers.

Verified on 2026-09-03 with:

- macOS 26.5 (25F71)
- Xcode 26.6 (17F113), macOS SDK 26.5, Swift 6.3.3
- Apple M5 Pro

The deployment minimum remains macOS 14. Both architectures compile; runtime compatibility has only been verified on the environment above. No OS update, permission change, or automatic update-monitoring task was installed.

## Data source and architecture

`GPUService` is an actor implementing `GPUProviding`. It uses public Metal device enumeration and each device's [registry ID](https://developer.apple.com/documentation/metal/mtldevice/registryid) to find the corresponding IOKit entry. Public [IOKit matching](https://developer.apple.com/documentation/iokit/1514880-ioregistryentryidmatching) and [property-reading functions](https://developer.apple.com/documentation/iokit/1514293-ioregistryentrycreatecfproperty/) access this driver payload:

```text
PerformanceStatistics
└── Device Utilization %
```

The payload keys and their meaning are not a stable documented Apple API contract. Their continued availability and accuracy need revalidation after system updates. Metal is used only to identify devices, not to generate GPU work or report PulseBar's own resource usage as system-wide usage.

- Accept only numeric, finite percentages in 0...100, normalized to 0...1. Boolean, string, missing, out-of-range, and non-finite values are unavailable, not zero.
- The driver supplies a percentage, not a cumulative counter. Do not calculate a counter delta, add renderer/tiler percentages, or sum different GPUs.
- Re-enumerate devices each sample to handle removal/addition. Sort by registry ID; match historical values by ID instead of array position.
- Keep all IOKit handles and Metal objects local to a sample. Release returned IOKit handles and consume retained CF properties correctly.
- Use the existing centralized sampling loop and bounded snapshot history. No new timers, detached tasks, or background monitoring loops.
- Dashboard shows each device's name, percentage, and 0–100% history, labeled `Experimental · Driver-reported`. Missing readings show `Unavailable`.
- A 520-point scrolling content area accommodates the extra card while keeping the header and footer visible. Colors remain system-adaptive.

## Verification and rough review

- SwiftPM Debug: 40/40 tests pass with warnings-as-errors and complete strict concurrency checking.
- Xcode Debug: 40/40 tests pass with the same checks; static analysis passes.
- SwiftPM Release build and Xcode universal Release archive pass. `lipo` confirms `arm64` and `x86_64`.
- Strict formatting lint, project-file plist validation, and `git diff --check` pass.
- No Swift compiler or concurrency warnings were reported.
- A temporary ad-hoc-signed app compiled the actual `GPUService` with the unchanged project sandbox entitlement. Signature verification confirmed `com.apple.security.app-sandbox = true`; three consecutive live GPU samples were present, finite, and in range.
- New regression coverage checks malformed payloads, zero versus unavailable, changing/reordered device IDs, missing counters, device removal, bounded GPU history, and automatic/manual sampling.
- No additional concrete defects were found in the short review. Existing CPU, memory, network, disk, battery, settings, and monitoring-lifecycle tests remain passing.

The temporary probe is a verification artifact, not a production helper. The production app still uses its original sandbox entitlement and does not request administrator privileges.

## Remaining limitations

- Unsupported drivers or restricted environments can return no Metal devices or omit the utilization field. The UI degrades to `Unavailable`.
- Driver averaging windows and freshness are undocumented. Sampling faster does not guarantee a new driver measurement each time.
- Tests validate normalization and isolation, not the absolute accuracy of the driver's utilization formula.
- Intel/multi-GPU/eGPU hardware, older macOS versions, and future OS releases have not been physically tested. Device-change behavior is covered with mocked readings.
- Manual Light/Dark appearance, long device names, scrolling on small displays, and accessibility text sizes still need a UI check. Long-running Instruments and sleep/wake checks are deferred.
- TestFlight/App Store acceptance, distribution signing, and notarization are not established by these builds or the sandbox probe.

## Recheck after a system update

1. Record the new macOS, SDK, and Xcode versions.
2. Run `swift test` and the Xcode tests with warnings-as-errors.
3. Verify that a sandboxed build still reads each expected GPU, and that unavailable data is not displayed as 0%.
4. Compare trends under ordinary GPU activity with Activity Monitor, allowing for different sampling windows.
5. Check sleep/wake, applicable device changes, and idle resource usage before treating the new system as verified.

Keep unverified behavior labeled experimental. Do not silently substitute undocumented counters with different meanings.

## Files changed

- New: `Sources/PulseBar/Services/GPUService.swift`, `PHASE_21_GPU.md`.
- Models/protocols: `MonitoringReadings.swift`, `SystemSnapshot.swift`, `MonitoringProtocols.swift`.
- Integration: `PlaceholderMonitoringServices.swift`, `SystemMonitorViewModel.swift`, `DashboardView.swift`.
- Tests/build: `PulseBarTests.swift`, `PulseBar.xcodeproj/project.pbxproj`.
- Documentation: `README.md`, `AUDIT.md`.

Phase checkpoint: `codex/phase-21-gpu-monitoring`. Prior checkpoint: `codex/phase-20-battery-health-estimates`.
