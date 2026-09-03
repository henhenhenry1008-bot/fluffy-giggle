protocol CPUProviding: Sendable {
  func readCPUUsage() async -> Double?
}

protocol PerCoreCPUProviding: Sendable {
  func readPerCoreCPUUsage() async -> [Double?]
}

protocol MemoryProviding: Sendable {
  func readMemory() async -> MemoryReading?
}

protocol NetworkProviding: Sendable {
  func readNetwork() async -> NetworkReading?
}

protocol DiskProviding: Sendable {
  func readDisk() async -> DiskReading?
  func readDiskThroughput() async -> DiskThroughputReading?
}

protocol BatteryProviding: Sendable {
  func readBattery() async -> BatteryReading?
}
