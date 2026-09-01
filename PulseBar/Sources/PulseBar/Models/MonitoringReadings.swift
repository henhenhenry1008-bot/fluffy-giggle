struct MemoryReading: Equatable, Sendable {
  let usedBytes: UInt64
  let totalBytes: UInt64
}

struct NetworkReading: Equatable, Sendable {
  let downloadBytesPerSecond: Double
  let uploadBytesPerSecond: Double
}

struct DiskReading: Equatable, Sendable {
  let usedBytes: UInt64
  let totalBytes: UInt64
}

struct BatteryReading: Equatable, Sendable {
  let percentage: Double
  let isCharging: Bool
}
