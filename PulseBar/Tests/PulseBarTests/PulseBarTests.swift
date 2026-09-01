import Testing

@testable import PulseBar

@Suite("PulseBar monitoring")
struct PulseBarTests {
  @Test("Metric formatter presents percentages and byte rates")
  func metricFormatting() {
    #expect(MetricFormatter.percentage(0.32) == "32%")
    #expect(MetricFormatter.bytes(18 * 1_024 * 1_024 * 1_024) == "18 GiB")
    #expect(MetricFormatter.rate(2.4 * 1_024 * 1_024) == "2.4 MiB/s")
    #expect(MetricFormatter.percentage(nil) == "Unavailable")
  }

  @Test("View model combines provider readings into one snapshot")
  @MainActor
  func snapshotCoordination() async {
    let viewModel = SystemMonitorViewModel(
      cpuProvider: PlaceholderCPUService(usage: 0.32),
      memoryProvider: PlaceholderMemoryService()
    )

    await viewModel.refresh()

    #expect(viewModel.snapshot.cpuUsage == 0.32)
    #expect(viewModel.snapshot.memoryUsed != nil)
    #expect(viewModel.snapshot.networkDownloadBytesPerSecond != nil)
    #expect(viewModel.snapshot.diskTotal != nil)
    #expect(viewModel.snapshot.batteryPercentage == 0.83)
    #expect(viewModel.snapshot.batteryIsCharging == true)
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
    try await Task.sleep(for: .milliseconds(100))

    let usage = await service.readCPUUsage()
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
}
