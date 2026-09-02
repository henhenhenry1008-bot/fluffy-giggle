import Darwin

actor MemoryService: MemoryProviding {
  private var cachedConfiguration: MemorySystemConfiguration?

  func readMemory() async -> MemoryReading? {
    let configuration: MemorySystemConfiguration
    if let cachedConfiguration {
      configuration = cachedConfiguration
    } else {
      guard let loadedConfiguration = Self.readSystemConfiguration() else {
        return nil
      }
      cachedConfiguration = loadedConfiguration
      configuration = loadedConfiguration
    }

    guard let statistics = Self.readVMStatistics() else { return nil }

    return Self.makeReading(
      totalBytes: configuration.totalBytes,
      pageSize: configuration.pageSize,
      freePages: UInt64(statistics.free_count),
      activePages: UInt64(statistics.active_count),
      inactivePages: UInt64(statistics.inactive_count),
      wiredPages: UInt64(statistics.wire_count),
      compressedPages: UInt64(statistics.compressor_page_count),
      purgeablePages: UInt64(statistics.purgeable_count)
    )
  }

  static func makeReading(
    totalBytes: UInt64,
    pageSize: UInt64,
    freePages: UInt64,
    activePages: UInt64,
    inactivePages: UInt64,
    wiredPages: UInt64,
    compressedPages: UInt64,
    purgeablePages: UInt64
  ) -> MemoryReading {
    let freeBytes = bytes(forPages: freePages, pageSize: pageSize)
    let activeBytes = bytes(forPages: activePages, pageSize: pageSize)
    let inactiveBytes = bytes(forPages: inactivePages, pageSize: pageSize)
    let wiredBytes = bytes(forPages: wiredPages, pageSize: pageSize)
    let compressedBytes = bytes(forPages: compressedPages, pageSize: pageSize)
    let purgeableBytes = bytes(forPages: purgeablePages, pageSize: pageSize)

    // Inactive pages are readily reclaimable on macOS. Treating them as
    // available produces a pressure-oriented usage figure instead of the
    // misleading total-minus-free value. Speculative pages are already part
    // of free_count according to the Mach API and must not be added again.
    let availableBytes = min(totalBytes, saturatingAdd(freeBytes, inactiveBytes))
    let usedBytes = totalBytes - availableBytes

    return MemoryReading(
      usedBytes: usedBytes,
      totalBytes: totalBytes,
      availableBytes: availableBytes,
      freeBytes: min(freeBytes, totalBytes),
      activeBytes: min(activeBytes, totalBytes),
      inactiveBytes: min(inactiveBytes, totalBytes),
      wiredBytes: min(wiredBytes, totalBytes),
      compressedBytes: min(compressedBytes, totalBytes),
      purgeableBytes: min(purgeableBytes, totalBytes)
    )
  }

  private static func readPhysicalMemorySize() -> UInt64? {
    var totalBytes: UInt64 = 0
    var size = MemoryLayout<UInt64>.size
    let result = sysctlbyname("hw.memsize", &totalBytes, &size, nil, 0)
    return result == 0 && totalBytes > 0 ? totalBytes : nil
  }

  private static func readSystemConfiguration() -> MemorySystemConfiguration? {
    guard let totalBytes = readPhysicalMemorySize() else { return nil }

    let host = mach_host_self()
    defer { mach_port_deallocate(mach_task_self_, host) }

    var pageSize: vm_size_t = 0
    guard host_page_size(host, &pageSize) == KERN_SUCCESS, pageSize > 0 else {
      return nil
    }

    return MemorySystemConfiguration(
      totalBytes: totalBytes,
      pageSize: UInt64(pageSize)
    )
  }

  private static func readVMStatistics() -> vm_statistics64_data_t? {
    let host = mach_host_self()
    defer { mach_port_deallocate(mach_task_self_, host) }

    var statistics = vm_statistics64_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
    )

    let result = withUnsafeMutablePointer(to: &statistics) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
        host_statistics64(host, HOST_VM_INFO64, reboundPointer, &count)
      }
    }

    guard result == KERN_SUCCESS else { return nil }
    return statistics
  }

  private static func bytes(forPages pages: UInt64, pageSize: UInt64) -> UInt64 {
    let result = pages.multipliedReportingOverflow(by: pageSize)
    return result.overflow ? UInt64.max : result.partialValue
  }

  private static func saturatingAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
    let result = lhs.addingReportingOverflow(rhs)
    return result.overflow ? UInt64.max : result.partialValue
  }
}

private struct MemorySystemConfiguration: Sendable {
  let totalBytes: UInt64
  let pageSize: UInt64
}
