import Testing

@testable import PulseBar

@Suite("PulseBar monitoring")
struct PulseBarTests {
  @Test("Metric formatter presents percentages and byte rates")
  func metricFormatting() {
    #expect(MetricFormatter.percentage(0.32) == "32%")
    #expect(MetricFormatter.bytes(18 * 1_024 * 1_024 * 1_024) == "18 GiB")
    #expect(MetricFormatter.rate(2.4 * 1_024 * 1_024) == "2.4 MiB/s")
    #expect(
      MetricFormatter.rate(2.4 * 1_024 * 1_024, unit: .bytesPerSecond) == "2.5 MB/s")
    #expect(MetricFormatter.rate(2.4 * 1_024 * 1_024, unit: .bitsPerSecond) == "20 Mb/s")
    #expect(MetricFormatter.percentage(nil) == "Unavailable")
    #expect(MetricFormatter.compactPercentage(nil) == "—")
    #expect(MetricFormatter.compactRate(2.4 * 1_024 * 1_024) == "2.4M")
    #expect(
      MetricFormatter.rate(Double.greatestFiniteMagnitude, unit: .bitsPerSecond)
        == "Unavailable")
    #expect(
      MetricFormatter.compactRate(Double.greatestFiniteMagnitude, unit: .bitsPerSecond)
        == "—")
  }

  @Test("Menu bar presentation is compact and includes download throughput")
  func menuBarPresentation() {
    let presentation = MenuBarPresentation(
      cpuUsage: 0.23,
      memoryUsage: 0.51,
      downloadBytesPerSecond: 2.4 * 1_024 * 1_024
    )

    #expect(presentation.title == "CPU 23%  MEM 51%  ↓ 2.4M")
    #expect(
      presentation.accessibilityLabel
        == "CPU 23%, memory 51%, download 2.4 MiB/s")

    let unavailablePresentation = MenuBarPresentation(
      cpuUsage: nil,
      memoryUsage: nil,
      downloadBytesPerSecond: nil
    )
    #expect(unavailablePresentation.title == "CPU —  MEM —  ↓ —")

    let alternatePresentation = MenuBarPresentation(
      cpuUsage: 0.23,
      memoryUsage: 0.51,
      downloadBytesPerSecond: 2.4 * 1_024 * 1_024,
      uploadBytesPerSecond: 820 * 1_024,
      batteryPercentage: 0.83,
      visibility: MenuBarMetricVisibility(
        showsCPU: false,
        showsMemory: false,
        showsNetworkDownload: false,
        showsNetworkUpload: true,
        showsBattery: true
      ),
      networkUnit: .bitsPerSecond
    )
    #expect(alternatePresentation.title == "↑ 6.7Mb  BAT 83%")
    #expect(alternatePresentation.accessibilityLabel == "upload 6.7 Mb/s, battery 83%")

    let hiddenPresentation = MenuBarPresentation(
      cpuUsage: 0.23,
      memoryUsage: 0.51,
      downloadBytesPerSecond: 2.4 * 1_024 * 1_024,
      visibility: MenuBarMetricVisibility(
        showsCPU: false,
        showsMemory: false,
        showsNetworkDownload: false,
        showsNetworkUpload: false,
        showsBattery: false
      )
    )
    #expect(hiddenPresentation.title == "PulseBar")
    #expect(hiddenPresentation.accessibilityLabel == "PulseBar")
  }

  @Test("View model combines provider readings into one snapshot")
  @MainActor
  func snapshotCoordination() async {
    let viewModel = SystemMonitorViewModel(
      cpuProvider: PlaceholderCPUService(usage: 0.32),
      memoryProvider: PlaceholderMemoryService(),
      networkProvider: PlaceholderNetworkService(),
      diskProvider: PlaceholderDiskService(),
      batteryProvider: PlaceholderBatteryService()
    )

    await viewModel.refresh()

    #expect(viewModel.snapshot.cpuUsage == 0.32)
    #expect(viewModel.snapshot.memoryUsed != nil)
    #expect(viewModel.snapshot.networkDownloadBytesPerSecond != nil)
    #expect(viewModel.snapshot.diskTotal != nil)
    #expect(viewModel.snapshot.diskAvailable != nil)
    #expect(viewModel.snapshot.batteryPercentage == 0.83)
    #expect(viewModel.snapshot.batteryIsCharging == true)
    #expect(viewModel.snapshot.batteryIsFullyCharged == false)
    #expect(viewModel.snapshot.batteryIsACPowered == true)
    #expect(viewModel.history.count == 1)
    #expect(viewModel.history.last == viewModel.snapshot)
  }

  @Test("Ring buffer retains only the newest elements in chronological order")
  func boundedRingBuffer() {
    var buffer = RingBuffer<Int>(capacity: 3)
    for value in 1...5 {
      buffer.append(value)
    }

    #expect(Array(buffer) == [3, 4, 5])
    #expect(buffer.count == 3)
    #expect(buffer.capacity == 3)

    buffer.resize(to: 2)
    #expect(Array(buffer) == [4, 5])
    buffer.resize(to: 5)
    buffer.append(6)
    #expect(Array(buffer) == [4, 5, 6])

    var zeroCapacityBuffer = RingBuffer<Int>(capacity: 0)
    zeroCapacityBuffer.append(1)
    #expect(zeroCapacityBuffer.isEmpty)
  }

  @Test("View model history never exceeds its configured capacity")
  @MainActor
  func boundedSnapshotHistory() async {
    let viewModel = SystemMonitorViewModel(
      cpuProvider: PlaceholderCPUService(),
      memoryProvider: PlaceholderMemoryService(),
      networkProvider: PlaceholderNetworkService(),
      diskProvider: PlaceholderDiskService(),
      batteryProvider: PlaceholderBatteryService(),
      historyCapacity: 2
    )

    await viewModel.refresh()
    await viewModel.refresh()
    await viewModel.refresh()

    #expect(viewModel.history.count == 2)
    #expect(viewModel.history.last == viewModel.snapshot)

    viewModel.changeHistoryCapacity(to: 1)
    #expect(viewModel.history.count == 1)
    #expect(viewModel.history.last == viewModel.snapshot)
  }

  @Test("Preference options expose stable persisted values")
  func preferenceOptions() {
    #expect(MonitoringHistoryLength.allCases.map(\.rawValue) == [60, 120, 300])
    #expect(NetworkDisplayUnit.bitsPerSecond.rawValue == "bitsPerSecond")
    #expect(AppearancePreference.dark.colorScheme == .dark)
  }

  @Test("Refresh intervals expose the four supported cadences")
  func refreshIntervals() {
    #expect(
      MonitoringRefreshInterval.allCases.map(\.rawValue)
        == [0.5, 1, 2, 5])
    #expect(MonitoringRefreshInterval.halfSecond.duration == .milliseconds(500))
    #expect(MonitoringRefreshInterval.oneSecond.displayName == "1 second")
  }

  @Test("Monitoring lifecycle is idempotent and preserves interval changes")
  @MainActor
  func monitoringLifecycle() {
    let viewModel = SystemMonitorViewModel(
      cpuProvider: PlaceholderCPUService(),
      memoryProvider: PlaceholderMemoryService(),
      networkProvider: PlaceholderNetworkService(),
      diskProvider: PlaceholderDiskService(),
      batteryProvider: PlaceholderBatteryService()
    )

    #expect(!viewModel.isMonitoring)
    #expect(viewModel.refreshInterval == .oneSecond)

    viewModel.startMonitoring()
    viewModel.startMonitoring()
    #expect(viewModel.isMonitoring)

    viewModel.changeRefreshInterval(to: .halfSecond)
    #expect(viewModel.refreshInterval == .halfSecond)
    #expect(viewModel.isMonitoring)

    viewModel.stopMonitoring()
    viewModel.stopMonitoring()
    #expect(!viewModel.isMonitoring)

    viewModel.changeRefreshInterval(to: .fiveSeconds)
    #expect(viewModel.refreshInterval == .fiveSeconds)
    #expect(!viewModel.isMonitoring)
  }

  @Test("CPU delta calculation includes user, system, and nice as busy time")
  func cpuDeltaCalculation() {
    let previous = CPUTickSnapshot(user: 100, system: 200, idle: 300, nice: 10)
    let current = CPUTickSnapshot(user: 130, system: 220, idle: 340, nice: 20)

    let usage = CPUService.calculateUsage(previous: previous, current: current)

    #expect(usage != nil)
    #expect(abs((usage ?? 0) - 0.6) < 0.000_001)
  }

  @Test("CPU delta calculation handles an unchanged sample")
  func unchangedCPUSample() {
    let sample = CPUTickSnapshot(user: 100, system: 200, idle: 300, nice: 10)

    #expect(CPUService.calculateUsage(previous: sample, current: sample) == nil)
  }

  @Test("CPU service reads a normalized system-wide measurement")
  func liveCPUReading() async throws {
    let service = CPUService()

    #expect(await service.readCPUUsage() == nil)

    var usage: Double?
    for _ in 0..<10 {
      try await Task.sleep(for: .milliseconds(100))
      usage = await service.readCPUUsage()
      if usage != nil { break }
    }

    #expect(usage != nil)

    if let usage {
      #expect((0...1).contains(usage))
    }
  }

  @Test("Memory calculation treats inactive pages as available")
  func memoryCalculation() {
    let pageSize: UInt64 = 4_096
    let reading = MemoryService.makeReading(
      totalBytes: 1_000 * pageSize,
      pageSize: pageSize,
      freePages: 100,
      activePages: 500,
      inactivePages: 200,
      wiredPages: 200,
      compressedPages: 50,
      purgeablePages: 25
    )

    #expect(reading.availableBytes == 300 * pageSize)
    #expect(reading.usedBytes == 700 * pageSize)
    #expect(reading.freeBytes == 100 * pageSize)
    #expect(reading.activeBytes == 500 * pageSize)
    #expect(reading.inactiveBytes == 200 * pageSize)
    #expect(reading.wiredBytes == 200 * pageSize)
    #expect(reading.compressedBytes == 50 * pageSize)
    #expect(reading.purgeableBytes == 25 * pageSize)
  }

  @Test("Memory service reads a consistent physical-memory measurement")
  func liveMemoryReading() async {
    let reading = await MemoryService().readMemory()

    #expect(reading != nil)
    if let reading {
      #expect(reading.totalBytes > 0)
      #expect(reading.usedBytes <= reading.totalBytes)
      #expect(reading.availableBytes <= reading.totalBytes)
      #expect(reading.usedBytes + reading.availableBytes == reading.totalBytes)
      #expect(reading.freeBytes <= reading.totalBytes)
      #expect(reading.activeBytes <= reading.totalBytes)
      #expect(reading.inactiveBytes <= reading.totalBytes)
      #expect(reading.wiredBytes <= reading.totalBytes)
      #expect(reading.compressedBytes <= reading.totalBytes)
      #expect(reading.purgeableBytes <= reading.totalBytes)
    }
  }

  @Test("Network rates handle new, removed, and reset interfaces")
  func networkRateCalculation() {
    let previous: NetworkCounterSnapshot = [
      1: NetworkInterfaceCounters(receivedBytes: 1_000, sentBytes: 500),
      2: NetworkInterfaceCounters(receivedBytes: 8_000, sentBytes: 4_000),
      4: NetworkInterfaceCounters(receivedBytes: 90_000, sentBytes: 45_000),
    ]
    let current: NetworkCounterSnapshot = [
      1: NetworkInterfaceCounters(receivedBytes: 5_000, sentBytes: 2_500),
      2: NetworkInterfaceCounters(receivedBytes: 100, sentBytes: 4_500),
      3: NetworkInterfaceCounters(receivedBytes: 50_000, sentBytes: 25_000),
    ]

    let reading = NetworkService.makeReading(
      previous: previous,
      current: current,
      elapsedSeconds: 2
    )

    #expect(reading?.downloadBytesPerSecond == 2_000)
    #expect(reading?.uploadBytesPerSecond == 1_250)
  }

  @Test("Network rate calculation rejects a non-positive interval")
  func invalidNetworkInterval() {
    let counters: NetworkCounterSnapshot = [
      1: NetworkInterfaceCounters(receivedBytes: 1_000, sentBytes: 500)
    ]

    #expect(
      NetworkService.makeReading(previous: counters, current: counters, elapsedSeconds: 0) == nil
    )
  }

  @Test("Network service reads non-negative aggregate throughput")
  func liveNetworkReading() async throws {
    let service = NetworkService()

    #expect(await service.readNetwork() == nil)
    try await Task.sleep(for: .milliseconds(100))

    let reading = await service.readNetwork()
    #expect(reading != nil)
    if let reading {
      #expect(reading.downloadBytesPerSecond >= 0)
      #expect(reading.uploadBytesPerSecond >= 0)
      #expect(reading.downloadBytesPerSecond.isFinite)
      #expect(reading.uploadBytesPerSecond.isFinite)
    }
  }

  @Test("Disk calculation derives used space and clamps inconsistent availability")
  func diskCalculation() {
    let reading = DiskService.makeReading(totalBytes: 1_000, availableBytes: 400)
    let clampedReading = DiskService.makeReading(totalBytes: 1_000, availableBytes: 1_200)

    #expect(reading?.usedBytes == 600)
    #expect(reading?.totalBytes == 1_000)
    #expect(reading?.availableBytes == 400)
    #expect(clampedReading?.usedBytes == 0)
    #expect(clampedReading?.availableBytes == 1_000)
    #expect(DiskService.makeReading(totalBytes: 0, availableBytes: 0) == nil)
  }

  @Test("Disk service reads a consistent system-volume capacity")
  func liveDiskReading() async {
    let reading = await DiskService().readDisk()

    #expect(reading != nil)
    if let reading {
      #expect(reading.totalBytes > 0)
      #expect(reading.usedBytes <= reading.totalBytes)
      #expect(reading.availableBytes <= reading.totalBytes)
      #expect(reading.usedBytes + reading.availableBytes == reading.totalBytes)
    }
  }

  @Test("Battery calculation normalizes capacity and preserves power states")
  func batteryCalculation() {
    let reading = BatteryService.makeReading(
      currentCapacity: 80,
      maximumCapacity: 100,
      isCharging: true,
      isFullyCharged: false,
      isACPowered: true
    )
    let clampedReading = BatteryService.makeReading(
      currentCapacity: 120,
      maximumCapacity: 100,
      isCharging: false,
      isFullyCharged: true,
      isACPowered: true
    )

    #expect(reading?.percentage == 0.8)
    #expect(reading?.isCharging == true)
    #expect(reading?.isFullyCharged == false)
    #expect(reading?.isACPowered == true)
    #expect(clampedReading?.percentage == 1)
    #expect(
      BatteryService.makeReading(
        currentCapacity: -1,
        maximumCapacity: 100,
        isCharging: false,
        isFullyCharged: false,
        isACPowered: false
      ) == nil)
    #expect(
      BatteryService.makeReading(
        currentCapacity: 0,
        maximumCapacity: 0,
        isCharging: false,
        isFullyCharged: false,
        isACPowered: false
      ) == nil)
  }

  @Test("Battery service supports battery-equipped and batteryless Macs")
  func liveBatteryReading() async {
    guard let reading = await BatteryService().readBattery() else {
      return
    }

    #expect((0...1).contains(reading.percentage))
    if reading.isCharging || reading.isFullyCharged {
      #expect(reading.isACPowered)
    }
  }
}
