import Combine
import Foundation
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
    #expect(MetricFormatter.duration(minutes: 125) == "2h 5m")
    #expect(MetricFormatter.duration(minutes: 120) == "2h")
    #expect(MetricFormatter.duration(minutes: 45) == "45m")
    #expect(MetricFormatter.duration(minutes: 0) == "<1m")
    #expect(MetricFormatter.duration(minutes: -1) == "Unavailable")
    #expect(MetricFormatter.duration(minutes: nil) == "Unavailable")
  }

  @Test("Chart bounds remain finite when padding extreme samples")
  func chartBoundaries() {
    #expect(MetricChart.upperBound(for: 0) == 1)
    #expect(MetricChart.upperBound(for: 10) == 11)
    #expect(MetricChart.upperBound(for: -1) == 1)
    #expect(MetricChart.upperBound(for: .infinity) == 1)
    #expect(MetricChart.upperBound(for: .nan) == 1)
    #expect(
      MetricChart.upperBound(for: Double.greatestFiniteMagnitude)
        == Double.greatestFiniteMagnitude)
  }

  @Test("Menu bar presentation is compact and includes download throughput")
  func menuBarPresentation() {
    let presentation = MenuBarPresentation(
      cpuUsage: 0.23,
      memoryUsage: 0.51,
      downloadBytesPerSecond: 2.4 * 1_024 * 1_024
    )

    #expect(presentation.title == "CPU 23%  MEM 51%  ↓ 2.4M")
    #expect(presentation.metrics.map(\.metric) == [.cpu, .memory, .networkDownload])
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
    #expect(alternatePresentation.metrics.map(\.metric) == [.networkUpload, .battery])
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
    #expect(hiddenPresentation.metrics.isEmpty)
  }

  @Test("Menu bar metrics define stable order, keys, and defaults")
  func menuBarMetricConfiguration() {
    #expect(
      MenuBarMetric.allCases
        == [.cpu, .memory, .networkDownload, .networkUpload, .battery])
    #expect(
      MenuBarMetric.allCases.map(\.settingsTitle)
        == ["CPU", "Memory", "Network Download", "Network Upload", "Battery"])
    #expect(Set(MenuBarMetric.allCases.map(\.preferenceKey)).count == 5)
    #expect(
      MenuBarMetric.allCases.filter(\.isVisibleByDefault)
        == [.cpu, .memory, .networkDownload])

    for metric in MenuBarMetric.allCases {
      #expect(MenuBarMetricVisibility.standard.isVisible(metric) == metric.isVisibleByDefault)
    }
  }

  @Test("View model combines provider readings into one snapshot")
  @MainActor
  func snapshotCoordination() async {
    let viewModel = SystemMonitorViewModel(
      cpuProvider: PlaceholderCPUService(usage: 0.32),
      perCoreCPUProvider: PlaceholderPerCoreCPUService(usages: [0.2, 0.4]),
      memoryProvider: PlaceholderMemoryService(),
      networkProvider: PlaceholderNetworkService(),
      diskProvider: PlaceholderDiskService(),
      batteryProvider: PlaceholderBatteryService()
    )

    await viewModel.refresh()

    #expect(viewModel.snapshot.cpuUsage == 0.32)
    #expect(viewModel.snapshot.cpuCoreUsages == [0.2, 0.4])
    #expect(viewModel.snapshot.memoryUsed != nil)
    #expect(viewModel.snapshot.memoryCached == UInt64(3) * 1_024 * 1_024 * 1_024)
    #expect(viewModel.snapshot.swapUsed == UInt64(512) * 1_024 * 1_024)
    #expect(viewModel.snapshot.swapTotal == UInt64(4) * 1_024 * 1_024 * 1_024)
    #expect(viewModel.snapshot.networkDownloadBytesPerSecond != nil)
    #expect(viewModel.snapshot.diskTotal != nil)
    #expect(viewModel.snapshot.diskAvailable != nil)
    #expect(viewModel.snapshot.diskReadBytesPerSecond == Double(18 * 1_024 * 1_024))
    #expect(viewModel.snapshot.diskWriteBytesPerSecond == Double(6 * 1_024 * 1_024))
    #expect(viewModel.snapshot.batteryPercentage == 0.83)
    #expect(viewModel.snapshot.batteryIsCharging == true)
    #expect(viewModel.snapshot.batteryIsFullyCharged == false)
    #expect(viewModel.snapshot.batteryIsACPowered == true)
    #expect(viewModel.snapshot.batteryHealthStatus == "Good")
    #expect(viewModel.snapshot.batteryTimeToEmptyMinutes == nil)
    #expect(viewModel.snapshot.batteryTimeToFullChargeMinutes == 35)
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
      perCoreCPUProvider: PlaceholderPerCoreCPUService(),
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

  @Test("Launch at login registration and removal are idempotent")
  @MainActor
  func launchAtLoginRegistration() {
    let service = MockLaunchAtLoginService(status: .disabled)
    let controller = LaunchAtLoginController(service: service)

    #expect(!controller.isEnabled)
    controller.setEnabled(false)
    #expect(service.unregisterCallCount == 0)

    controller.setEnabled(true)
    #expect(service.registerCallCount == 1)
    #expect(controller.status == .enabled)
    #expect(controller.isEnabled)

    controller.setEnabled(true)
    #expect(service.registerCallCount == 1)

    controller.setEnabled(false)
    #expect(service.unregisterCallCount == 1)
    #expect(controller.status == .disabled)
    #expect(!controller.isEnabled)
  }

  @Test("Launch at login exposes approval and refreshes external changes")
  @MainActor
  func launchAtLoginApproval() {
    let service = MockLaunchAtLoginService(status: .requiresApproval)
    let controller = LaunchAtLoginController(service: service)

    #expect(controller.isEnabled)
    #expect(controller.status.title == "Approval Required")

    controller.openSystemSettings()
    #expect(service.openSettingsCallCount == 1)

    service.status = .enabled
    controller.refresh()
    #expect(controller.status == .enabled)
  }

  @Test("Launch at login reports failures and rejects unavailable services")
  @MainActor
  func launchAtLoginFailure() {
    let failingService = MockLaunchAtLoginService(status: .disabled)
    failingService.registerError = StubLaunchAtLoginError()
    let failingController = LaunchAtLoginController(service: failingService)

    failingController.setEnabled(true)

    #expect(failingController.status == .disabled)
    #expect(failingController.errorMessage?.contains("Registration failed") == true)

    failingService.status = .enabled
    failingController.refresh()
    #expect(failingController.errorMessage == nil)

    let unavailableService = MockLaunchAtLoginService(status: .unavailable)
    let unavailableController = LaunchAtLoginController(service: unavailableService)

    unavailableController.setEnabled(true)
    #expect(!unavailableController.canChange)
    #expect(unavailableService.registerCallCount == 0)
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
      perCoreCPUProvider: PlaceholderPerCoreCPUService(),
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

  @Test("Automatic sampling publishes one consolidated UI update")
  @MainActor
  func consolidatedAutomaticUpdate() async {
    let viewModel = SystemMonitorViewModel(
      cpuProvider: PlaceholderCPUService(),
      perCoreCPUProvider: PlaceholderPerCoreCPUService(),
      memoryProvider: PlaceholderMemoryService(),
      networkProvider: PlaceholderNetworkService(),
      diskProvider: PlaceholderDiskService(),
      batteryProvider: PlaceholderBatteryService()
    )
    var updateCount = 0
    let observation = viewModel.objectWillChange.sink {
      updateCount += 1
    }

    await viewModel.refreshForMonitoring()

    #expect(updateCount == 1)
    #expect(!viewModel.isRefreshing)
    withExtendedLifetime(observation) {}
  }

  @Test("Manual refresh requested during automatic sampling is coalesced")
  @MainActor
  func queuedManualRefresh() async {
    let cpuProvider = FirstReadGateCPUProvider()
    let slowMetricProvider = CountingSlowMetricProvider()
    let viewModel = SystemMonitorViewModel(
      cpuProvider: cpuProvider,
      perCoreCPUProvider: PlaceholderPerCoreCPUService(),
      memoryProvider: PlaceholderMemoryService(),
      networkProvider: PlaceholderNetworkService(),
      diskProvider: slowMetricProvider,
      batteryProvider: slowMetricProvider
    )

    let automaticSample = Task {
      await viewModel.refreshForMonitoring()
    }
    await cpuProvider.waitUntilFirstReadStarts()

    await viewModel.refresh()
    await cpuProvider.resumeFirstRead()
    await automaticSample.value

    for _ in 0..<100 where await slowMetricProvider.callCounts().disk < 2 {
      await Task.yield()
    }

    let counts = await slowMetricProvider.callCounts()
    #expect(counts.disk == 2)
    #expect(counts.throughput == 2)
    #expect(counts.battery == 2)
  }

  @Test("Automatic sampling throttles slow metrics and manual refresh bypasses caches")
  @MainActor
  func slowMetricCadence() async {
    let dateSource = TestDateSource(currentDate: Date(timeIntervalSince1970: 1_000))
    let slowMetricProvider = CountingSlowMetricProvider()
    let viewModel = SystemMonitorViewModel(
      cpuProvider: PlaceholderCPUService(),
      perCoreCPUProvider: PlaceholderPerCoreCPUService(),
      memoryProvider: PlaceholderMemoryService(),
      networkProvider: PlaceholderNetworkService(),
      diskProvider: slowMetricProvider,
      batteryProvider: slowMetricProvider,
      now: { dateSource.currentDate }
    )

    await viewModel.refreshForMonitoring()
    var counts = await slowMetricProvider.callCounts()
    #expect(counts.disk == 1)
    #expect(counts.throughput == 1)
    #expect(counts.battery == 1)

    dateSource.advance(by: 1)
    await viewModel.refreshForMonitoring()
    counts = await slowMetricProvider.callCounts()
    #expect(counts.disk == 1)
    #expect(counts.throughput == 2)
    #expect(counts.battery == 1)

    dateSource.advance(by: 4)
    await viewModel.refreshForMonitoring()
    counts = await slowMetricProvider.callCounts()
    #expect(counts.disk == 1)
    #expect(counts.throughput == 3)
    #expect(counts.battery == 2)

    dateSource.advance(by: 25)
    await viewModel.refreshForMonitoring()
    counts = await slowMetricProvider.callCounts()
    #expect(counts.disk == 2)
    #expect(counts.throughput == 4)
    #expect(counts.battery == 3)

    await viewModel.refresh()
    counts = await slowMetricProvider.callCounts()
    #expect(counts.disk == 3)
    #expect(counts.throughput == 5)
    #expect(counts.battery == 4)
  }

  @Test("Slow metric cadence refreshes after wall-clock changes")
  func slowMetricClockChanges() {
    let lastRefresh = Date(timeIntervalSince1970: 100)

    #expect(
      !SystemMonitorViewModel.shouldRefresh(
        lastRefresh: lastRefresh,
        at: Date(timeIntervalSince1970: 104),
        minimumInterval: 5
      ))
    #expect(
      SystemMonitorViewModel.shouldRefresh(
        lastRefresh: lastRefresh,
        at: Date(timeIntervalSince1970: 105),
        minimumInterval: 5
      ))
    #expect(
      SystemMonitorViewModel.shouldRefresh(
        lastRefresh: lastRefresh,
        at: Date(timeIntervalSince1970: 90),
        minimumInterval: 5
      ))
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

  @Test("CPU delta calculation handles counter wrap and rejects malformed counters")
  func cpuCounterBoundaries() {
    let maximumTick = UInt64(UInt32.max)
    let previous = CPUTickSnapshot(
      user: maximumTick - 4,
      system: 200,
      idle: 300,
      nice: 10
    )
    let current = CPUTickSnapshot(user: 5, system: 200, idle: 310, nice: 10)

    #expect(CPUService.calculateUsage(previous: previous, current: current) == 0.5)

    let malformed = CPUTickSnapshot(
      user: maximumTick + 1,
      system: 200,
      idle: 300,
      nice: 10
    )
    #expect(CPUService.calculateUsage(previous: malformed, current: current) == nil)
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

  @Test("Per-core CPU calculation preserves core order and handles topology changes")
  func perCoreCPUCalculation() {
    let previous = [
      CPUTickSnapshot(user: 100, system: 100, idle: 200, nice: 0),
      CPUTickSnapshot(user: 200, system: 100, idle: 100, nice: 0),
    ]
    let current = [
      CPUTickSnapshot(user: 120, system: 110, idle: 210, nice: 0),
      CPUTickSnapshot(user: 210, system: 110, idle: 130, nice: 0),
      CPUTickSnapshot(user: 50, system: 20, idle: 100, nice: 0),
    ]

    let usages = PerCoreCPUService.calculateUsages(previous: previous, current: current)

    #expect(usages.count == 3)
    #expect(abs((usages[0] ?? 0) - 0.75) < 0.000_001)
    #expect(abs((usages[1] ?? 0) - 0.4) < 0.000_001)
    #expect(usages[2] == nil)
  }

  @Test("Per-core CPU service reads normalized logical processor measurements")
  func livePerCoreCPUReading() async throws {
    let service = PerCoreCPUService()
    let baseline = await service.readPerCoreCPUUsage()

    #expect(!baseline.isEmpty)
    #expect(baseline.allSatisfy { $0 == nil })

    var usages: [Double?] = []
    for _ in 0..<10 {
      try await Task.sleep(for: .milliseconds(100))
      usages = await service.readPerCoreCPUUsage()
      if usages.contains(where: { $0 != nil }) { break }
    }

    #expect(usages.count == baseline.count)
    #expect(usages.contains(where: { $0 != nil }))
    for usage in usages.compactMap({ $0 }) {
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
      externalPages: 150,
      wiredPages: 200,
      compressedPages: 50,
      purgeablePages: 25,
      swapUsedBytes: 1_200,
      swapTotalBytes: 1_000
    )

    #expect(reading.availableBytes == 300 * pageSize)
    #expect(reading.usedBytes == 700 * pageSize)
    #expect(reading.freeBytes == 100 * pageSize)
    #expect(reading.activeBytes == 500 * pageSize)
    #expect(reading.inactiveBytes == 200 * pageSize)
    #expect(reading.cachedBytes == 150 * pageSize)
    #expect(reading.wiredBytes == 200 * pageSize)
    #expect(reading.compressedBytes == 50 * pageSize)
    #expect(reading.purgeableBytes == 25 * pageSize)
    #expect(reading.swapUsedBytes == 1_000)
    #expect(reading.swapTotalBytes == 1_000)
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
      #expect(reading.cachedBytes <= reading.totalBytes)
      #expect(reading.wiredBytes <= reading.totalBytes)
      #expect(reading.compressedBytes <= reading.totalBytes)
      #expect(reading.purgeableBytes <= reading.totalBytes)
      #expect(reading.swapUsedBytes != nil)
      #expect(reading.swapTotalBytes != nil)
      if let swapUsedBytes = reading.swapUsedBytes,
        let swapTotalBytes = reading.swapTotalBytes
      {
        #expect(swapUsedBytes <= swapTotalBytes)
      }
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

  @Test("Network rate calculation rejects non-finite results")
  func overflowingNetworkRate() {
    let previous: NetworkCounterSnapshot = [
      1: NetworkInterfaceCounters(receivedBytes: 0, sentBytes: 0)
    ]
    let current: NetworkCounterSnapshot = [
      1: NetworkInterfaceCounters(receivedBytes: .max, sentBytes: .max)
    ]

    #expect(
      NetworkService.makeReading(
        previous: previous,
        current: current,
        elapsedSeconds: .leastNonzeroMagnitude
      ) == nil
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

  @Test("Disk rates handle new, removed, and reset devices")
  func diskThroughputCalculation() {
    let previous: DiskCounterSnapshot = [
      1: DiskDeviceCounters(readBytes: 1_000, writtenBytes: 500),
      2: DiskDeviceCounters(readBytes: 8_000, writtenBytes: 4_000),
      4: DiskDeviceCounters(readBytes: 90_000, writtenBytes: 45_000),
    ]
    let current: DiskCounterSnapshot = [
      1: DiskDeviceCounters(readBytes: 5_000, writtenBytes: 2_500),
      2: DiskDeviceCounters(readBytes: 100, writtenBytes: 4_500),
      3: DiskDeviceCounters(readBytes: 50_000, writtenBytes: 25_000),
    ]

    let reading = DiskService.makeThroughputReading(
      previous: previous,
      current: current,
      elapsedSeconds: 2
    )

    #expect(reading?.readBytesPerSecond == 2_000)
    #expect(reading?.writeBytesPerSecond == 1_250)
  }

  @Test("Disk rate calculation rejects invalid intervals and non-finite results")
  func invalidDiskThroughput() {
    let baseline: DiskCounterSnapshot = [
      1: DiskDeviceCounters(readBytes: 0, writtenBytes: 0)
    ]

    #expect(
      DiskService.makeThroughputReading(
        previous: baseline,
        current: baseline,
        elapsedSeconds: 0
      ) == nil)

    let maximum: DiskCounterSnapshot = [
      1: DiskDeviceCounters(readBytes: .max, writtenBytes: .max)
    ]
    #expect(
      DiskService.makeThroughputReading(
        previous: baseline,
        current: maximum,
        elapsedSeconds: .leastNonzeroMagnitude
      ) == nil)
  }

  @Test("Disk service reads non-negative aggregate throughput")
  func liveDiskThroughput() async throws {
    let service = DiskService()

    #expect(await service.readDiskThroughput() == nil)
    try await Task.sleep(for: .milliseconds(100))

    guard let reading = await service.readDiskThroughput() else {
      // Some virtualized Macs do not expose IOBlockStorageDriver statistics.
      return
    }

    #expect(reading.readBytesPerSecond >= 0)
    #expect(reading.writeBytesPerSecond >= 0)
    #expect(reading.readBytesPerSecond.isFinite)
    #expect(reading.writeBytesPerSecond.isFinite)
  }

  @Test("Battery calculation normalizes capacity and preserves power states")
  func batteryCalculation() {
    let reading = BatteryService.makeReading(
      currentCapacity: 80,
      maximumCapacity: 100,
      isCharging: true,
      isFullyCharged: false,
      isACPowered: true,
      healthStatus: " Good ",
      timeToEmptyMinutes: 120,
      timeToFullChargeMinutes: 45
    )
    let clampedReading = BatteryService.makeReading(
      currentCapacity: 120,
      maximumCapacity: 100,
      isCharging: false,
      isFullyCharged: true,
      isACPowered: true
    )
    let dischargingReading = BatteryService.makeReading(
      currentCapacity: 50,
      maximumCapacity: 100,
      isCharging: false,
      isFullyCharged: false,
      isACPowered: false,
      healthStatus: "\n",
      timeToEmptyMinutes: 125,
      timeToFullChargeMinutes: 30
    )

    #expect(reading?.percentage == 0.8)
    #expect(reading?.isCharging == true)
    #expect(reading?.isFullyCharged == false)
    #expect(reading?.isACPowered == true)
    #expect(reading?.healthStatus == "Good")
    #expect(reading?.timeToEmptyMinutes == nil)
    #expect(reading?.timeToFullChargeMinutes == 45)
    #expect(clampedReading?.percentage == 1)
    #expect(dischargingReading?.healthStatus == nil)
    #expect(dischargingReading?.timeToEmptyMinutes == 125)
    #expect(dischargingReading?.timeToFullChargeMinutes == nil)
    #expect(
      BatteryService.preferredHealthStatus(condition: " Check Battery ", estimate: "Good")
        == "Check Battery")
    #expect(BatteryService.preferredHealthStatus(condition: "", estimate: " Fair ") == "Fair")
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

  @Test("Battery estimates hide unknown values and inactive charge or discharge times")
  func batteryEstimateAvailability() throws {
    for minutes in [nil, -1, 0, 45] as [Int?] {
      let expectedMinutes = minutes == -1 ? nil : minutes
      let discharging = try #require(
        BatteryService.makeReading(
          currentCapacity: 50, maximumCapacity: 100,
          isCharging: false, isFullyCharged: false, isACPowered: false,
          timeToEmptyMinutes: minutes, timeToFullChargeMinutes: minutes
        ))
      #expect(discharging.timeToEmptyMinutes == expectedMinutes)
      #expect(discharging.timeToFullChargeMinutes == nil)

      let charging = try #require(
        BatteryService.makeReading(
          currentCapacity: 50, maximumCapacity: 100,
          isCharging: true, isFullyCharged: false, isACPowered: true,
          timeToEmptyMinutes: minutes, timeToFullChargeMinutes: minutes
        ))
      #expect(charging.timeToEmptyMinutes == nil)
      #expect(charging.timeToFullChargeMinutes == expectedMinutes)

      for fullyCharged in [false, true] {
        let pluggedIn = try #require(
          BatteryService.makeReading(
            currentCapacity: 100, maximumCapacity: 100,
            isCharging: false, isFullyCharged: fullyCharged, isACPowered: true,
            timeToEmptyMinutes: minutes, timeToFullChargeMinutes: minutes
          ))
        #expect(pluggedIn.timeToEmptyMinutes == nil)
        #expect(pluggedIn.timeToFullChargeMinutes == nil)
      }
    }
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
    if let timeToEmptyMinutes = reading.timeToEmptyMinutes {
      #expect(timeToEmptyMinutes >= 0)
      #expect(!reading.isCharging)
      #expect(!reading.isACPowered)
    }
    if let timeToFullChargeMinutes = reading.timeToFullChargeMinutes {
      #expect(timeToFullChargeMinutes >= 0)
      #expect(reading.isCharging)
      #expect(!reading.isFullyCharged)
    }
    if let healthStatus = reading.healthStatus {
      #expect(!healthStatus.isEmpty)
      #expect(healthStatus == healthStatus.trimmingCharacters(in: .whitespacesAndNewlines))
    }
  }
}

@MainActor
private final class MockLaunchAtLoginService: LaunchAtLoginServicing {
  var status: LaunchAtLoginStatus
  var registerError: Error?
  var unregisterError: Error?
  var registerCallCount = 0
  var unregisterCallCount = 0
  var openSettingsCallCount = 0

  init(status: LaunchAtLoginStatus) {
    self.status = status
  }

  func register() throws {
    registerCallCount += 1
    if let registerError {
      throw registerError
    }
    status = .enabled
  }

  func unregister() throws {
    unregisterCallCount += 1
    if let unregisterError {
      throw unregisterError
    }
    status = .disabled
  }

  func openSystemSettings() {
    openSettingsCallCount += 1
  }
}

private struct StubLaunchAtLoginError: LocalizedError {
  var errorDescription: String? {
    "Registration failed"
  }
}

@MainActor
private final class TestDateSource {
  private(set) var currentDate: Date

  init(currentDate: Date) {
    self.currentDate = currentDate
  }

  func advance(by interval: TimeInterval) {
    currentDate.addTimeInterval(interval)
  }
}

private actor CountingSlowMetricProvider: DiskProviding, BatteryProviding {
  private var diskCallCount = 0
  private var diskThroughputCallCount = 0
  private var batteryCallCount = 0

  func readDisk() async -> DiskReading? {
    diskCallCount += 1
    return DiskReading(
      usedBytes: 400,
      totalBytes: 1_000,
      availableBytes: 600
    )
  }

  func readDiskThroughput() async -> DiskThroughputReading? {
    diskThroughputCallCount += 1
    return DiskThroughputReading(readBytesPerSecond: 0, writeBytesPerSecond: 0)
  }

  func readBattery() async -> BatteryReading? {
    batteryCallCount += 1
    return nil
  }

  func callCounts() -> (disk: Int, throughput: Int, battery: Int) {
    (diskCallCount, diskThroughputCallCount, batteryCallCount)
  }
}

private actor FirstReadGateCPUProvider: CPUProviding {
  private var firstReadContinuation: CheckedContinuation<Void, Never>?
  private var readCount = 0

  func readCPUUsage() async -> Double? {
    readCount += 1
    if readCount == 1 {
      await withCheckedContinuation { continuation in
        firstReadContinuation = continuation
      }
    }
    return 0.5
  }

  func waitUntilFirstReadStarts() async {
    while readCount == 0 {
      await Task.yield()
    }
  }

  func resumeFirstRead() {
    firstReadContinuation?.resume()
    firstReadContinuation = nil
  }
}
