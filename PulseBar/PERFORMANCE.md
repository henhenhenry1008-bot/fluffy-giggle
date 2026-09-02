# Phase 14 Performance Review

## Changes

- Automatic sampling publishes one consolidated snapshot update instead of also toggling the manual-refresh activity state twice per sample.
- CPU, memory, and network continue to refresh at the user-selected interval. Disk capacity is sampled at most every 30 seconds and battery state every 5 seconds; a manual refresh bypasses both caches.
- Disk and battery work is only created when that reading is due. A normal cached cycle therefore creates three provider operations instead of five.
- A manual refresh requested during an automatic sample is coalesced and forced immediately afterward instead of overlapping or being dropped.
- Static physical-memory size and page-size configuration is cached after the first successful lookup. Dynamic VM statistics remain fresh on every sample.
- The disk resource-key set is reused, while chart history remains bounded by the configured ring-buffer capacity.

## Verification

- SwiftPM and Xcode unit tests cover automatic publication count, manual-refresh coalescing, slow-metric cadence, manual cache bypass, unavailable-battery caching, and clock rollback.
- Strict Swift concurrency and warnings-as-errors builds pass.
- The Release archive builds for both Apple Silicon and Intel architectures, and Xcode static analysis reports no findings.

## Remaining measurement

This phase removes identifiable redundant work but does not claim a measured CPU or memory percentage. Before release, profile a signed build during a long idle session with Instruments, test sleep/wake and network-interface changes, and confirm Launch at Login on a real signed installation.
