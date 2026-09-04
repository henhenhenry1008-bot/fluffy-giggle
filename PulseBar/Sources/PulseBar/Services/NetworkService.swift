import Darwin
import Foundation
import SystemConfiguration

struct NetworkInterfaceCounters: Equatable, Sendable {
  let receivedBytes: UInt64
  let sentBytes: UInt64
}

typealias NetworkCounterSnapshot = [UInt32: NetworkInterfaceCounters]

actor NetworkService: NetworkProviding {
  private let clock = ContinuousClock()
  private var previousCounters: NetworkCounterSnapshot?
  private var previousInstant: ContinuousClock.Instant?

  func readNetwork() async -> NetworkReading? {
    guard let currentCounters = Self.readInterfaceCounters() else {
      return nil
    }

    let currentInstant = clock.now
    defer {
      previousCounters = currentCounters
      previousInstant = currentInstant
    }

    guard let previousCounters, let previousInstant else {
      // Interface counters are cumulative, so the first sample establishes a baseline.
      return nil
    }

    return Self.makeReading(
      previous: previousCounters,
      current: currentCounters,
      elapsedSeconds: Self.seconds(in: previousInstant.duration(to: currentInstant))
    )
  }

  static func makeReading(
    previous: NetworkCounterSnapshot,
    current: NetworkCounterSnapshot,
    elapsedSeconds: Double
  ) -> NetworkReading? {
    guard elapsedSeconds.isFinite, elapsedSeconds > 0 else { return nil }

    var receivedDelta: UInt64 = 0
    var sentDelta: UInt64 = 0

    for (interfaceIndex, currentCounters) in current {
      guard let previousCounters = previous[interfaceIndex] else {
        // A new interface needs one complete sampling interval before it has a rate.
        continue
      }

      if let delta = counterDelta(
        previous: previousCounters.receivedBytes,
        current: currentCounters.receivedBytes
      ) {
        receivedDelta = saturatingAdd(receivedDelta, delta)
      }

      if let delta = counterDelta(
        previous: previousCounters.sentBytes,
        current: currentCounters.sentBytes
      ) {
        sentDelta = saturatingAdd(sentDelta, delta)
      }
    }

    let downloadBytesPerSecond = Double(receivedDelta) / elapsedSeconds
    let uploadBytesPerSecond = Double(sentDelta) / elapsedSeconds
    guard downloadBytesPerSecond.isFinite, uploadBytesPerSecond.isFinite else {
      return nil
    }

    return NetworkReading(
      downloadBytesPerSecond: downloadBytesPerSecond,
      uploadBytesPerSecond: uploadBytesPerSecond
    )
  }

  private static func readInterfaceCounters() -> NetworkCounterSnapshot? {
    guard let physicalInterfaces = physicalInterfaceIndices() else { return nil }
    guard let routingData = readRoutingData() else { return nil }

    return parseInterfaceCounters(routingData, physicalInterfaceIndices: physicalInterfaces)
  }

  // Use system-reported interface types, not a fixed en0 or an en* prefix:
  // Wi-Fi and external Ethernet adapters can have different BSD names.
  static func isPhysicalInterface(name: String?, type: String?, isLayered: Bool) -> Bool {
    guard let name, !name.isEmpty, let type, !isLayered else { return false }

    // These auxiliary Wi-Fi interfaces must not be added to the main radio's
    // counters, even if a future OS exposes them as a Wi-Fi/Ethernet type.
    guard !["awdl", "llw", "ap"].contains(where: { name.hasPrefix($0) }) else {
      return false
    }

    return [
      kSCNetworkInterfaceTypeEthernet as String,
      kSCNetworkInterfaceTypeIEEE80211 as String,
      kSCNetworkInterfaceTypeWWAN as String,
      kSCNetworkInterfaceTypeBluetooth as String,
      kSCNetworkInterfaceTypeFireWire as String,
    ].contains(type)
  }

  private static func physicalInterfaceIndices() -> Set<UInt32>? {
    guard let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else {
      return nil
    }

    var indices: Set<UInt32> = []
    for interface in interfaces {
      let name = SCNetworkInterfaceGetBSDName(interface) as String?
      guard
        isPhysicalInterface(
          name: name,
          type: SCNetworkInterfaceGetInterfaceType(interface) as String?,
          isLayered: SCNetworkInterfaceGetInterface(interface) != nil
        ), let name
      else { continue }

      let index = name.withCString { if_nametoindex($0) }
      if index != 0 { indices.insert(index) }
    }
    return indices
  }

  static func parseInterfaceCounters(
    _ routingData: [UInt8],
    physicalInterfaceIndices: Set<UInt32>
  ) -> NetworkCounterSnapshot? {

    var counters: NetworkCounterSnapshot = [:]
    let parsedSuccessfully = routingData.withUnsafeBytes { rawBuffer in
      var offset = 0

      while offset < rawBuffer.count {
        // Every routing message starts with length, version, and type fields.
        guard rawBuffer.count - offset >= 4 else { return false }

        let messageLength = Int(
          rawBuffer.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
        )
        let messageType = rawBuffer.loadUnaligned(
          fromByteOffset: offset + 3,
          as: UInt8.self
        )

        guard messageLength >= 4, messageLength <= rawBuffer.count - offset else {
          return false
        }

        if messageType == UInt8(RTM_IFINFO2) {
          guard messageLength >= MemoryLayout<if_msghdr2>.size else { return false }

          let header = rawBuffer.loadUnaligned(
            fromByteOffset: offset,
            as: if_msghdr2.self
          )
          let flags = header.ifm_flags

          // Sum physical links once. Adding a VPN/bridge/VLAN and its underlying
          // physical interface would count the same traffic at multiple layers.
          if physicalInterfaceIndices.contains(UInt32(header.ifm_index)),
            flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0
          {
            counters[UInt32(header.ifm_index)] = NetworkInterfaceCounters(
              receivedBytes: header.ifm_data.ifi_ibytes,
              sentBytes: header.ifm_data.ifi_obytes
            )
          }
        }

        offset += messageLength
      }

      return true
    }

    return parsedSuccessfully ? counters : nil
  }

  private static func readRoutingData() -> [UInt8]? {
    var managementInformationBase: [Int32] = [
      CTL_NET,
      PF_ROUTE,
      0,
      0,
      NET_RT_IFLIST2,
      0,
    ]

    // The interface list can change between the size query and data query.
    // Retry once if the original buffer becomes too small.
    for _ in 0..<2 {
      var byteCount = 0
      let sizeResult = managementInformationBase.withUnsafeMutableBufferPointer { mib in
        sysctl(mib.baseAddress, UInt32(mib.count), nil, &byteCount, nil, 0)
      }

      guard sizeResult == 0 else { return nil }
      guard byteCount > 0 else { return [] }

      var data = [UInt8](repeating: 0, count: byteCount)
      let dataResult = managementInformationBase.withUnsafeMutableBufferPointer { mib in
        data.withUnsafeMutableBytes { rawBuffer in
          sysctl(
            mib.baseAddress,
            UInt32(mib.count),
            rawBuffer.baseAddress,
            &byteCount,
            nil,
            0
          )
        }
      }

      if dataResult == 0 {
        if byteCount < data.count {
          data.removeSubrange(byteCount...)
        }
        return data
      }
    }

    return nil
  }

  private static func counterDelta(previous: UInt64, current: UInt64) -> UInt64? {
    guard current >= previous else {
      // A lower value indicates an interface reset or replacement. Skipping
      // this interval prevents an artificial speed spike.
      return nil
    }
    return current - previous
  }

  private static func saturatingAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
    let result = lhs.addingReportingOverflow(rhs)
    return result.overflow ? UInt64.max : result.partialValue
  }

  private static func seconds(in duration: Duration) -> Double {
    let components = duration.components
    return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
  }
}
