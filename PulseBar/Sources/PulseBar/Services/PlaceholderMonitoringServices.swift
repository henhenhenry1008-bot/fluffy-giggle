private enum PlaceholderUnits {
  static let kibibyte: UInt64 = 1_024
  static let mebibyte = kibibyte * 1_024
  static let gibibyte = mebibyte * 1_024
}

struct PlaceholderCPUService: CPUProviding {
  let usage: Double

  init(usage: Double = 0.32) {
    self.usage = usage
  }

  func readCPUUsage() async -> Double? {
    usage
  }
}

struct PlaceholderMemoryService: MemoryProviding {
  func readMemory() async -> MemoryReading? {
    let total = 18 * PlaceholderUnits.gibibyte
    let used = UInt64(9.2 * Double(PlaceholderUnits.gibibyte))

    return MemoryReading(
      usedBytes: used,
      totalBytes: total,
      availableBytes: total - used,
      freeBytes: 2 * PlaceholderUnits.gibibyte,
      activeBytes: 6 * PlaceholderUnits.gibibyte,
      inactiveBytes: 4 * PlaceholderUnits.gibibyte,
      wiredBytes: 2 * PlaceholderUnits.gibibyte,
      compressedBytes: PlaceholderUnits.gibibyte,
      purgeableBytes: PlaceholderUnits.gibibyte / 2
    )
  }
}

struct PlaceholderNetworkService: NetworkProviding {
  func readNetwork() async -> NetworkReading? {
    NetworkReading(
      downloadBytesPerSecond: 2.4 * Double(PlaceholderUnits.mebibyte),
      uploadBytesPerSecond: 820 * Double(PlaceholderUnits.kibibyte)
    )
  }
}

struct PlaceholderDiskService: DiskProviding {
  func readDisk() async -> DiskReading? {
    DiskReading(
      usedBytes: 243 * PlaceholderUnits.gibibyte,
      totalBytes: 494 * PlaceholderUnits.gibibyte,
      availableBytes: 251 * PlaceholderUnits.gibibyte
    )
  }
}

struct PlaceholderBatteryService: BatteryProviding {
  func readBattery() async -> BatteryReading? {
    BatteryReading(percentage: 0.83, isCharging: true)
  }
}
