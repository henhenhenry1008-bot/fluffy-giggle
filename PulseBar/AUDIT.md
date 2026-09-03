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
