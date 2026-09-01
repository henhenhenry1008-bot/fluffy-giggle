# PulseBar

PulseBar is an original macOS 14+ menu bar system monitor built with Swift and SwiftUI.

## Phase one

This first phase establishes the application architecture and a compilable menu bar dashboard. All displayed measurements come from clearly named placeholder services. No hardware APIs, timers, charts, temperature sensors, or privileged operations are implemented yet.

The data flow is:

```text
Placeholder services -> SystemMonitorViewModel -> SystemSnapshot -> SwiftUI
```

## Build and test

```bash
swift build
swift test
```

Open `Package.swift` in Xcode and run the `PulseBar` executable scheme. A distributable `.app` target, signing settings, and launch-at-login support will be added in a later phase.
