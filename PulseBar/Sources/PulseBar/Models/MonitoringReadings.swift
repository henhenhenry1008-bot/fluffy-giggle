struct AppProcessID: Hashable, Sendable {
  let pid: Int32
  let startSeconds: UInt64
  let startMicroseconds: UInt64
}

struct AppProcessReading: Identifiable, Equatable, Sendable {
  let id: AppProcessID
  let name: String
  let cpuUsage: Double?
  let residentBytes: UInt64
}

struct AppProcessListReading: Equatable, Sendable {
  let topProcesses: [AppProcessReading]
  let listedCount: Int
  let queriedCount: Int
  let readableCount: Int
}

struct GPUDeviceReading: Identifiable, Equatable, Sendable {
  let id: UInt64
  let name: String
  let usage: Double?
}

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
