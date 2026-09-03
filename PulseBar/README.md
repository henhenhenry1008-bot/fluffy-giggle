# PulseBar

PulseBar is an original macOS 14+ menu bar system monitor built with Swift and SwiftUI.

## Current status

The project has a compilable menu bar dashboard, one centralized and cancellable refresh loop, bounded real-time charts, and a native persistent Settings window. Users can configure refresh speed, history length, network units, appearance, Launch at Login, and which reusable metric components appear in the menu bar. Menu bar metrics use one stable CPU, memory, download, upload, and battery order, update immediately, and retain compact monospaced number presentation. Login-item registration and approval state come from `SMAppService`, with a direct link to the relevant System Settings panel when macOS requires user approval. Total and per-core CPU usage are measured from real Mach tick counters, memory usage comes from Mach VM statistics plus the physical memory size reported by `sysctl`, network throughput is calculated from native 64-bit BSD interface counters, disk capacity comes from Foundation volume resource values, and battery state comes from IOKit power source APIs. Batteryless Macs report the metric as unavailable. CPU frequency and core-type classification are not reported because macOS has no stable public API for those values; temperature sensors and privileged operations are not implemented yet.

The data flow is:

```text
Monitoring services -> SystemMonitorViewModel -> SystemSnapshot -> SwiftUI
```

Automatic sampling keeps total CPU, per-core CPU, memory, and network readings at the selected refresh interval. Disk capacity is refreshed at most every 30 seconds and battery state every 5 seconds, while a manual refresh updates every metric. Static memory configuration is cached after its first successful read, history storage remains bounded, and automatic samples publish one consolidated snapshot update to SwiftUI.

The Phase 14 optimization notes and remaining runtime profiling work are recorded in `PERFORMANCE.md`.

The Phase 15 full-project correctness review is recorded in `AUDIT.md`.

## Build and test

```bash
swift build
swift test
xcodebuild -project PulseBar.xcodeproj -scheme PulseBar -destination 'platform=macOS' build
```

Open `PulseBar.xcodeproj` in Xcode and run the `PulseBar` app scheme. The project includes a macOS application bundle, generated test bundle, hardened runtime, App Sandbox entitlement, menu-bar-only Info.plist configuration, and automatic signing settings. Select your Apple Developer team in Xcode before creating a signed archive for TestFlight.
