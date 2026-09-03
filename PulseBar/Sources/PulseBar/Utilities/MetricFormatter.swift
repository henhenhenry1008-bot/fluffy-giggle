import Foundation

enum MetricFormatter {
  static func percentage(_ fraction: Double?) -> String {
    guard let fraction, fraction.isFinite else { return "Unavailable" }
    return String(format: "%.0f%%", min(max(fraction, 0), 1) * 100)
  }

  static func compactPercentage(_ fraction: Double?) -> String {
    guard let fraction, fraction.isFinite else { return "—" }
    return String(format: "%.0f%%", min(max(fraction, 0), 1) * 100)
  }

  static func bytes(_ bytes: UInt64?) -> String {
    guard let bytes else { return "Unavailable" }
    return scaledBytes(Double(bytes))
  }

  static func rate(
    _ bytesPerSecond: Double?,
    unit: NetworkDisplayUnit = .automatic
  ) -> String {
    guard let bytesPerSecond, bytesPerSecond.isFinite, bytesPerSecond >= 0 else {
      return "Unavailable"
    }

    switch unit {
    case .automatic:
      return "\(scaledBytes(bytesPerSecond))/s"
    case .bytesPerSecond:
      return
        "\(scaledValue(bytesPerSecond, divisor: 1_000, units: ["B", "KB", "MB", "GB", "TB"], separator: " "))/s"
    case .bitsPerSecond:
      guard let bitsPerSecond = bitsPerSecond(from: bytesPerSecond) else {
        return "Unavailable"
      }
      return
        "\(scaledValue(bitsPerSecond, divisor: 1_000, units: ["b", "Kb", "Mb", "Gb", "Tb"], separator: " "))/s"
    }
  }

  static func compactRate(
    _ bytesPerSecond: Double?,
    unit: NetworkDisplayUnit = .automatic
  ) -> String {
    guard let bytesPerSecond, bytesPerSecond.isFinite, bytesPerSecond >= 0 else {
      return "—"
    }

    switch unit {
    case .automatic:
      return scaledValue(
        bytesPerSecond,
        divisor: 1_024,
        units: ["B", "K", "M", "G", "T"],
        separator: ""
      )
    case .bytesPerSecond:
      return scaledValue(
        bytesPerSecond,
        divisor: 1_000,
        units: ["B", "KB", "MB", "GB", "TB"],
        separator: ""
      )
    case .bitsPerSecond:
      guard let bitsPerSecond = bitsPerSecond(from: bytesPerSecond) else {
        return "—"
      }
      return scaledValue(
        bitsPerSecond,
        divisor: 1_000,
        units: ["b", "Kb", "Mb", "Gb", "Tb"],
        separator: ""
      )
    }
  }

  static func duration(minutes: Int?) -> String {
    guard let minutes, minutes >= 0 else { return "Unavailable" }
    guard minutes > 0 else { return "<1m" }

    let hours = minutes / 60
    let remainingMinutes = minutes % 60

    if hours == 0 {
      return "\(remainingMinutes)m"
    }
    if remainingMinutes == 0 {
      return "\(hours)h"
    }
    return "\(hours)h \(remainingMinutes)m"
  }

  private static func bitsPerSecond(from bytesPerSecond: Double) -> Double? {
    guard bytesPerSecond <= Double.greatestFiniteMagnitude / 8 else { return nil }
    return bytesPerSecond * 8
  }

  private static func scaledBytes(_ bytes: Double) -> String {
    scaledValue(
      bytes,
      divisor: 1_024,
      units: ["B", "KiB", "MiB", "GiB", "TiB"],
      separator: " "
    )
  }

  private static func scaledValue(
    _ rawValue: Double,
    divisor: Double,
    units: [String],
    separator: String
  ) -> String {
    var value = max(rawValue, 0)
    var unitIndex = 0

    while value >= divisor, unitIndex < units.count - 1 {
      value /= divisor
      unitIndex += 1
    }

    let decimals = value >= 10 || unitIndex == 0 ? 0 : 1
    return "\(String(format: "%.*f", decimals, value))\(separator)\(units[unitIndex])"
  }
}
