import Combine
import Foundation

@MainActor
final class SystemMonitorViewModel: ObservableObject {
  @Published private(set) var snapshot: SystemSnapshot
  @Published private(set) var isRefreshing = false
  @Published private(set) var isMonitoring = false
  @Published private(set) var refreshInterval: MonitoringRefreshInterval

  private var monitoringTask: Task<Void, Never>?
  private let cpuProvider: any CPUProviding
  private let memoryProvider: any MemoryProviding
  private let networkProvider: any NetworkProviding
  private let diskProvider: any DiskProviding
  private let batteryProvider: any BatteryProviding

  init(
    cpuProvider: any CPUProviding = CPUService(),
    memoryProvider: any MemoryProviding = MemoryService(),
    networkProvider: any NetworkProviding = NetworkService(),
    diskProvider: any DiskProviding = DiskService(),
    batteryProvider: any BatteryProviding = BatteryService(),
    initialSnapshot: SystemSnapshot = .empty,
    refreshInterval: MonitoringRefreshInterval = .oneSecond
  ) {
    self.cpuProvider = cpuProvider
    self.memoryProvider = memoryProvider
    self.networkProvider = networkProvider
    self.diskProvider = diskProvider
    self.batteryProvider = batteryProvider
    snapshot = initialSnapshot
    self.refreshInterval = refreshInterval
  }

  deinit {
    monitoringTask?.cancel()
  }

  func startMonitoring() {
    guard monitoringTask == nil else { return }

    isMonitoring = true
    monitoringTask = makeMonitoringTask(interval: refreshInterval)
  }

  func stopMonitoring() {
    monitoringTask?.cancel()
    monitoringTask = nil
    isMonitoring = false
  }

  func changeRefreshInterval(to interval: MonitoringRefreshInterval) {
    guard refreshInterval != interval else { return }

    refreshInterval = interval
    guard monitoringTask != nil else { return }

    // Cancellation wakes the old clock sleep immediately. A replacement task
    // starts with the new cadence, while refresh() prevents sampling overlap.
    monitoringTask?.cancel()
    monitoringTask = makeMonitoringTask(interval: interval)
  }

  private func makeMonitoringTask(
    interval: MonitoringRefreshInterval
  ) -> Task<Void, Never> {
    Task { [weak self] in
      let clock = ContinuousClock()
      var nextSample = clock.now

      while !Task.isCancelled {
        await self?.refresh()
        guard !Task.isCancelled else { break }

        nextSample = nextSample.advanced(by: interval.duration)

        let now = clock.now
        if nextSample <= now {
          // Skip missed deadlines instead of immediately running catch-up samples.
          nextSample = now.advanced(by: interval.duration)
        }

        do {
          try await clock.sleep(until: nextSample, tolerance: .milliseconds(50))
        } catch {
          break
        }
      }
    }
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

    // A canceled automatic sample should not publish after monitoring stops or
    // an interval change replaces its loop.
    guard !Task.isCancelled else { return }

    snapshot = SystemSnapshot(
      timestamp: .now,
      cpuUsage: values.0,
      memoryUsed: values.1?.usedBytes,
      memoryTotal: values.1?.totalBytes,
      memoryAvailable: values.1?.availableBytes,
      memoryFree: values.1?.freeBytes,
      memoryActive: values.1?.activeBytes,
      memoryInactive: values.1?.inactiveBytes,
      memoryWired: values.1?.wiredBytes,
      memoryCompressed: values.1?.compressedBytes,
      memoryPurgeable: values.1?.purgeableBytes,
      networkDownloadBytesPerSecond: values.2?.downloadBytesPerSecond,
      networkUploadBytesPerSecond: values.2?.uploadBytesPerSecond,
      diskUsed: values.3?.usedBytes,
      diskTotal: values.3?.totalBytes,
      diskAvailable: values.3?.availableBytes,
      batteryPercentage: values.4?.percentage,
      batteryIsCharging: values.4?.isCharging,
      batteryIsFullyCharged: values.4?.isFullyCharged,
      batteryIsACPowered: values.4?.isACPowered
    )
  }
}
