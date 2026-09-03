import Foundation
import IOKit
import Metal

actor GPUService: GPUProviding {
  // These driver properties are undocumented and may change with macOS updates.
  // Only the IOKit access functions and Metal device enumeration are public APIs.
  private static let statisticsKey = "PerformanceStatistics"
  private static let utilizationKey = "Device Utilization %"

  func readGPUs() async -> [GPUDeviceReading] {
    // Re-enumerate to handle removable GPUs. Do not retain Metal devices or
    // IOKit handles between samples, or create command queues to measure load.
    MTLCopyAllDevices().map { device in
      let statistics = Self.readStatistics(registryID: device.registryID)
      let name = device.name.trimmingCharacters(in: .whitespacesAndNewlines)
      return GPUDeviceReading(
        id: device.registryID,
        name: name.isEmpty ? "GPU" : name,
        usage: Self.usage(from: statistics)
      )
    }
    .sorted { $0.id < $1.id }
  }

  static func usage(from statistics: [String: Any]?) -> Double? {
    guard let number = statistics?[utilizationKey] as? NSNumber,
      CFGetTypeID(number) != CFBooleanGetTypeID()
    else {
      return nil
    }

    let percentage = number.doubleValue
    guard percentage.isFinite, (0...100).contains(percentage) else { return nil }

    // This is a driver-reported percentage, not a cumulative counter. Renderer
    // and tiler values can overlap and must not be summed or used as fallbacks.
    return percentage / 100
  }

  private static func readStatistics(registryID: UInt64) -> [String: Any]? {
    guard let matching = IORegistryEntryIDMatching(registryID) else { return nil }

    // Matching by Metal's registry ID avoids attaching one GPU's counters to
    // another GPU. IOServiceGetMatchingService consumes the matching dictionary.
    let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
    guard service != 0 else { return nil }
    defer { IOObjectRelease(service) }

    return IORegistryEntryCreateCFProperty(
      service,
      statisticsKey as CFString,
      kCFAllocatorDefault,
      0
    )?.takeRetainedValue() as? [String: Any]
  }
}
