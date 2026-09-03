import Foundation
import Testing

@testable import PulseBar

@Suite("Application process monitoring")
struct AppProcessTests {
  @Test("Process CPU converts Mach ticks and preserves multi-core percentages")
  func cpuTimebase() throws {
    let instant = ContinuousClock.now
    let first = sample(at: instant)
    let second = sample(user: 24_000_000, system: 24_000_000, at: instant.advanced(by: .seconds(1)))
    let usage = try #require(
      AppProcessTracker.cpuUsage(previous: first, current: second, secondsPerTick: 125.0 / 3 / 1e9))
    #expect(abs(usage - 2) < 0.000001)
    #expect(MetricFormatter.processCPU(usage) == "200.0%")
    #expect(MetricFormatter.processCPU(0) == "0.0%")
    #expect(MetricFormatter.processCPU(nil) == "—")
    for invalid in [-1.0, .nan, .infinity, .greatestFiniteMagnitude] {
      #expect(MetricFormatter.processCPU(invalid) == "—")
    }
  }

  @Test("Process CPU rejects missing baselines, PID reuse, resets, and invalid intervals")
  func cpuInvalidSamples() {
    let instant = ContinuousClock.now
    let first = sample(user: 10, system: 10, at: instant)
    let next = instant.advanced(by: .seconds(1))
    let valid = sample(user: 20, system: 20, at: next)
    #expect(AppProcessTracker.cpuUsage(previous: nil, current: valid, secondsPerTick: 1e-9) == nil)
    for invalid in [
      sample(start: 2, user: 20, system: 20, at: next),
      sample(pid: 11, user: 20, system: 20, at: next),
      sample(user: 9, system: 20, at: next),
      sample(user: 20, system: 9, at: next),
      sample(user: 20, system: 20, at: instant),
      sample(user: 20, system: 20, at: instant.advanced(by: .seconds(-1))),
    ] {
      #expect(
        AppProcessTracker.cpuUsage(previous: first, current: invalid, secondsPerTick: 1e-9) == nil)
    }
    for timebase: Double? in [nil, 0, -1, .nan, .infinity, .greatestFiniteMagnitude] {
      #expect(
        AppProcessTracker.cpuUsage(previous: first, current: valid, secondsPerTick: timebase) == nil
      )
    }
  }

  @Test("Process CPU subtracts before conversion and adds without integer overflow")
  func cpuLargeCounters() throws {
    let instant = ContinuousClock.now
    let current = sample(user: .max, system: .max, at: instant.advanced(by: .seconds(1)))
    let previous = sample(user: .max - 100, system: .max - 100, at: instant)
    let usage = try #require(
      AppProcessTracker.cpuUsage(previous: previous, current: current, secondsPerTick: 0.001))
    #expect(abs(usage - 0.2) < 0.000001)
    let large = try #require(
      AppProcessTracker.cpuUsage(
        previous: sample(at: instant), current: current, secondsPerTick: 1e-9))
    #expect(large.isFinite && large > 0)
  }

  @Test("Top processes are bounded, deduplicated, CPU-ranked, and stable on ties")
  func ranking() {
    let instant = ContinuousClock.now
    let baseline = (1...7).map { sample(pid: Int32($0), resident: UInt64($0) * 100, at: instant) }
    var tracker = AppProcessTracker()
    let first = tracker.update(
      samples: baseline, listedCount: 9, queriedCount: 9, secondsPerTick: 0.001)
    #expect(first.topProcesses.count == 5)
    #expect(first.topProcesses.allSatisfy { $0.cpuUsage == nil })
    #expect(first.readableCount == 7)

    var current = (1...7).map {
      sample(
        pid: Int32($0), user: UInt64(8 - $0) * 1_000, resident: 100,
        at: instant.advanced(by: .seconds(1)))
    }
    current.append(current[0])
    let ranked = tracker.update(
      samples: current, listedCount: 9, queriedCount: 9, secondsPerTick: 0.001)
    #expect(ranked.topProcesses.map(\.id.pid) == [1, 2, 3, 4, 5])
    #expect(ranked.readableCount == 7)
    #expect(tracker.previous.count == 7)

    let ties = (1...7).reversed().map { sample(pid: Int32($0), resident: 100, at: instant) }
    var tieTracker = AppProcessTracker()
    let tied = tieTracker.update(
      samples: ties, listedCount: 7, queriedCount: 7, secondsPerTick: 0.001)
    #expect(tied.topProcesses.map(\.id.pid) == [1, 2, 3, 4, 5])
  }

  @Test("Exits, unavailable reads, and PID reuse discard old baselines")
  func lifecycle() {
    let instant = ContinuousClock.now
    var tracker = AppProcessTracker()
    _ = tracker.update(
      samples: [sample(user: 100, at: instant)], listedCount: 1, queriedCount: 1,
      secondsPerTick: 0.001)
    let reused = tracker.update(
      samples: [sample(start: 2, user: 200, at: instant.advanced(by: .seconds(1)))],
      listedCount: 1, queriedCount: 1, secondsPerTick: 0.001)
    #expect(reused.topProcesses.first?.cpuUsage == nil)
    #expect(tracker.previous.count == 1)
    let missing = tracker.update(
      samples: [], listedCount: 1, queriedCount: 1, secondsPerTick: 0.001)
    #expect(missing.topProcesses.isEmpty)
    #expect(missing.readableCount == 0)
    #expect(tracker.previous.isEmpty)
    let reappeared = tracker.update(
      samples: [sample(start: 2, user: 300, at: instant.advanced(by: .seconds(3)))],
      listedCount: 1, queriedCount: 1, secondsPerTick: 0.001)
    #expect(reappeared.topProcesses.first?.cpuUsage == nil)
  }

  @Test("Application processes follow all four refresh options and clear failed readings")
  @MainActor
  func cadenceAndFailures() async {
    var date = Date(timeIntervalSince1970: 1_000)
    let provider = TestAppProcessProvider()
    let viewModel = SystemMonitorViewModel(
      cpuProvider: PlaceholderCPUService(),
      perCoreCPUProvider: PlaceholderPerCoreCPUService(),
      cpuTopologyProvider: PlaceholderCPUTopologyService(),
      gpuProvider: PlaceholderGPUService(),
      appProcessProvider: provider,
      memoryProvider: PlaceholderMemoryService(),
      networkProvider: PlaceholderNetworkService(),
      diskProvider: PlaceholderDiskService(),
      batteryProvider: PlaceholderBatteryService(),
      historyCapacity: 2,
      now: { date }
    )
    #expect(viewModel.refreshInterval == .twoSeconds)
    for (index, interval) in MonitoringRefreshInterval.allCases.enumerated() {
      viewModel.changeRefreshInterval(to: interval)
      date.addTimeInterval(interval.rawValue)
      await viewModel.refreshForMonitoring()
      #expect(viewModel.refreshInterval == interval)
      #expect(await provider.readCount == index + 1)
      #expect(viewModel.snapshot.appProcesses?.readableCount == 1)
    }
    await provider.fail()
    await viewModel.refresh()
    #expect(await provider.readCount == 5)
    #expect(viewModel.snapshot.appProcesses == nil)
    #expect(viewModel.history.count == 2)
    #expect(viewModel.history.last?.appProcesses == nil)
    date.addTimeInterval(-5)
    await viewModel.refreshForMonitoring()
    #expect(await provider.readCount == 6)
  }

  @Test("Live app process reads tolerate sandbox restrictions and remain bounded")
  func liveReadings() async throws {
    let service = AppProcessService()
    let reading = try #require(await service.readAppProcesses())
    #expect(reading.topProcesses.count <= 5)
    #expect(reading.queriedCount <= AppProcessService.maximumCandidates)
    #expect(reading.readableCount <= reading.queriedCount)
    #expect(reading.queriedCount <= reading.listedCount)
    #expect(Set(reading.topProcesses.map(\.id)).count == reading.topProcesses.count)
    for process in reading.topProcesses {
      #expect(process.id.pid > 0 && process.id.startSeconds > 0)
      #expect(!process.name.isEmpty)
      #expect(process.cpuUsage == nil)
    }
  }

  private func sample(
    pid: Int32 = 10, start: UInt64 = 1,
    user: UInt64 = 0, system: UInt64 = 0, resident: UInt64 = 100,
    at instant: ContinuousClock.Instant
  ) -> AppProcessSample {
    AppProcessSample(
      id: AppProcessID(pid: pid, startSeconds: start, startMicroseconds: 0),
      name: "Process \(pid)", userTicks: user, systemTicks: system,
      residentBytes: resident, instant: instant)
  }
}

private actor TestAppProcessProvider: AppProcessProviding {
  private(set) var readCount = 0
  private var reading: AppProcessListReading? = AppProcessListReading(
    topProcesses: [
      AppProcessReading(
        id: AppProcessID(pid: 10, startSeconds: 1, startMicroseconds: 0),
        name: "Test", cpuUsage: 2, residentBytes: 100)
    ],
    listedCount: 2, queriedCount: 2, readableCount: 1)

  func fail() { reading = nil }

  func readAppProcesses() async -> AppProcessListReading? {
    readCount += 1
    return reading
  }
}
