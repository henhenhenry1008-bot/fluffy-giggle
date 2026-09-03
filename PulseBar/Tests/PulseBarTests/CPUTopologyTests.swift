import Foundation
import Testing

@testable import PulseBar

@Suite("CPU topology")
struct CPUTopologyTests {
  @Test("Core composition uses physical and logical counts from each system level")
  func hybridLevels() throws {
    let reading = try #require(read(hybrid))
    #expect(reading.physicalCoreCount == 12)
    #expect(reading.logicalCoreCount == 12)
    #expect(reading.performanceLevels?.map(\.id) == [0, 1])
    #expect(reading.performanceLevels?.map(\.name) == ["Performance", "Efficiency"])
    #expect(reading.performanceLevels?.map(\.physicalCoreCount) == [8, 4])
    #expect(reading.performanceLevels?.map(\.logicalCoreCount) == [8, 4])
  }

  @Test("New chip names and additional levels are not relabeled as P or E cores")
  func futureLevels() throws {
    let names = ["hw.perflevel0.name": "Super", "hw.perflevel1.name": "Performance"]
    let reading = try #require(read(hybrid, names: names))
    #expect(reading.performanceLevels?.map(\.name) == ["Super", "Performance"])

    var threeLevels = hybrid
    threeLevels["hw.nperflevels"] = 3
    threeLevels["hw.perflevel1.physicalcpu_max"] = 2
    threeLevels["hw.perflevel1.logicalcpu_max"] = 2
    threeLevels["hw.perflevel2.physicalcpu_max"] = 2
    threeLevels["hw.perflevel2.logicalcpu_max"] = 2
    let future = try #require(read(threeLevels, names: names))
    #expect(future.performanceLevels?.map(\.name) == ["Super", "Performance", "Level 2"])
    #expect(future.performanceLevels?.map(\.physicalCoreCount) == [8, 2, 2])
  }

  @Test("Symmetric SMT systems retain totals even when performance levels are unavailable")
  func symmetricAndSMT() throws {
    var counts = ["hw.physicalcpu_max": 8, "hw.logicalcpu_max": 16]
    let totalsOnly = try #require(read(counts))
    #expect(totalsOnly.physicalCoreCount == 8)
    #expect(totalsOnly.logicalCoreCount == 16)
    #expect(totalsOnly.performanceLevels == nil)
    counts["hw.nperflevels"] = 1
    counts["hw.perflevel0.physicalcpu_max"] = 8
    counts["hw.perflevel0.logicalcpu_max"] = 16
    let smt = try #require(read(counts, names: [:]))
    #expect(smt.performanceLevels?.first?.physicalCoreCount == 8)
    #expect(smt.performanceLevels?.first?.logicalCoreCount == 16)
    #expect(smt.performanceLevels?.first?.name == "Level 0")
  }

  @Test("Invalid totals are unavailable instead of zero or invented hardware")
  func invalidTotals() {
    for key in ["hw.physicalcpu_max", "hw.logicalcpu_max"] {
      for value in [nil, -1, 0] as [Int?] {
        var counts = hybrid
        counts[key] = value
        #expect(read(counts) == nil)
      }
    }
    var counts = hybrid
    counts["hw.logicalcpu_max"] = 4
    #expect(read(counts) == nil)
  }

  @Test("Partial, inconsistent, and overflowing level counts preserve totals only")
  func invalidLevels() throws {
    for (key, value) in [
      ("hw.perflevel1.physicalcpu_max", nil),
      ("hw.perflevel1.logicalcpu_max", nil),
      ("hw.perflevel1.physicalcpu_max", -1),
      ("hw.perflevel1.physicalcpu_max", 0),
      ("hw.perflevel1.logicalcpu_max", 2),
      ("hw.perflevel1.physicalcpu_max", 3),
      ("hw.perflevel1.logicalcpu_max", 5),
      ("hw.perflevel1.physicalcpu_max", Int.max),
      ("hw.perflevel1.logicalcpu_max", Int.max),
    ] as [(String, Int?)] {
      var counts = hybrid
      counts[key] = value
      let reading = try #require(read(counts))
      #expect(reading.physicalCoreCount == 12)
      #expect(reading.performanceLevels == nil)
    }
    var huge = hybrid
    huge["hw.physicalcpu_max"] = Int.max
    huge["hw.logicalcpu_max"] = Int.max
    huge["hw.perflevel0.physicalcpu_max"] = Int.max
    huge["hw.perflevel0.logicalcpu_max"] = Int.max
    #expect(try #require(read(huge)).performanceLevels == nil)
  }

  @Test("Missing or unreasonable level counts never create an unbounded query loop")
  func boundedQueries() throws {
    for count in [nil, -1, 0, 33, Int.max] as [Int?] {
      var counts = hybrid
      counts["hw.nperflevels"] = count
      var keys: [String] = []
      let reading = try #require(
        CPUTopologyService.readTopology(
          integer: { key in
            keys.append(key)
            return counts[key]
          },
          string: { _ in
            Issue.record("Invalid level counts must not query names")
            return nil
          }))
      #expect(reading.performanceLevels == nil)
      #expect(keys == ["hw.physicalcpu_max", "hw.logicalcpu_max", "hw.nperflevels"])
    }
  }

  @Test("Optional names normalize whitespace and fall back without losing core counts")
  func optionalNames() throws {
    for name in [nil, "", " \n ", "Bad\0Name"] as [String?] {
      #expect(CPUTopologyService.levelName(name, index: 3) == "Level 3")
    }
    #expect(CPUTopologyService.levelName("  Future\n Cluster  ", index: 0) == "Future Cluster")
    #expect(CPUTopologyService.levelName(String(repeating: "X", count: 300), index: 0).count == 80)
    #expect(
      try #require(read(hybrid, names: [:])).performanceLevels?.map(\.name)
        == ["Level 0", "Level 1"])
  }

  @Test("Central sampling publishes topology, preserves cadence, and clears failed readings")
  @MainActor
  func snapshotIntegration() async throws {
    let topology = try #require(read(hybrid))
    let provider = TestTopologyProvider(reading: topology)
    let viewModel = SystemMonitorViewModel(
      cpuProvider: PlaceholderCPUService(),
      perCoreCPUProvider: PlaceholderPerCoreCPUService(),
      cpuTopologyProvider: provider,
      gpuProvider: PlaceholderGPUService(),
      appProcessProvider: PlaceholderAppProcessService(),
      memoryProvider: PlaceholderMemoryService(),
      networkProvider: PlaceholderNetworkService(),
      diskProvider: PlaceholderDiskService(),
      batteryProvider: PlaceholderBatteryService(),
      historyCapacity: 2
    )
    #expect(viewModel.refreshInterval == .twoSeconds)
    for interval in MonitoringRefreshInterval.allCases {
      viewModel.changeRefreshInterval(to: interval)
      await viewModel.refreshForMonitoring()
      #expect(viewModel.snapshot.cpuTopology == topology)
      #expect(viewModel.history.last?.cpuTopology == topology)
      #expect(viewModel.refreshInterval == interval)
      #expect(viewModel.snapshot.cpuUsage == 0.32)
      #expect(viewModel.snapshot.batteryPercentage == 0.83)
    }
    await provider.fail()
    await viewModel.refresh()
    #expect(viewModel.snapshot.cpuTopology == nil)
    #expect(viewModel.history.last?.cpuTopology == nil)
    #expect(viewModel.history.count == 2)
  }

  @Test("Live topology reports valid totals and stable hardware composition")
  func liveTopology() async throws {
    let service = CPUTopologyService()
    let reading = try #require(await service.readCPUTopology())
    #expect(reading.physicalCoreCount > 0)
    #expect(reading.logicalCoreCount >= reading.physicalCoreCount)
    #expect(reading.logicalCoreCount == ProcessInfo.processInfo.processorCount)
    #expect(await service.readCPUTopology() == reading)
    if let levels = reading.performanceLevels {
      #expect(!levels.isEmpty && levels.count <= CPUTopologyService.maximumPerformanceLevels)
      #expect(levels.reduce(0) { $0 + $1.physicalCoreCount } == reading.physicalCoreCount)
      #expect(levels.reduce(0) { $0 + $1.logicalCoreCount } == reading.logicalCoreCount)
      #expect(levels.allSatisfy { !$0.name.isEmpty })
    }
  }

  private var hybrid: [String: Int] {
    [
      "hw.physicalcpu_max": 12, "hw.logicalcpu_max": 12, "hw.nperflevels": 2,
      "hw.perflevel0.physicalcpu_max": 8, "hw.perflevel0.logicalcpu_max": 8,
      "hw.perflevel1.physicalcpu_max": 4, "hw.perflevel1.logicalcpu_max": 4,
    ]
  }

  private func read(
    _ counts: [String: Int],
    names: [String: String] = [
      "hw.perflevel0.name": "Performance", "hw.perflevel1.name": "Efficiency",
    ]
  ) -> CPUTopologyReading? {
    CPUTopologyService.readTopology(integer: { counts[$0] }, string: { names[$0] })
  }
}

private actor TestTopologyProvider: CPUTopologyProviding {
  var reading: CPUTopologyReading?
  init(reading: CPUTopologyReading?) { self.reading = reading }
  func readCPUTopology() async -> CPUTopologyReading? { reading }
  func fail() { reading = nil }
}
