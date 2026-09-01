# PulseBar

PulseBar is an original macOS 14+ menu bar system monitor built with Swift and SwiftUI.

## Current status

The project has a compilable menu bar dashboard and a centralized one-second refresh loop. CPU usage is measured from real system-wide Mach tick counters, memory usage comes from Mach VM statistics plus the physical memory size reported by `sysctl`, network throughput is calculated from native 64-bit BSD interface counters, and disk capacity comes from Foundation volume resource values. Battery still comes from a clearly named placeholder service. Charts, temperature sensors, and privileged operations are not implemented yet.

The data flow is:

```text
Monitoring services -> SystemMonitorViewModel -> SystemSnapshot -> SwiftUI
```

## Build and test

```bash
swift build
swift test
xcodebuild -project PulseBar.xcodeproj -scheme PulseBar -destination 'platform=macOS' build
```

Open `PulseBar.xcodeproj` in Xcode and run the `PulseBar` app scheme. The project includes a macOS application bundle, generated test bundle, hardened runtime, App Sandbox entitlement, menu-bar-only Info.plist configuration, and automatic signing settings. Select your Apple Developer team in Xcode before creating a signed archive for TestFlight.
