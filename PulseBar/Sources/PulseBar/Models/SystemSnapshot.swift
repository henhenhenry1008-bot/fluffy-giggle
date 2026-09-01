import Foundation

struct SystemSnapshot: Identifiable, Equatable, Sendable {
  let id: UUID
  let timestamp: Date
  let cpuUsage: Double?
  let memoryUsed: UInt64?
  let memoryTotal: UInt64?
  let networkDownloadBytesPerSecond: Double?
  let networkUploadBytesPerSecond: Double?
  let diskUsed: UInt64?
  let diskTotal: UInt64?
  let batteryPercentage: Double?
  let batteryIsCharging: Bool?

  init(
    id: UUID = UUID(),
    timestamp: Date,
    cpuUsage: Double?,
    memoryUsed: UInt64?,
    memoryTotal: UInt64?,
    networkDownloadBytesPerSecond: Double?,
    networkUploadBytesPerSecond: Double?,
    diskUsed: UInt64?,
    diskTotal: UInt64?,
    batteryPercentage: Double?,
    batteryIsCharging: Bool?
  ) {
    self.id = id
    self.timestamp = timestamp
    self.cpuUsage = cpuUsage
    self.memoryUsed = memoryUsed
    self.memoryTotal = memoryTotal
    self.networkDownloadBytesPerSecond = networkDownloadBytesPerSecond
    self.networkUploadBytesPerSecond = networkUploadBytesPerSecond
    self.diskUsed = diskUsed
    self.diskTotal = diskTotal
    self.batteryPercentage = batteryPercentage
    self.batteryIsCharging = batteryIsCharging
  }

  static let empty = SystemSnapshot(
    timestamp: .now,
    cpuUsage: nil,
    memoryUsed: nil,
    memoryTotal: nil,
    networkDownloadBytesPerSecond: nil,
    networkUploadBytesPerSecond: nil,
    diskUsed: nil,
    diskTotal: nil,
    batteryPercentage: nil,
    batteryIsCharging: nil
  )
}
