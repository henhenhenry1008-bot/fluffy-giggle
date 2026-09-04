# Network scope correction — 2026-09-04

## Problem and scope

The previous implementation summed every up, non-loopback interface from
`NET_RT_IFLIST2`. This included a VPN tunnel and its underlying physical link,
as well as Apple peer-to-peer traffic. This produced valid interface-counter
arithmetic but overstated a single-layer network total. A live check observed
about 41.9 KB/s on en0, 30.2 KB/s on utun10 and 6.4 KB/s on awdl0 while the old
service reported about 78.0 KB/s. The screenshot's earlier 104/140 KB/s cannot be
reconstructed retroactively.

## Correction

- Identify base network interfaces through `SCNetworkInterfaceCopyAll`,
  `SCNetworkInterfaceGetInterfaceType`, and `SCNetworkInterfaceGetBSDName`.
- Accept system-reported Ethernet, Wi-Fi, WWAN, Bluetooth and FireWire base
  types; reject layered or unknown types and Apple awdl/llw/ap auxiliary links.
- Resolve current interface indices each sample; do not hard-code en0, assume
  an en* prefix is physical, or keep a stale list after hot-plug changes.
- Read the same native 64-bit counters, selecting only eligible up,
  non-loopback interfaces. Do not fall back to all interfaces on discovery failure.
- Preserve elapsed-time normalization, counter-reset protection, and fresh
  baselines for newly appearing interfaces. No new timers or tasks are added.
- Add a dashboard help description explaining the physical-interface scope.
- Preserve the preceding decimal byte-unit correction and all refresh options.

Public API reference:
[SCNetworkInterfaceCopyAll](https://developer.apple.com/documentation/systemconfiguration/scnetworkinterfacecopyall()).
No private API, privileged helper, network setting change, or extra entitlement
is required for this correction.

## Validation

- SwiftPM and Xcode: all 67 working-tree tests pass with complete strict
  concurrency and warnings-as-errors (including 3 pre-existing sensor tests).
- The staged checkpoint was exported to a separate temporary directory, without
  any uncommitted sensor files: all 64 core tests also pass with the same checks.
- Xcode Debug build succeeds with the same Swift checks.
- New regression tests cover type-based selection independent of interface
  numbering, VPN/peer-to-peer/bridge exclusion, multiple physical interfaces,
  down/loopback filtering, malformed messages, offline and interface switching.
- Existing tests cover counter resets, new/removed interfaces, invalid elapsed
  time, overflow rejection, decimal units and menu-bar direction mapping.
- A read-only probe compiled the actual updated NetworkService and compared
  three sampling intervals with system `netstat` output. Example interval:
  en0 12.69/12.93 KB/s down/up; utun10 7.31/9.38 KB/s; the service now reports
  12.52/13.00 KB/s rather than the combined 20.00/22.32 KB/s. These independently
  timed snapshots are close comparisons, not packet-exact simultaneous samples.
- The normal locally signed App retains App Sandbox. Its actual dashboard
  displays nonzero KB/s readings and the new scope help, with no clipping
  observed in the network card. The old DecimalUnits test app was quit before
  opening the NetworkScope build.
- Swift formatting and `git diff --check` pass.

## Remaining limits and release boundary

The metric includes LAN traffic, VPN encapsulation overhead, and traffic on
multiple physical links. It is not unique application payload or Internet-only
throughput. A bridge forwarding between two physical links may contribute at
both physical ports, as expected for this metric's scope. Unknown future
interface types are excluded until validated. Wi-Fi with VPN is live-tested;
Ethernet hot-plug, multi-NIC, WWAN and older hardware are covered by synthetic
selection/delta tests, not physical-device validation in this run.

Changes are limited to NetworkService, network-card help, regression tests and
this documentation/README. Pre-existing experimental sensor changes and the
user's Phase 22 document edits are preserved, not audited or included by default.
The current app is a local test build, not a signed/notarized public installer.
No website publishing, App Store submission, consent flow or localization was
performed. Release preparation remains separate from this fix.

The local Git checkpoint groups this correction with the preceding decimal-unit
fix. Only the network-card help hunk is included from the already-dirty dashboard
file; existing sensor changes and the Phase 22 document are deliberately excluded.
The parent baseline is `14b20e1`. Use the isolated checkpoint's Git history for
recovery; do not reset or discard the surrounding unfinished work.
