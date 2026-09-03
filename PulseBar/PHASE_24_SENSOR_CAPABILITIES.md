# Phase 24 — Advanced Sensor Capability Check

## Status: preflight complete; sensor implementation awaits authorization

This phase follows the original roadmap's remaining CPU/GPU frequency,
temperature, fan, and power items. It does **not** claim to implement those
features. Because website distribution and the Mac App Store are both planned,
we first checked the existing sandbox and data sources before changing any
production permissions or adding an experimental backend.

Verified on 2026-09-03: macOS 26.5 (25F71), Apple M5 Pro, Xcode 26.6 (17F113).
These observations describe this machine and permission context, not all Macs.

## Read-only probe results

The developer-only tool was built as an ad-hoc-signed app with the unchanged
`Config/PulseBar.entitlements`; signature inspection confirmed App Sandbox was
enabled. It ran as the ordinary user, not root. The probe makes no SMC sensor or
control requests: it only attempts to open/close a connection. It does not load
private frameworks or collect serial numbers or other unique device identifiers.

| Check | Observed result | Meaning |
| --- | --- | --- |
| `hw.cpufrequency`, `_min`, `_max` | Each returns `errno=2` | No frequency reading through these queries in this environment |
| AppleSMC service connection | `0xe00002e2`, `(iokit/common) not permitted` | Opening the connection is denied with the current permissions |
| Existing GPU `PerformanceStatistics` | No temperature/frequency/clock/power candidate keys | The currently used GPU payload offers no candidate for those metrics |
| `ProcessInfo.thermalState` | `0` / nominal | A system thermal-severity category, not CPU temperature in degrees |

No unsandboxed or privileged control run was performed. Consequently, this check
does not prove that removing the sandbox alone would make SMC available, or that
an available connection would provide accurate temperatures or fan speeds.
Sensor discovery, units, freshness, chip compatibility, and read-only command
validation would still be required before exposing any readings.

## Architecture and publication boundary

- Production source, build configuration, entitlements, and the runnable app are
  unchanged from Phase 23. The 0.5 / 1 / 2 / 5 second refresh options, two-second
  default, hardware auto-detection, and battery fix are retained.
- `Tools/` is outside both the Swift package target paths and Xcode source phases.
  The diagnostic tool is not shipped or launched by PulseBar and adds no timers,
  tasks, background helper, admin prompt, or sensor-control code to the app.
- The public [thermal-state API](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum)
  supplies categories; it must not be labeled as a measured CPU temperature.
- Apple's [App Sandbox guidance](https://developer.apple.com/documentation/security/discovering-and-diagnosing-app-sandbox-violations)
  describes capability limits and the need to choose an appropriate approach for
  restricted functionality. App Store [review rules](https://developer.apple.com/app-store/review/guidelines/)
  include sandbox and public-API requirements. Current experimental GPU driver
  fields also remain subject to a separate App Store compatibility review.
- Proposed next step, **not authorized or implemented here**: keep a sandboxed,
  public-API App Store configuration and evaluate a separate website-only build
  with a read-only experimental SMC backend. This would change that build's
  permission boundary and use an undocumented device protocol, so it needs an
  explicit user decision. No fan control, privileged helper, private framework,
  or root requirement is implicitly authorized by this proposal.
- Consent terms, localization, signing, notarization, and publishing remain
  deferred as requested by the user.

## Reproduce without changing PulseBar

From the `PulseBar` directory on a development Mac, use a fresh temporary directory:

```sh
probe_dir=$(mktemp -d /tmp/PulseBarSensorProbe.XXXXXX)
mkdir -p "$probe_dir/SensorCapabilityProbe.app/Contents/MacOS"
cp Tools/SensorCapabilityProbe-Info.plist "$probe_dir/SensorCapabilityProbe.app/Contents/Info.plist"
xcrun swiftc -parse-as-library -swift-version 6 -strict-concurrency=complete -warnings-as-errors Tools/SensorCapabilityProbe.swift -o "$probe_dir/SensorCapabilityProbe.app/Contents/MacOS/SensorCapabilityProbe"
codesign --force --sign - --options runtime --entitlements Config/PulseBar.entitlements "$probe_dir/SensorCapabilityProbe.app"
codesign --verify --strict "$probe_dir/SensorCapabilityProbe.app"
codesign -d --entitlements - "$probe_dir/SensorCapabilityProbe.app"
"$probe_dir/SensorCapabilityProbe.app/Contents/MacOS/SensorCapabilityProbe"
```

Keep the original sandbox entitlement. A denied connection is a useful result,
not a reason to retry with root, extra entitlements, or disabled protections.

## Verification and rough review

- Previous-stage review: core-count validation/caching, bounded enumeration,
  optional fallbacks, and central sampling remain intact; no new concrete issue
  was found in that short review.
- SwiftPM and Xcode Debug: all **59 tests pass** with warnings-as-errors and
  complete strict concurrency checks. No production feature was added, so the
  test count is unchanged.
- The standalone probe compiles with the same Swift checks and runs successfully
  as a sandboxed app while reporting the access denials above. Its exit code
  indicates that diagnostics ran, not that sensors are supported.
- Strict Swift formatting lint, plist validation, and `git diff --check` pass.
  Xcode still emits the unrelated App Intents metadata-skipping warning.
- The diagnostic uses bounded numeric/string handling and balances IOKit
  service/connection ownership. This is a capability check, not a sensor decoder
  audit or a long-running performance test.

## Files changed and rollback

- New: `Tools/SensorCapabilityProbe.swift`,
  `Tools/SensorCapabilityProbe-Info.plist`, this report.
- Updated: `README.md`, `AUDIT.md` for progress and the authorization boundary.
- No production files, user preferences, or existing runnable application were
  changed. The user's uncommitted Phase 22 document edits remain excluded.

Checkpoint branch: `codex/phase-24-sensor-capabilities`. Previous runnable feature
checkpoint: `codex/phase-23-cpu-topology`, commit `17dd487`.
