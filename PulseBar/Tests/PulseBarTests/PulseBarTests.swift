import Testing

@testable import PulseBar

@Suite("PulseBar phase-one architecture")
struct PulseBarTests {
  @Test("Metric formatter presents percentages and byte rates")
  func metricFormatting() {
    #expect(MetricFormatter.percentage(0.32) == "32%")
    #expect(MetricFormatter.bytes(18 * 1_024 * 1_024 * 1_024) == "18 GB")
    #expect(MetricFormatter.rate(2.4 * 1_024 * 1_024) == "2.4 MB/s")
    #expect(MetricFormatter.percentage(nil) == "Unavailable")
  }

  @Test("View model combines provider readings into one snapshot")
  @MainActor
  func snapshotCoordination() async {
    let viewModel = SystemMonitorViewModel()

    await viewModel.refresh()

    #expect(viewModel.snapshot.cpuUsage == 0.32)
    #expect(viewModel.snapshot.memoryUsed != nil)
    #expect(viewModel.snapshot.networkDownloadBytesPerSecond != nil)
    #expect(viewModel.snapshot.diskTotal != nil)
    #expect(viewModel.snapshot.batteryPercentage == 0.83)
    #expect(viewModel.snapshot.batteryIsCharging == true)
  }

}
