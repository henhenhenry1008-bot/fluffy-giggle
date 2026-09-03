struct MemoryReading: Equatable, Sendable {
  let usedBytes: UInt64
  let totalBytes: UInt64
  let availableBytes: UInt64
  let freeBytes: UInt64
  let activeBytes: UInt64
  let inactiveBytes: UInt64
  let cachedBytes: UInt64
  let wiredBytes: UInt64
  let compressedBytes: UInt64
  let purgeableBytes: UInt64
  let swapUsedBytes: UInt64?
  let swapTotalBytes: UInt64?
}

struct NetworkReading: Equatable, Sendable {
  let downloadBytesPerSecond: Double
  let uploadBytesPerSecond: Double
}

struct DiskReading: Equatable, Sendable {
  let usedBytes: UInt64
  let totalBytes: UInt64
  let availableBytes: UInt64
}

struct DiskThroughputReading: Equatable, Sendable {
  let readBytesPerSecond: Double
  let writeBytesPerSecond: Double
}

struct BatteryReading: Equatable, Sendable {
  let percentage: Double
  let isCharging: Bool
  let isFullyCharged: Bool
  let isACPowered: Bool
  let healthStatus: String?
  let timeToEmptyMinutes: Int?
  let timeToFullChargeMinutes: Int?
}
