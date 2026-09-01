import Foundation

actor DiskService: DiskProviding {
  private let volumeURL: URL

  init(volumeURL: URL = URL(fileURLWithPath: "/", isDirectory: true)) {
    self.volumeURL = volumeURL
  }

  func readDisk() async -> DiskReading? {
    let keys: Set<URLResourceKey> = [
      .volumeTotalCapacityKey,
      .volumeAvailableCapacityKey,
    ]

    guard let values = try? volumeURL.resourceValues(forKeys: keys),
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

  static func makeReading(totalBytes: UInt64, availableBytes: UInt64) -> DiskReading? {
    guard totalBytes > 0 else { return nil }

    let clampedAvailableBytes = min(availableBytes, totalBytes)
    return DiskReading(
      usedBytes: totalBytes - clampedAvailableBytes,
      totalBytes: totalBytes,
      availableBytes: clampedAvailableBytes
    )
  }
}
