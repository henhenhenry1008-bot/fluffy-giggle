import Combine
import Foundation

@MainActor
final class SystemMonitorViewModel: ObservableObject {
  static let defaultDiskRefreshInterval: TimeInterval = 30
  static let defaultBatteryRefreshInterval: TimeInterval = 5

  @Published private(set) var snapshot: SystemSnapshot
  @Published private(set) var isRefreshing = false
  @Published private(set) var isMonitoring = false
  @Published private(set) var refreshInterval: MonitoringRefreshInterval
  private(set) var history: RingBuffer<SystemSnapshot>

  private var monitoringTask: Task<Void, Never>?
  private var isSampling = false
  private var hasPendingManualRefresh = false
  private var diskCache: CachedReading<DiskReading>?
  private var batteryCache: CachedReading<BatteryReading>?
  private let cpuProvider: any CPUProviding
  private let perCoreCPUProvider: any PerCoreCPUProviding
  private let gpuProvider: any GPUProviding
  private let memoryProvider: any MemoryProviding
  private let networkProvider: any NetworkProviding
  private let diskProvider: any DiskProviding
  private let batteryProvider: any BatteryProviding
  private let now: () -> Date
  private let diskRefreshInterval: TimeInterval
  private let batteryRefreshInterval: TimeInterval

  init(
    cpuProvider: any CPUProviding = CPUService(),
    perCoreCPUProvider: any PerCoreCPUProviding = PerCoreCPUService(),
    gpuProvider: any GPUProviding = GPUService(),
    memoryProvider: any MemoryProviding = MemoryService(),
    networkProvider: any NetworkProviding = NetworkService(),
    diskProvider: any DiskProviding = DiskService(),
    batteryProvider: any BatteryProviding = BatteryService(),
    initialSnapshot: SystemSnapshot = .empty,
    refreshInterval: MonitoringRefreshInterval = .oneSecond,
    historyCapacity: Int = 120,
    diskRefreshInterval: TimeInterval = defaultDiskRefreshInterval,
    batteryRefreshInterval: TimeInterval = defaultBatteryRefreshInterval,
    now: @escaping () -> Date = { .now }
  ) {
    self.cpuProvider = cpuProvider
    self.perCoreCPUProvider = perCoreCPUProvider
    self.gpuProvider = gpuProvider
    self.memoryProvider = memoryProvider
    self.networkProvider = networkProvider
    self.diskProvider = diskProvider
    self.batteryProvider = batteryProvider
    snapshot = initialSnapshot
    self.refreshInterval = refreshInterval
    history = RingBuffer(capacity: historyCapacity)
    self.diskRefreshInterval = Swift.max(diskRefreshInterval, 0)
    self.batteryRefreshInterval = Swift.max(batteryRefreshInterval, 0)
    self.now = now
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
    // starts with the new cadence, while the sampling guard prevents overlap.
    monitoringTask?.cancel()
    monitoringTask = makeMonitoringTask(interval: interval)
  }

  func changeHistoryCapacity(to capacity: Int) {
    let normalizedCapacity = Swift.max(capacity, 0)
    guard history.capacity != normalizedCapacity else { return }

    objectWillChange.send()
    history.resize(to: normalizedCapacity)
  }

  private func makeMonitoringTask(
    interval: MonitoringRefreshInterval
  ) -> Task<Void, Never> {
    Task { [weak self] in
      let clock = ContinuousClock()
      var nextSample = clock.now

      while !Task.isCancelled {
        await self?.refreshForMonitoring()
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
    guard !isSampling else {
      // Coalesce clicks that arrive during a sample, then force every metric
      // once the in-flight work has finished.
      hasPendingManualRefresh = true
      return
    }

    await performRefresh(reportsActivity: true, refreshesSlowMetrics: true)
  }

  func refreshForMonitoring() async {
    await performRefresh(reportsActivity: false, refreshesSlowMetrics: false)
  }

  private func performRefresh(
    reportsActivity: Bool,
    refreshesSlowMetrics: Bool
  ) async {
    guard !isSampling else { return }

    isSampling = true
    if reportsActivity {
      isRefreshing = true
    }
    defer {
      if reportsActivity {
        isRefreshing = false
      }
      isSampling = false

      if hasPendingManualRefresh {
        hasPendingManualRefresh = false
        Task { [weak self] in
          await self?.refresh()
        }
      }
    }

    let sampleTime = now()
    let refreshesDisk =
      refreshesSlowMetrics
      || Self.shouldRefresh(
        lastRefresh: diskCache?.timestamp,
        at: sampleTime,
        minimumInterval: diskRefreshInterval
      )
    let refreshesBattery =
      refreshesSlowMetrics
      || Self.shouldRefresh(
        lastRefresh: batteryCache?.timestamp,
        at: sampleTime,
        minimumInterval: batteryRefreshInterval
      )

    async let cpuUsage = cpuProvider.readCPUUsage()
    async let cpuCoreUsages = perCoreCPUProvider.readPerCoreCPUUsage()
    async let gpuDevices = gpuProvider.readGPUs()
    async let memory = memoryProvider.readMemory()
    async let network = networkProvider.readNetwork()
    async let diskThroughput = diskProvider.readDiskThroughput()

    var disk = diskCache?.value
    var battery = batteryCache?.value

    if refreshesDisk, refreshesBattery {
      async let updatedDisk = diskProvider.readDisk()
      async let updatedBattery = batteryProvider.readBattery()
      (disk, battery) = await (updatedDisk, updatedBattery)
    } else if refreshesDisk {
      disk = await diskProvider.readDisk()
    } else if refreshesBattery {
      battery = await batteryProvider.readBattery()
    }

    let (
      latestCPUUsage, latestCoreUsages, latestGPUs, latestMemory, latestNetwork,
      latestDiskThroughput
    ) =
      await (cpuUsage, cpuCoreUsages, gpuDevices, memory, network, diskThroughput)

    // A canceled automatic sample should not publish after monitoring stops or
    // an interval change replaces its loop.
    guard !Task.isCancelled else { return }

    if refreshesDisk {
      diskCache = CachedReading(value: disk, timestamp: sampleTime)
    }
    if refreshesBattery {
      batteryCache = CachedReading(value: battery, timestamp: sampleTime)
    }

    let nextSnapshot = SystemSnapshot(
      timestamp: sampleTime,
      cpuUsage: latestCPUUsage,
      cpuCoreUsages: latestCoreUsages,
      gpuDevices: latestGPUs,
      memoryUsed: latestMemory?.usedBytes,
      memoryTotal: latestMemory?.totalBytes,
      memoryAvailable: latestMemory?.availableBytes,
      memoryFree: latestMemory?.freeBytes,
      memoryActive: latestMemory?.activeBytes,
      memoryInactive: latestMemory?.inactiveBytes,
      memoryCached: latestMemory?.cachedBytes,
      memoryWired: latestMemory?.wiredBytes,
      memoryCompressed: latestMemory?.compressedBytes,
      memoryPurgeable: latestMemory?.purgeableBytes,
      swapUsed: latestMemory?.swapUsedBytes,
      swapTotal: latestMemory?.swapTotalBytes,
      networkDownloadBytesPerSecond: latestNetwork?.downloadBytesPerSecond,
      networkUploadBytesPerSecond: latestNetwork?.uploadBytesPerSecond,
      diskUsed: disk?.usedBytes,
      diskTotal: disk?.totalBytes,
      diskAvailable: disk?.availableBytes,
      diskReadBytesPerSecond: latestDiskThroughput?.readBytesPerSecond,
      diskWriteBytesPerSecond: latestDiskThroughput?.writeBytesPerSecond,
      batteryPercentage: battery?.percentage,
      batteryIsCharging: battery?.isCharging,
      batteryIsFullyCharged: battery?.isFullyCharged,
      batteryIsACPowered: battery?.isACPowered,
      batteryHealthStatus: battery?.healthStatus,
      batteryTimeToEmptyMinutes: battery?.timeToEmptyMinutes,
      batteryTimeToFullChargeMinutes: battery?.timeToFullChargeMinutes
    )

    history.append(nextSnapshot)
    snapshot = nextSnapshot
  }

  nonisolated static func shouldRefresh(
    lastRefresh: Date?,
    at currentDate: Date,
    minimumInterval: TimeInterval
  ) -> Bool {
    guard minimumInterval > 0, let lastRefresh else { return true }

    let elapsed = currentDate.timeIntervalSince(lastRefresh)
    return elapsed < 0 || elapsed >= minimumInterval
  }
}

private struct CachedReading<Value: Sendable>: Sendable {
  let value: Value?
  let timestamp: Date
}
