import Combine
import Foundation

@MainActor
final class SystemMonitorViewModel: ObservableObject {
  @Published private(set) var snapshot: SystemSnapshot
  @Published private(set) var isRefreshing = false

  private var monitoringTask: Task<Void, Never>?
  private let cpuProvider: any CPUProviding
  private let memoryProvider: any MemoryProviding
  private let networkProvider: any NetworkProviding
  private let diskProvider: any DiskProviding
  private let batteryProvider: any BatteryProviding

  init(
    cpuProvider: any CPUProviding = CPUService(),
    memoryProvider: any MemoryProviding = PlaceholderMemoryService(),
    networkProvider: any NetworkProviding = PlaceholderNetworkService(),
    diskProvider: any DiskProviding = PlaceholderDiskService(),
    batteryProvider: any BatteryProviding = PlaceholderBatteryService(),
    initialSnapshot: SystemSnapshot = .empty
  ) {
    self.cpuProvider = cpuProvider
    self.memoryProvider = memoryProvider
    self.networkProvider = networkProvider
    self.diskProvider = diskProvider
    self.batteryProvider = batteryProvider
    snapshot = initialSnapshot
  }

  deinit {
    monitoringTask?.cancel()
  }

  func startMonitoring() {
    guard monitoringTask == nil else { return }

    monitoringTask = Task { [weak self] in
      let clock = ContinuousClock()
      let interval: Duration = .seconds(1)
      var nextSample = clock.now

      while !Task.isCancelled {
        await self?.refresh()
        nextSample = nextSample.advanced(by: interval)

        let now = clock.now
        if nextSample <= now {
          // Skip missed deadlines instead of immediately running catch-up samples.
          nextSample = now.advanced(by: interval)
        }

        do {
          try await clock.sleep(until: nextSample, tolerance: .milliseconds(50))
        } catch {
          break
        }
      }
    }
  }

  func stopMonitoring() {
    monitoringTask?.cancel()
    monitoringTask = nil
  }

  func refresh() async {
    guard !isRefreshing else { return }

    isRefreshing = true
    defer { isRefreshing = false }

    async let cpuUsage = cpuProvider.readCPUUsage()
    async let memory = memoryProvider.readMemory()
    async let network = networkProvider.readNetwork()
    async let disk = diskProvider.readDisk()
    async let battery = batteryProvider.readBattery()

    let values = await (cpuUsage, memory, network, disk, battery)

    snapshot = SystemSnapshot(
      timestamp: .now,
      cpuUsage: values.0,
      memoryUsed: values.1?.usedBytes,
      memoryTotal: values.1?.totalBytes,
      networkDownloadBytesPerSecond: values.2?.downloadBytesPerSecond,
      networkUploadBytesPerSecond: values.2?.uploadBytesPerSecond,
      diskUsed: values.3?.usedBytes,
      diskTotal: values.3?.totalBytes,
      batteryPercentage: values.4?.percentage,
      batteryIsCharging: values.4?.isCharging
    )
  }
}
