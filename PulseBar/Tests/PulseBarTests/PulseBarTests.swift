import Combine
import Darwin
import Foundation
import IOKit.ps
import Testing

@testable import PulseBar

@Suite("PulseBar monitoring")
struct PulseBarTests {
  @Test("Metric formatter presents percentages and byte rates")
  func metricFormatting() {
    #expect(MetricFormatter.percentage(0.32) == "32%")
    #expect(MetricFormatter.bytes(18 * 1_000 * 1_000 * 1_000) == "18 GB")
    #expect(MetricFormatter.rate(2.4 * 1_024 * 1_024) == "2.5 MB/s")
    #expect(
      MetricFormatter.rate(2.4 * 1_024 * 1_024, unit: .bytesPerSecond) == "2.5 MB/s")
    #expect(MetricFormatter.rate(2.4 * 1_024 * 1_024, unit: .bitsPerSecond) == "20 Mb/s")
    #expect(MetricFormatter.percentage(nil) == "Unavailable")
    #expect(MetricFormatter.compactPercentage(nil) == "—")
    #expect(MetricFormatter.compactRate(2.4 * 1_024 * 1_024) == "2.5MB")
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

  @Test("Decimal byte units use the same thresholds in cards and menu bar")
  func decimalByteUnits() {
    let cases: [(UInt64, String, String)] = [
      (0, "0 B", "0B"),
      (999, "999 B", "999B"),
      (1_000, "1.0 KB", "1.0KB"),
      (1_000_000, "1.0 MB", "1.0MB"),
      (1_000_000_000, "1.0 GB", "1.0GB"),
      (1_000_000_000_000, "1.0 TB", "1.0TB"),
    ]

    for (bytes, expanded, compact) in cases {
      #expect(MetricFormatter.bytes(bytes) == expanded)
      for unit in [NetworkDisplayUnit.automatic, .bytesPerSecond] {
        #expect(MetricFormatter.rate(Double(bytes), unit: unit) == "\(expanded)/s")
        #expect(MetricFormatter.compactRate(Double(bytes), unit: unit) == compact)
      }
    }
    #expect(MetricFormatter.bytes(UInt64.max).hasSuffix(" TB"))
    #expect(MetricFormatter.bytes(nil) == "Unavailable")
  }

  @Test("Invalid throughput remains unavailable after decimal conversion")
  func invalidByteRates() {
    let values: [Double?] = [nil, -1, .nan, .infinity]
    for value in values {
      for unit in NetworkDisplayUnit.allCases {
        #expect(MetricFormatter.rate(value, unit: unit) == "Unavailable")
        #expect(MetricFormatter.compactRate(value, unit: unit) == "—")
      }
    }
    #expect(MetricFormatter.rate(1_000_000, unit: .bitsPerSecond) == "8.0 Mb/s")
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

  @Test("Chart point preparation preserves valid readings and rejects invalid values")
  @MainActor
  func chartPointFiltering() {
    var samples = RingBuffer<SystemSnapshot>(capacity: 1)
    samples.append(.empty)
    let invalidValues: [Double?] = [nil, -1, .nan, .infinity]
    for value in invalidValues {
      let series = MetricChartSeries(name: "Download", color: .cyan) { _ in value }
      #expect(MetricChart.points(samples: samples, series: series).isEmpty)
    }
    for value in [0.0, 0.25, Double.greatestFiniteMagnitude] {
      let series = MetricChartSeries(name: "Download", color: .cyan) { _ in value }
      let points = MetricChart.points(samples: samples, series: series)
      #expect(points.count == 1)
      #expect(points.first?.value == value)
      #expect(points.first?.id == SystemSnapshot.empty.id)
      #expect(points.first?.timestamp == SystemSnapshot.empty.timestamp)
      #expect(points.first?.seriesName == "Download")
    }
  }

  @Test("Batched chart points preserve ring-buffer order and independent series")
  @MainActor
  func chartPointOrdering() async {
    let viewModel = SystemMonitorViewModel(
      cpuProvider: PlaceholderCPUService(),
      perCoreCPUProvider: PlaceholderPerCoreCPUService(),
      cpuTopologyProvider: PlaceholderCPUTopologyService(),
      gpuProvider: PlaceholderGPUService(),
      appProcessProvider: PlaceholderAppProcessService(),
      memoryProvider: PlaceholderMemoryService(),
      networkProvider: PlaceholderNetworkService(),
      diskProvider: PlaceholderDiskService(),
      batteryProvider: PlaceholderBatteryService(),
      historyCapacity: 2
    )
    for _ in 0..<3 { await viewModel.refreshForMonitoring() }
    let chart = MetricChart(
      samples: viewModel.history,
      primarySeries: MetricChartSeries(name: "Download", color: .cyan) {
        $0.networkDownloadBytesPerSecond
      },
      secondarySeries: MetricChartSeries(name: "Upload", color: .orange) {
        $0.networkUploadBytesPerSecond
      },
      accessibilityLabel: "Network"
    )
    #expect(chart.primaryPoints.count == 2)
    #expect(chart.primaryPoints.map(\.id) == viewModel.history.map(\.id))
    #expect(chart.secondaryPoints.map(\.timestamp) == viewModel.history.map(\.timestamp))
    #expect(
      chart.primaryPoints.map(\.value)
        == viewModel.history.compactMap(\.networkDownloadBytesPerSecond))
    #expect(
      chart.secondaryPoints.map(\.value)
        == viewModel.history.compactMap(\.networkUploadBytesPerSecond))
    #expect(chart.primaryPoints.allSatisfy { $0.seriesName == "Download" })
    #expect(chart.secondaryPoints.allSatisfy { $0.seriesName == "Upload" })
  }

  @Test("Menu bar presentation is compact and includes download throughput")
  func menuBarPresentation() {
    let presentation = MenuBarPresentation(
      cpuUsage: 0.23,
      memoryUsage: 0.51,
      downloadBytesPerSecond: 2.4 * 1_024 * 1_024
    )

    #expect(presentation.title == "CPU 23%  MEM 51%  ↓ 2.5MB")
    #expect(presentation.metrics.map(\.metric) == [.cpu, .memory, .networkDownload])
    #expect(
      presentation.accessibilityLabel
        == "CPU 23%, memory 51%, download 2.5 MB/s")

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
      cpuTopologyProvider: PlaceholderCPUTopologyService(),
      gpuProvider: PlaceholderGPUService(),
      appProcessProvider: PlaceholderAppProcessService(),
      memoryProvider: PlaceholderMemoryService(),
      networkProvider: PlaceholderNetworkService(),
      diskProvider: PlaceholderDiskService(),
      batteryProvider: PlaceholderBatteryService()
    )

    await viewModel.refresh()

    #expect(viewModel.snapshot.cpuUsage == 0.32)
    #expect(viewModel.snapshot.cpuCoreUsages == [0.2, 0.4])
    #expect(viewModel.snapshot.gpuUsage(for: 1) == 0.42)
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
      cpuTopologyProvider: PlaceholderCPUTopologyService(),
      gpuProvider: PlaceholderGPUService(),
      appProcessProvider: PlaceholderAppProcessService(),
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
    #expect(MonitoringRefreshInterval.standard == .twoSeconds)
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
      cpuTopologyProvider: PlaceholderCPUTopologyService(),
      gpuProvider: PlaceholderGPUService(),
      appProcessProvider: PlaceholderAppProcessService(),
      memoryProvider: PlaceholderMemoryService(),
      networkProvider: PlaceholderNetworkService(),
      diskProvider: PlaceholderDiskService(),
      batteryProvider: PlaceholderBatteryService()
    )

    #expect(!viewModel.isMonitoring)
    #expect(viewModel.refreshInterval == .twoSeconds)

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
      cpuTopologyProvider: PlaceholderCPUTopologyService(),
      gpuProvider: PlaceholderGPUService(),
      appProcessProvider: PlaceholderAppProcessService(),
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
      cpuTopologyProvider: PlaceholderCPUTopologyService(),
      gpuProvider: PlaceholderGPUService(),
      appProcessProvider: PlaceholderAppProcessService(),
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
      cpuTopologyProvider: PlaceholderCPUTopologyService(),
      gpuProvider: PlaceholderGPUService(),
      appProcessProvider: PlaceholderAppProcessService(),
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

  @Test("Physical network selection uses hardware types without assuming en0")
  func physicalNetworkSelection() {
    for (name, type) in [
      ("en7", "IEEE80211"), ("en0", "Ethernet"), ("en99", "Ethernet"),
      ("wwan0", "WWAN"), ("fw0", "FireWire"), ("bt0", "Bluetooth"),
    ] {
      #expect(NetworkService.isPhysicalInterface(name: name, type: type, isLayered: false))
    }
    for (name, type) in [
      ("utun10", "IPSec"), ("ppp0", "PPP"), ("bridge0", "Bridge"),
      ("bond0", "Bond"), ("vlan0", "VLAN"), ("lo0", "Loopback"),
      ("awdl0", "IEEE80211"), ("llw0", "Ethernet"), ("ap1", "IEEE80211"),
      ("en8", "Unknown"),
    ] {
      #expect(!NetworkService.isPhysicalInterface(name: name, type: type, isLayered: false))
    }
    #expect(!NetworkService.isPhysicalInterface(name: nil, type: "Ethernet", isLayered: false))
    #expect(!NetworkService.isPhysicalInterface(name: "", type: "Ethernet", isLayered: false))
    #expect(!NetworkService.isPhysicalInterface(name: "en0", type: nil, isLayered: false))
    #expect(!NetworkService.isPhysicalInterface(name: "en0", type: "Ethernet", isLayered: true))
  }

  @Test("Routing counter parsing excludes VPN, peer-to-peer, and layered duplicate traffic")
  func physicalNetworkCounters() throws {
    func message(index: UInt16, received: UInt64, sent: UInt64, flags: Int32 = IFF_UP) -> [UInt8] {
      var header = if_msghdr2()
      header.ifm_msglen = UInt16(MemoryLayout<if_msghdr2>.size)
      header.ifm_version = UInt8(RTM_VERSION)
      header.ifm_type = UInt8(RTM_IFINFO2)
      header.ifm_flags = flags
      header.ifm_index = index
      header.ifm_data.ifi_ibytes = received
      header.ifm_data.ifi_obytes = sent
      return withUnsafeBytes(of: header) { Array($0) }
    }

    let physical: Set<UInt32> = [15, 7, 8, 1]
    let before =
      message(index: 15, received: 10_000, sent: 5_000)
      + message(index: 7, received: 20_000, sent: 8_000)
      + message(index: 36, received: 9_000, sent: 4_000)
    let after =
      message(index: 15, received: 94_000, sent: 51_000)
      + message(index: 7, received: 22_000, sent: 10_000)
      + message(index: 36, received: 69_000, sent: 30_000)  // VPN
      + message(index: 16, received: 13_000, sent: 0)  // AWDL
      + message(index: 13, received: 84_000, sent: 46_000)  // Bridge
      + message(index: 8, received: 999_000, sent: 999_000, flags: 0)  // Down
      + message(index: 1, received: 999_000, sent: 999_000, flags: IFF_UP | IFF_LOOPBACK)
    let previous = try #require(
      NetworkService.parseInterfaceCounters(before, physicalInterfaceIndices: physical))
    let current = try #require(
      NetworkService.parseInterfaceCounters(after, physicalInterfaceIndices: physical))

    #expect(Set(current.keys) == [15, 7])
    let reading = NetworkService.makeReading(
      previous: previous, current: current, elapsedSeconds: 2)
    #expect(reading?.downloadBytesPerSecond == 43_000)
    #expect(reading?.uploadBytesPerSecond == 24_000)
    #expect(NetworkService.parseInterfaceCounters(after, physicalInterfaceIndices: []) == [:])
  }

  @Test("Network interface changes establish fresh baselines and reject malformed routing data")
  func physicalNetworkChanges() {
    let wifi: NetworkCounterSnapshot = [
      15: NetworkInterfaceCounters(receivedBytes: 100, sentBytes: 50)
    ]
    let ethernet: NetworkCounterSnapshot = [
      7: NetworkInterfaceCounters(receivedBytes: 9_000, sentBytes: 8_000)
    ]
    let switched = NetworkService.makeReading(previous: wifi, current: ethernet, elapsedSeconds: 2)
    #expect(switched?.downloadBytesPerSecond == 0)
    #expect(switched?.uploadBytesPerSecond == 0)
    let offline = NetworkService.makeReading(previous: wifi, current: [:], elapsedSeconds: 2)
    #expect(offline?.downloadBytesPerSecond == 0)
    #expect(offline?.uploadBytesPerSecond == 0)
    #expect(NetworkService.parseInterfaceCounters([0], physicalInterfaceIndices: [15]) == nil)
    #expect(
      NetworkService.parseInterfaceCounters([0, 0, 0, 0], physicalInterfaceIndices: [15]) == nil)
    #expect(
      NetworkService.parseInterfaceCounters([255, 255, 0, 0], physicalInterfaceIndices: [15]) == nil
    )
    #expect(
      NetworkService.parseInterfaceCounters(
        [4, 0, UInt8(RTM_VERSION), UInt8(RTM_IFINFO2)], physicalInterfaceIndices: [15]) == nil)
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

  @Test("GPU percentages reject malformed or unsupported driver statistics")
  func gpuUsageValidation() {
    #expect(GPUService.usage(from: ["Device Utilization %": 42]) == 0.42)
    #expect(GPUService.usage(from: ["Device Utilization %": 12.5]) == 0.125)
    #expect(GPUService.usage(from: ["Device Utilization %": 0]) == 0)
    #expect(GPUService.usage(from: ["Device Utilization %": 1]) == 0.01)
    #expect(GPUService.usage(from: ["Device Utilization %": 100]) == 1)
    #expect(GPUService.usage(from: nil) == nil)
    #expect(GPUService.usage(from: [:]) == nil)
    #expect(
      GPUService.usage(from: ["Renderer Utilization %": 60, "Tiler Utilization %": 40]) == nil)
    #expect(GPUService.usage(from: ["Device Utilization %": "42"]) == nil)
    #expect(GPUService.usage(from: ["Device Utilization %": true]) == nil)
    #expect(GPUService.usage(from: ["Device Utilization %": false]) == nil)
    #expect(GPUService.usage(from: ["Device Utilization %": NSNull()]) == nil)
    for value in [-1.0, 100.1, Double.nan, .infinity, -.infinity, .greatestFiniteMagnitude] {
      #expect(GPUService.usage(from: ["Device Utilization %": value]) == nil)
    }
  }

  @Test("GPU history follows device IDs and clears missing or unavailable readings")
  @MainActor
  func gpuSnapshotHistory() async {
    let provider = MutableGPUProvider(devices: [
      GPUDeviceReading(id: 10, name: "GPU A", usage: 0.25),
      GPUDeviceReading(id: 20, name: "GPU B", usage: 0.75),
    ])
    let viewModel = SystemMonitorViewModel(
      cpuProvider: PlaceholderCPUService(),
      perCoreCPUProvider: PlaceholderPerCoreCPUService(),
      cpuTopologyProvider: PlaceholderCPUTopologyService(),
      gpuProvider: provider,
      appProcessProvider: PlaceholderAppProcessService(),
      memoryProvider: PlaceholderMemoryService(),
      networkProvider: PlaceholderNetworkService(),
      diskProvider: PlaceholderDiskService(),
      batteryProvider: PlaceholderBatteryService(),
      historyCapacity: 2
    )

    await viewModel.refreshForMonitoring()
    #expect(viewModel.snapshot.gpuUsage(for: 10) == 0.25)
    #expect(viewModel.snapshot.gpuUsage(for: 20) == 0.75)
    #expect(viewModel.snapshot.gpuUsage(for: 30) == nil)

    await provider.setDevices([
      GPUDeviceReading(id: 30, name: "New GPU", usage: 0.5),
      GPUDeviceReading(id: 20, name: "GPU B", usage: nil),
    ])
    await viewModel.refreshForMonitoring()
    #expect(viewModel.snapshot.gpuUsage(for: 10) == nil)
    #expect(viewModel.snapshot.gpuUsage(for: 20) == nil)
    #expect(viewModel.snapshot.gpuUsage(for: 30) == 0.5)
    #expect(viewModel.history.first?.gpuUsage(for: 10) == 0.25)
    #expect(viewModel.history.first?.gpuUsage(for: 30) == nil)

    await provider.setDevices([])
    await viewModel.refresh()
    #expect(viewModel.snapshot.gpuDevices.isEmpty)
    #expect(viewModel.history.count == 2)
    #expect(viewModel.history.last?.gpuDevices.isEmpty == true)
    #expect(await provider.readCount == 3)
  }

  @Test("GPU service safely supports available and unavailable driver counters")
  func liveGPUReadings() async {
    let readings = await GPUService().readGPUs()
    #expect(Set(readings.map(\.id)).count == readings.count)
    #expect(readings.map(\.id) == readings.map(\.id).sorted())
    for reading in readings {
      #expect(!reading.name.isEmpty)
      if let usage = reading.usage {
        #expect(usage.isFinite)
        #expect((0...1).contains(usage))
      }
    }
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

  @Test("Battery descriptions remain readable when the charged key is absent")
  func batteryDescriptionMissingCharged() throws {
    let description: NSDictionary = [
      kIOPSTypeKey: kIOPSInternalBatteryType,
      kIOPSCurrentCapacityKey: 75,
      kIOPSMaxCapacityKey: 100,
      kIOPSIsChargingKey: true,
      kIOPSPowerSourceStateKey: kIOPSACPowerValue,
      kIOPSTimeToFullChargeKey: 30,
    ]
    let reading = try #require(BatteryService.makeReading(from: description))
    #expect(reading.percentage == 0.75)
    #expect(reading.isCharging)
    #expect(reading.isACPowered)
    #expect(!reading.isFullyCharged)
    #expect(reading.timeToFullChargeMinutes == 30)
  }

  @Test("Battery charged fallback uses capacity but explicit system flags take precedence")
  func batteryDescriptionChargedFallback() throws {
    for capacity in [0, 75, 95, 100, 120] {
      for charged in [nil, false, true] as [Bool?] {
        var description: [String: Any] = [
          kIOPSTypeKey: kIOPSInternalBatteryType,
          kIOPSCurrentCapacityKey: capacity,
          kIOPSMaxCapacityKey: 100,
          kIOPSIsChargingKey: false,
          kIOPSPowerSourceStateKey: kIOPSACPowerValue,
        ]
        if let charged { description[kIOPSIsChargedKey] = charged }
        let reading = try #require(BatteryService.makeReading(from: description as NSDictionary))
        #expect(reading.isFullyCharged == (charged ?? (capacity >= 100)))
        #expect(reading.percentage == min(Double(capacity) / 100, 1))
      }
    }

    let unplugged: NSDictionary = [
      kIOPSTypeKey: kIOPSInternalBatteryType,
      kIOPSCurrentCapacityKey: 100,
      kIOPSMaxCapacityKey: 100,
      kIOPSIsChargingKey: false,
      kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue,
      kIOPSTimeToEmptyKey: 90,
    ]
    let reading = try #require(BatteryService.makeReading(from: unplugged))
    #expect(reading.percentage == 1)
    #expect(!reading.isFullyCharged)
    #expect(!reading.isACPowered)
    #expect(reading.timeToEmptyMinutes == 90)
  }

  @Test("Battery descriptions still reject absent batteries and invalid required fields")
  func batteryDescriptionInvalidFields() {
    let valid: [String: Any] = [
      kIOPSTypeKey: kIOPSInternalBatteryType,
      kIOPSCurrentCapacityKey: 75,
      kIOPSMaxCapacityKey: 100,
      kIOPSIsChargingKey: true,
      kIOPSPowerSourceStateKey: kIOPSACPowerValue,
    ]
    for (key, value) in [
      (kIOPSTypeKey, "UPS" as Any),
      (kIOPSIsPresentKey, false as Any),
      (kIOPSCurrentCapacityKey, -1 as Any),
      (kIOPSMaxCapacityKey, 0 as Any),
      (kIOPSPowerSourceStateKey, "Unknown" as Any),
    ] {
      var description = valid
      description[key] = value
      #expect(BatteryService.makeReading(from: description as NSDictionary) == nil)
    }
    for key in [
      kIOPSCurrentCapacityKey, kIOPSMaxCapacityKey, kIOPSIsChargingKey, kIOPSPowerSourceStateKey,
    ] {
      var description = valid
      description.removeValue(forKey: key)
      #expect(BatteryService.makeReading(from: description as NSDictionary) == nil)
    }
  }

  @Test("Battery service supports battery-equipped and batteryless Macs")
  func liveBatteryReading() async {
    let hasBattery = hasPresentInternalBattery()
    let result = await BatteryService().readBattery()
    if hasBattery == true {
      #expect(result != nil, "A present internal battery must not silently become unavailable")
    }
    guard let reading = result else {
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

  private func hasPresentInternalBattery() -> Bool? {
    guard let information = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
      let sources = IOPSCopyPowerSourcesList(information)?.takeRetainedValue() as? [AnyObject]
    else { return nil }

    return sources.contains { source in
      guard
        let description = IOPSGetPowerSourceDescription(information, source)?
          .takeUnretainedValue() as? [String: Any]
      else { return false }
      return description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
        && ((description[kIOPSIsPresentKey] as? NSNumber)?.boolValue ?? true)
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

private actor MutableGPUProvider: GPUProviding {
  private var devices: [GPUDeviceReading]
  private(set) var readCount = 0

  init(devices: [GPUDeviceReading]) {
    self.devices = devices
  }

  func setDevices(_ devices: [GPUDeviceReading]) {
    self.devices = devices
  }

  func readGPUs() async -> [GPUDeviceReading] {
    readCount += 1
    return devices
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
