// Developer-only, read-only capability check. Not part of the app or test target.
// Run with the app's existing sandbox entitlement; do not use sudo or grant
// additional entitlements to make a denied check succeed.
import Darwin
import Foundation
import IOKit
import Metal

@main
struct SensorCapabilityProbe {
  static func main() {
    print("OS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
    print("Running as root: \(geteuid() == 0)")

    for key in ["hw.cpufrequency", "hw.cpufrequency_min", "hw.cpufrequency_max"] {
      checkFrequency(key)
    }

    // ThermalState is a severity category, not a temperature in degrees Celsius.
    print("System thermal state (category only): \(ProcessInfo.processInfo.thermalState.rawValue)")
    checkSMCConnection()
    checkExistingGPUStatistics()
  }

  private static func checkFrequency(_ key: String) {
    var size = 0
    let query = sysctlbyname(key, nil, &size, nil, 0)
    let queryError = errno
    guard query == 0 else {
      print("\(key): unavailable; errno=\(queryError)")
      return
    }

    let expectedSize = size
    let result: Int32
    let value: UInt64
    switch size {
    case MemoryLayout<UInt32>.size:
      var number: UInt32 = 0
      result = sysctlbyname(key, &number, &size, nil, 0)
      value = UInt64(number)
    case MemoryLayout<UInt64>.size:
      var number: UInt64 = 0
      result = sysctlbyname(key, &number, &size, nil, 0)
      value = number
    default:
      print("\(key): no supported numeric payload; bytes=\(size)")
      return
    }
    let readError = errno
    guard result == 0, size == expectedSize, value > 0 else {
      print(
        "\(key): unavailable; result=\(result), errno=\(readError), bytes=\(size), value=\(value)")
      return
    }
    // A readable legacy value alone does not establish a live clock frequency.
    print("\(key): raw value=\(value); live-frequency semantics not established")
  }

  private static func checkSMCConnection() {
    guard let matching = IOServiceMatching("AppleSMC") else {
      print("AppleSMC: matching unavailable")
      return
    }
    // IOServiceGetMatchingService consumes the matching dictionary.
    let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
    guard service != 0 else {
      print("AppleSMC: service unavailable")
      return
    }
    defer { IOObjectRelease(service) }

    var connection: io_connect_t = 0
    let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
    defer {
      if connection != 0 { IOServiceClose(connection) }
    }
    let reason = mach_error_string(result).map { String(cString: $0) } ?? "unknown"
    print("AppleSMC IOServiceOpen: 0x\(String(UInt32(bitPattern: result), radix: 16)) \(reason)")
    // Deliberately do not call SMC read/write commands, change fan targets, or
    // load private frameworks. This check only opens and closes a connection.
  }

  private static func checkExistingGPUStatistics() {
    for device in MTLCopyAllDevices().prefix(32) {
      guard let matching = IORegistryEntryIDMatching(device.registryID) else { continue }
      let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
      guard service != 0 else { continue }
      defer { IOObjectRelease(service) }
      let statistics =
        IORegistryEntryCreateCFProperty(
          service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? [String: Any]
      guard let statistics else {
        print("GPU \(device.name): existing statistics unavailable")
        continue
      }
      let candidates = statistics.keys.filter { key in
        ["temperature", "frequency", "clock", "power"].contains { key.lowercased().contains($0) }
      }.sorted()
      print("GPU \(device.name): temperature/frequency/clock/power candidate keys: \(candidates)")
      print("Candidate names alone do not establish units, freshness, or sensor support.")
    }
  }
}
