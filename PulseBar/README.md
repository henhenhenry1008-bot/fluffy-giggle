# PulseBar

PulseBar is an original macOS 14+ menu bar system monitor built with Swift and SwiftUI.

## Current status

The project has a compilable menu bar dashboard, one centralized and cancellable refresh loop, bounded real-time charts, and a native persistent Settings window. Users can configure refresh speed, history length, network units, appearance, Launch at Login, and which reusable metric components appear in the menu bar. Menu bar metrics use one stable CPU, memory, download, upload, and battery order, update immediately, and retain compact monospaced number presentation. Login-item registration and approval state come from `SMAppService`, with a direct link to the relevant System Settings panel when macOS requires user approval. Total and per-core CPU usage are measured from real Mach tick counters. Memory usage, cached file-backed pages, wired memory, compressed memory, and Swap usage come from Mach VM statistics and public `sysctl` values. Network throughput is calculated from native 64-bit BSD interface counters. Disk capacity comes from Foundation volume resource values, while system-wide disk read and write throughput is calculated from public IOKit block-storage counters; systems that do not expose these counters report throughput as unavailable. Battery percentage, power state, health status, and charge/discharge time estimates come from public IOKit power source APIs, and batteryless Macs report the metric as unavailable. CPU hardware composition is now reported by performance level; exact type assignment to the per-core usage bars remains unverified. CPU frequency, temperature sensors, and privileged operations are not implemented yet.

The data flow is:

```text
Monitoring services -> SystemMonitorViewModel -> SystemSnapshot -> SwiftUI
```

Experimental GPU monitoring identifies devices with Metal and reads each device's undocumented IOKit `PerformanceStatistics` / `Device Utilization %` field. Each GPU gets its own usage value and history; missing or malformed values are unavailable. The backend remains read-only and sandboxed, but driver compatibility is not guaranteed across macOS updates. See `PHASE_21_GPU.md` for verified system versions, limitations, and the update recheck checklist.

Automatic sampling keeps total CPU, per-core CPU, GPU, memory, network, and disk-throughput readings at the selected refresh interval. Disk capacity is refreshed at most every 30 seconds and battery state every 5 seconds, while a manual refresh updates every metric. Static memory configuration is cached after its first successful read, history storage remains bounded, and automatic samples publish one consolidated snapshot update to SwiftUI.

Phase 22 adds an application-process Top CPU list, with resident memory and readable/listed coverage counts. It uses public workspace/task APIs with the existing sandbox, follows the selected refresh interval, and keeps only five rows per snapshot. All four refresh options remain available: **0.5, 1, 2 and 5 seconds**, with **2 seconds as the default**; existing saved choices are preserved. CPU percentages use one core as 100% and may exceed it. This is not a full system process list or an aggregate of each app's helper processes. Battery behavior is unchanged. See [PHASE_22_APP_PROCESSES.md](PHASE_22_APP_PROCESSES.md) for the scope, 47-test verification, and remaining limitations.

Phase 23 adds physical/logical CPU totals and system-reported performance-level composition. The current Mac reports 6 Super and 12 Performance cores; the app does not assume every chip has Efficiency cores or map types onto Mach core indices. Counts use documented `sysctlbyname` keys; optional names fall back to `Level N`. Hardware composition is cached per app session, and incomplete breakdowns remain unavailable. All 59 tests pass in SwiftPM and Xcode. See [PHASE_23_CPU_TOPOLOGY.md](PHASE_23_CPU_TOPOLOGY.md) for the review, API evidence, changed files, and limitations. The battery compatibility fix is retained unchanged.

The Phase 14 optimization notes and remaining runtime profiling work are recorded in `PERFORMANCE.md`.

The Phase 15 full-project correctness review and Phase 20 battery-details completion review are recorded in `AUDIT.md`.

## Build and test

For the local UI handoff, double-click `运行版/PulseBar.app` in this project folder. This generated app is locally signed with the existing sandbox entitlement and is not committed to Git. It is for testing on this Mac, not a notarized distribution build. The app now opens a normal dashboard window on launch; the menu-bar panel's window button can reopen it. Both surfaces share the same view model and monitoring task. Closing the dashboard leaves menu-bar monitoring running; use **Quit PulseBar** to stop the app. Scroll the dashboard to see GPU, network, and application-process cards, and open **Settings** to choose 0.5, 1, 2 or 5 seconds (default: 2).

```bash
swift build
swift test
xcodebuild -project PulseBar.xcodeproj -scheme PulseBar -destination 'platform=macOS' build
```

Open `PulseBar.xcodeproj` in Xcode and run the `PulseBar` app scheme. The project includes a macOS application bundle, generated test bundle, hardened runtime, App Sandbox entitlement, menu-bar-only Info.plist configuration, and automatic signing settings. Select your Apple Developer team in Xcode before creating a signed archive for TestFlight.
