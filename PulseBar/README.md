# PulseBar

PulseBar is an original macOS 14+ menu bar system monitor built with Swift and SwiftUI.

## Current status

The project has a compilable menu bar dashboard and a centralized one-second refresh loop. CPU usage is measured from real system-wide Mach tick counters. Memory, network, disk, and battery still come from clearly named placeholder services. Charts, temperature sensors, and privileged operations are not implemented yet.

The data flow is:

```text
Monitoring services -> SystemMonitorViewModel -> SystemSnapshot -> SwiftUI
```

## Build and test

```bash
swift build
swift test
```

Open `Package.swift` in Xcode and run the `PulseBar` executable scheme. A distributable `.app` target, signing settings, and launch-at-login support will be added in a later phase.
