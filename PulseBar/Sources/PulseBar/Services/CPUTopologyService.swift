import Darwin
import Foundation

actor CPUTopologyService: CPUTopologyProviding {
  static let maximumPerformanceLevels = 32
  private var cachedReading: CPUTopologyReading?

  func readCPUTopology() async -> CPUTopologyReading? {
    if let cachedReading { return cachedReading }

    // The *_max values describe hardware composition, not currently scheduled
    // or enabled cores. Cache successful reads for this app session.
    let reading = Self.readTopology(integer: Self.readInteger, string: Self.readString)
    cachedReading = reading
    return reading
  }

  static func readTopology(
    integer: (String) -> Int?,
    string: (String) -> String?
  ) -> CPUTopologyReading? {
    guard let physical = integer("hw.physicalcpu_max"), physical > 0,
      let logical = integer("hw.logicalcpu_max"), logical >= physical
    else { return nil }

    let totalsOnly = CPUTopologyReading(
      physicalCoreCount: physical, logicalCoreCount: logical, performanceLevels: nil)

    // Apple documents the level counts and ordering (lower index is faster).
    // Do not assume that level 0 is P and level 1 is E: newer chips can expose
    // Super/Performance, and symmetric or restricted systems may lack levels.
    guard let count = integer("hw.nperflevels"),
      (1...maximumPerformanceLevels).contains(count)
    else { return totalsOnly }

    var levels: [CPUPerformanceLevelReading] = []
    var physicalSum = 0
    var logicalSum = 0
    for index in 0..<count {
      let prefix = "hw.perflevel\(index)"
      guard let levelPhysical = integer("\(prefix).physicalcpu_max"), levelPhysical > 0,
        let levelLogical = integer("\(prefix).logicalcpu_max"), levelLogical >= levelPhysical,
        levelPhysical <= physical - physicalSum,
        levelLogical <= logical - logicalSum
      else { return totalsOnly }

      // Subtraction guards above also prevent overflow while summing bad data.
      physicalSum += levelPhysical
      logicalSum += levelLogical
      levels.append(
        CPUPerformanceLevelReading(
          id: index,
          name: levelName(string("\(prefix).name"), index: index),
          physicalCoreCount: levelPhysical,
          logicalCoreCount: levelLogical
        ))
    }

    // Never present an incomplete breakdown as the complete CPU composition.
    guard physicalSum == physical, logicalSum == logical else { return totalsOnly }
    return CPUTopologyReading(
      physicalCoreCount: physical, logicalCoreCount: logical, performanceLevels: levels)
  }

  static func levelName(_ name: String?, index: Int) -> String {
    guard let name else { return "Level \(index)" }
    let normalized = name.components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }.joined(separator: " ")
    guard !normalized.isEmpty,
      normalized.rangeOfCharacter(from: .controlCharacters) == nil
    else { return "Level \(index)" }
    return String(normalized.prefix(80))
  }

  private static func readInteger(_ key: String) -> Int? {
    // These documented integer sysctls use C int, not Swift's pointer-sized Int.
    var value: Int32 = 0
    var size = MemoryLayout<Int32>.size
    guard sysctlbyname(key, &value, &size, nil, 0) == 0,
      size == MemoryLayout<Int32>.size
    else { return nil }
    return Int(value)
  }

  private static func readString(_ key: String) -> String? {
    // The optional .name field is published in Apple's XNU source, but its
    // vocabulary is not an API contract. Missing/invalid names use Level N.
    var size = 0
    guard sysctlbyname(key, nil, &size, nil, 0) == 0, (2...256).contains(size)
    else { return nil }
    var bytes = [UInt8](repeating: 0, count: size)
    let capacity = bytes.count
    let result = bytes.withUnsafeMutableBytes {
      sysctlbyname(key, $0.baseAddress, &size, nil, 0)
    }
    guard result == 0, (2...capacity).contains(size), bytes[size - 1] == 0 else { return nil }
    return String(bytes: bytes.prefix(size - 1), encoding: .utf8)
  }
}
