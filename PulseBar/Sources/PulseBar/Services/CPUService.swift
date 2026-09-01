import Darwin

struct CPUTickSnapshot: Equatable, Sendable {
  let user: UInt64
  let system: UInt64
  let idle: UInt64
  let nice: UInt64
}

actor CPUService: CPUProviding {
  private var previousTicks: CPUTickSnapshot?

  func readCPUUsage() async -> Double? {
    guard let currentTicks = Self.readSystemTicks() else {
      return nil
    }

    defer { previousTicks = currentTicks }

    guard let previousTicks else {
      // CPU counters are cumulative, so the first sample only establishes a baseline.
      return nil
    }

    return Self.calculateUsage(previous: previousTicks, current: currentTicks)
  }

  static func calculateUsage(
    previous: CPUTickSnapshot,
    current: CPUTickSnapshot
  ) -> Double? {
    let user = tickDelta(previous: previous.user, current: current.user)
    let system = tickDelta(previous: previous.system, current: current.system)
    let idle = tickDelta(previous: previous.idle, current: current.idle)
    let nice = tickDelta(previous: previous.nice, current: current.nice)

    let busy = user + system + nice
    let total = busy + idle

    guard total > 0 else { return nil }
    return Double(busy) / Double(total)
  }

  private static func readSystemTicks() -> CPUTickSnapshot? {
    var loadInfo = host_cpu_load_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
    )

    // host_statistics fills host_cpu_load_info_data_t with cumulative system-wide
    // ticks in user, system, idle, and nice states. It does not report this app's
    // process usage, and it works on both Apple Silicon and Intel Macs.
    let result = withUnsafeMutablePointer(to: &loadInfo) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
        host_statistics(
          mach_host_self(),
          HOST_CPU_LOAD_INFO,
          reboundPointer,
          &count
        )
      }
    }

    guard result == KERN_SUCCESS else { return nil }

    let ticks = loadInfo.cpu_ticks
    return CPUTickSnapshot(
      user: UInt64(ticks.0),
      system: UInt64(ticks.1),
      idle: UInt64(ticks.2),
      nice: UInt64(ticks.3)
    )
  }

  private static func tickDelta(previous: UInt64, current: UInt64) -> UInt64 {
    if current >= previous {
      return current - previous
    }

    // Mach exposes natural_t counters. Account for a UInt32 wrap instead of
    // producing a negative or implausibly large utilization value.
    return UInt64(UInt32.max) - previous + current + 1
  }
}
