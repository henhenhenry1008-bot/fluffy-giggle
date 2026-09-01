protocol CPUProviding: Sendable {
  func readCPUUsage() async -> Double?
}

protocol MemoryProviding: Sendable {
  func readMemory() async -> MemoryReading?
}

protocol NetworkProviding: Sendable {
  func readNetwork() async -> NetworkReading?
}

protocol DiskProviding: Sendable {
  func readDisk() async -> DiskReading?
}

protocol BatteryProviding: Sendable {
  func readBattery() async -> BatteryReading?
}
