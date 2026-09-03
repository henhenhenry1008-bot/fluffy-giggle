# PulseBar

PulseBar is an original macOS 14+ menu bar system monitor built with Swift and SwiftUI.

## Current status

The project has a compilable menu bar dashboard, one centralized and cancellable refresh loop, bounded real-time charts, and a native persistent Settings window. Users can configure refresh speed, history length, network units, appearance, Launch at Login, and which reusable metric components appear in the menu bar. Menu bar metrics use one stable CPU, memory, download, upload, and battery order, update immediately, and retain compact monospaced number presentation. Login-item registration and approval state come from `SMAppService`, with a direct link to the relevant System Settings panel when macOS requires user approval. Total and per-core CPU usage are measured from real Mach tick counters. Memory usage, cached file-backed pages, wired memory, compressed memory, and Swap usage come from Mach VM statistics and public `sysctl` values. Network throughput is calculated from native 64-bit BSD interface counters. Disk capacity comes from Foundation volume resource values, while system-wide disk read and write throughput is calculated from public IOKit block-storage counters; systems that do not expose these counters report throughput as unavailable. Battery percentage, power state, health status, and charge/discharge time estimates come from public IOKit power source APIs, and batteryless Macs report the metric as unavailable. CPU frequency and core-type classification are not reported because macOS has no stable public API for those values; temperature sensors and privileged operations are not implemented yet.

The data flow is:

```text
Monitoring services -> SystemMonitorViewModel -> SystemSnapshot -> SwiftUI
```

Experimental GPU monitoring identifies devices with Metal and reads each device's undocumented IOKit `PerformanceStatistics` / `Device Utilization %` field. Each GPU gets its own usage value and history; missing or malformed values are unavailable. The backend remains read-only and sandboxed, but driver compatibility is not guaranteed across macOS updates. See `PHASE_21_GPU.md` for verified system versions, limitations, and the update recheck checklist.

Automatic sampling keeps total CPU, per-core CPU, GPU, memory, network, and disk-throughput readings at the selected refresh interval. Disk capacity is refreshed at most every 30 seconds and battery state every 5 seconds, while a manual refresh updates every metric. Static memory configuration is cached after its first successful read, history storage remains bounded, and automatic samples publish one consolidated snapshot update to SwiftUI.

Phase 22 adds an application-process Top CPU list, with resident memory and readable/listed coverage counts. It uses public workspace/task APIs with the existing sandbox, follows the selected refresh interval, and keeps only five rows per snapshot. All four refresh options remain available: **0.5, 1, 2 and 5 seconds**, with **2 seconds as the default**; existing saved choices are preserved. CPU percentages use one core as 100% and may exceed it. This is not a full system process list or an aggregate of each app's helper processes. Battery behavior is unchanged. See [PHASE_22_APP_PROCESSES.md](PHASE_22_APP_PROCESSES.md) for the scope, 47-test verification, and remaining limitations.

The Phase 14 optimization notes and remaining runtime profiling work are recorded in `PERFORMANCE.md`.

The Phase 15 full-project correctness review and Phase 20 battery-details completion review are recorded in `AUDIT.md`.

## Build and test

```bash
swift build
swift test
xcodebuild -project PulseBar.xcodeproj -scheme PulseBar -destination 'platform=macOS' build
```

Open `PulseBar.xcodeproj` in Xcode and run the `PulseBar` app scheme. The project includes a macOS application bundle, generated test bundle, hardened runtime, App Sandbox entitlement, menu-bar-only Info.plist configuration, and automatic signing settings. Select your Apple Developer team in Xcode before creating a signed archive for TestFlight.
