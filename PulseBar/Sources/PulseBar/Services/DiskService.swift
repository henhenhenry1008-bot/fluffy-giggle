import Foundation
import IOKit

struct DiskDeviceCounters: Equatable, Sendable {
  let readBytes: UInt64
  let writtenBytes: UInt64
}

typealias DiskCounterSnapshot = [UInt64: DiskDeviceCounters]

actor DiskService: DiskProviding {
  private static let capacityResourceKeys: Set<URLResourceKey> = [
    .volumeTotalCapacityKey,
    .volumeAvailableCapacityKey,
  ]

  private static let blockStorageDriverClass = "IOBlockStorageDriver"
  private static let statisticsKey = "Statistics"
  private static let bytesReadKey = "Bytes (Read)"
  private static let bytesWrittenKey = "Bytes (Write)"

  private let volumeURL: URL
  private let clock = ContinuousClock()
  private var previousCounters: DiskCounterSnapshot?
  private var previousInstant: ContinuousClock.Instant?

  init(volumeURL: URL = URL(fileURLWithPath: "/", isDirectory: true)) {
    self.volumeURL = volumeURL
  }

  func readDisk() async -> DiskReading? {
    guard let values = try? volumeURL.resourceValues(forKeys: Self.capacityResourceKeys),
      let totalCapacity = values.volumeTotalCapacity,
      let availableCapacity = values.volumeAvailableCapacity,
      totalCapacity > 0,
      availableCapacity >= 0
    else {
      return nil
    }

    // URL resource values query the mounted system volume directly. APFS may
    // report shared-container capacity, which is the useful value for showing
    // how much space remains available to the user.
    return Self.makeReading(
      totalBytes: UInt64(totalCapacity),
      availableBytes: UInt64(availableCapacity)
    )
  }

  func readDiskThroughput() async -> DiskThroughputReading? {
    guard let currentCounters = Self.readDeviceCounters() else {
      return nil
    }

    let currentInstant = clock.now
    defer {
      previousCounters = currentCounters
      previousInstant = currentInstant
    }

    guard let previousCounters, let previousInstant else {
      // Storage counters are cumulative, so the first sample is only a baseline.
      return nil
    }

    return Self.makeThroughputReading(
      previous: previousCounters,
      current: currentCounters,
      elapsedSeconds: Self.seconds(in: previousInstant.duration(to: currentInstant))
    )
  }

  static func makeReading(totalBytes: UInt64, availableBytes: UInt64) -> DiskReading? {
    guard totalBytes > 0 else { return nil }

    let clampedAvailableBytes = min(availableBytes, totalBytes)
    return DiskReading(
      usedBytes: totalBytes - clampedAvailableBytes,
      totalBytes: totalBytes,
      availableBytes: clampedAvailableBytes
    )
  }

  static func makeThroughputReading(
    previous: DiskCounterSnapshot,
    current: DiskCounterSnapshot,
    elapsedSeconds: Double
  ) -> DiskThroughputReading? {
    guard elapsedSeconds.isFinite, elapsedSeconds > 0 else { return nil }

    var readDelta: UInt64 = 0
    var writtenDelta: UInt64 = 0

    for (deviceID, currentCounters) in current {
      guard let previousCounters = previous[deviceID] else {
        // New devices need a complete sampling interval before contributing.
        continue
      }

      if let delta = counterDelta(
        previous: previousCounters.readBytes,
        current: currentCounters.readBytes
      ) {
        readDelta = saturatingAdd(readDelta, delta)
      }

      if let delta = counterDelta(
        previous: previousCounters.writtenBytes,
        current: currentCounters.writtenBytes
      ) {
        writtenDelta = saturatingAdd(writtenDelta, delta)
      }
    }

    let readBytesPerSecond = Double(readDelta) / elapsedSeconds
    let writeBytesPerSecond = Double(writtenDelta) / elapsedSeconds
    guard readBytesPerSecond.isFinite, writeBytesPerSecond.isFinite else {
      return nil
    }

    return DiskThroughputReading(
      readBytesPerSecond: readBytesPerSecond,
      writeBytesPerSecond: writeBytesPerSecond
    )
  }

  private static func readDeviceCounters() -> DiskCounterSnapshot? {
    guard let matchingDictionary = IOServiceMatching(blockStorageDriverClass) else {
      return nil
    }

    var iterator: io_iterator_t = 0
    guard
      IOServiceGetMatchingServices(
        kIOMainPortDefault,
        matchingDictionary,
        &iterator
      ) == KERN_SUCCESS
    else {
      return nil
    }
    defer { IOObjectRelease(iterator) }

    var counters: DiskCounterSnapshot = [:]
    var service = IOIteratorNext(iterator)
    while service != 0 {
      defer {
        IOObjectRelease(service)
        service = IOIteratorNext(iterator)
      }

      var deviceID: UInt64 = 0
      guard IORegistryEntryGetRegistryEntryID(service, &deviceID) == KERN_SUCCESS,
        let statistics = IORegistryEntryCreateCFProperty(
          service,
          statisticsKey as CFString,
          kCFAllocatorDefault,
          0
        )?.takeRetainedValue() as? [String: Any],
        let readBytes = statistics[bytesReadKey] as? NSNumber,
        let writtenBytes = statistics[bytesWrittenKey] as? NSNumber
      else {
        continue
      }

      counters[deviceID] = DiskDeviceCounters(
        readBytes: readBytes.uint64Value,
        writtenBytes: writtenBytes.uint64Value
      )
    }

    return counters.isEmpty ? nil : counters
  }

  private static func counterDelta(previous: UInt64, current: UInt64) -> UInt64? {
    guard current >= previous else {
      // A lower value means that the device or its counters were reset.
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
