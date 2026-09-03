import Darwin

actor PerCoreCPUService: PerCoreCPUProviding {
  private var previousTicks: [CPUTickSnapshot]?

  func readPerCoreCPUUsage() async -> [Double?] {
    guard let currentTicks = Self.readProcessorTicks() else {
      return []
    }

    defer { previousTicks = currentTicks }

    guard let previousTicks else {
      // Per-core counters are cumulative. Keep each core visible while the
      // first sample establishes the baseline needed for delta calculation.
      return Array(repeating: nil, count: currentTicks.count)
    }

    return Self.calculateUsages(previous: previousTicks, current: currentTicks)
  }

  static func calculateUsages(
    previous: [CPUTickSnapshot],
    current: [CPUTickSnapshot]
  ) -> [Double?] {
    current.enumerated().map { index, currentTicks in
      guard previous.indices.contains(index) else { return nil }
      return CPUService.calculateUsage(
        previous: previous[index],
        current: currentTicks
      )
    }
  }

  private static func readProcessorTicks() -> [CPUTickSnapshot]? {
    let host = mach_host_self()
    defer { mach_port_deallocate(mach_task_self_, host) }

    var processorCount: natural_t = 0
    var processorInfo: processor_info_array_t?
    var processorInfoCount: mach_msg_type_number_t = 0

    let result = host_processor_info(
      host,
      PROCESSOR_CPU_LOAD_INFO,
      &processorCount,
      &processorInfo,
      &processorInfoCount
    )

    guard result == KERN_SUCCESS, let processorInfo else { return nil }

    let address = vm_address_t(UInt(bitPattern: processorInfo))
    let byteCount = vm_size_t(processorInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
    defer { vm_deallocate(mach_task_self_, address, byteCount) }

    let stateCount = Int(CPU_STATE_MAX)
    let expectedCount = Int(processorCount) * stateCount
    guard processorCount > 0, Int(processorInfoCount) >= expectedCount else {
      return nil
    }

    return (0..<Int(processorCount)).map { processorIndex in
      let baseIndex = processorIndex * stateCount
      return CPUTickSnapshot(
        user: unsignedTick(processorInfo[baseIndex + Int(CPU_STATE_USER)]),
        system: unsignedTick(processorInfo[baseIndex + Int(CPU_STATE_SYSTEM)]),
        idle: unsignedTick(processorInfo[baseIndex + Int(CPU_STATE_IDLE)]),
        nice: unsignedTick(processorInfo[baseIndex + Int(CPU_STATE_NICE)])
      )
    }
  }

  private static func unsignedTick(_ value: integer_t) -> UInt64 {
    UInt64(UInt32(bitPattern: value))
  }
}
