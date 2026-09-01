import Foundation

struct SystemSnapshot: Identifiable, Equatable, Sendable {
  let id: UUID
  let timestamp: Date
  let cpuUsage: Double?
  let memoryUsed: UInt64?
  let memoryTotal: UInt64?
  let memoryAvailable: UInt64?
  let memoryFree: UInt64?
  let memoryActive: UInt64?
  let memoryInactive: UInt64?
  let memoryWired: UInt64?
  let memoryCompressed: UInt64?
  let memoryPurgeable: UInt64?
  let networkDownloadBytesPerSecond: Double?
  let networkUploadBytesPerSecond: Double?
  let diskUsed: UInt64?
  let diskTotal: UInt64?
  let diskAvailable: UInt64?
  let batteryPercentage: Double?
  let batteryIsCharging: Bool?
  let batteryIsFullyCharged: Bool?
  let batteryIsACPowered: Bool?

  init(
    id: UUID = UUID(),
    timestamp: Date,
    cpuUsage: Double?,
    memoryUsed: UInt64?,
    memoryTotal: UInt64?,
    memoryAvailable: UInt64?,
    memoryFree: UInt64?,
    memoryActive: UInt64?,
    memoryInactive: UInt64?,
    memoryWired: UInt64?,
    memoryCompressed: UInt64?,
    memoryPurgeable: UInt64?,
    networkDownloadBytesPerSecond: Double?,
    networkUploadBytesPerSecond: Double?,
    diskUsed: UInt64?,
    diskTotal: UInt64?,
    diskAvailable: UInt64?,
    batteryPercentage: Double?,
    batteryIsCharging: Bool?,
    batteryIsFullyCharged: Bool?,
    batteryIsACPowered: Bool?
  ) {
    self.id = id
    self.timestamp = timestamp
    self.cpuUsage = cpuUsage
    self.memoryUsed = memoryUsed
    self.memoryTotal = memoryTotal
    self.memoryAvailable = memoryAvailable
    self.memoryFree = memoryFree
    self.memoryActive = memoryActive
    self.memoryInactive = memoryInactive
    self.memoryWired = memoryWired
    self.memoryCompressed = memoryCompressed
    self.memoryPurgeable = memoryPurgeable
    self.networkDownloadBytesPerSecond = networkDownloadBytesPerSecond
    self.networkUploadBytesPerSecond = networkUploadBytesPerSecond
    self.diskUsed = diskUsed
    self.diskTotal = diskTotal
    self.diskAvailable = diskAvailable
    self.batteryPercentage = batteryPercentage
    self.batteryIsCharging = batteryIsCharging
    self.batteryIsFullyCharged = batteryIsFullyCharged
    self.batteryIsACPowered = batteryIsACPowered
  }

  static let empty = SystemSnapshot(
    timestamp: .now,
    cpuUsage: nil,
    memoryUsed: nil,
    memoryTotal: nil,
    memoryAvailable: nil,
    memoryFree: nil,
    memoryActive: nil,
    memoryInactive: nil,
    memoryWired: nil,
    memoryCompressed: nil,
    memoryPurgeable: nil,
    networkDownloadBytesPerSecond: nil,
    networkUploadBytesPerSecond: nil,
    diskUsed: nil,
    diskTotal: nil,
    diskAvailable: nil,
    batteryPercentage: nil,
    batteryIsCharging: nil,
    batteryIsFullyCharged: nil,
    batteryIsACPowered: nil
  )
}
