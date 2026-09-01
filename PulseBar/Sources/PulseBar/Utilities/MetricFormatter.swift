import Foundation

enum MetricFormatter {
  static func percentage(_ fraction: Double?) -> String {
    guard let fraction, fraction.isFinite else { return "Unavailable" }
    return String(format: "%.0f%%", min(max(fraction, 0), 1) * 100)
  }

  static func bytes(_ bytes: UInt64?) -> String {
    guard let bytes else { return "Unavailable" }
    return scaledBytes(Double(bytes))
  }

  static func rate(_ bytesPerSecond: Double?) -> String {
    guard let bytesPerSecond, bytesPerSecond.isFinite, bytesPerSecond >= 0 else {
      return "Unavailable"
    }
    return "\(scaledBytes(bytesPerSecond))/s"
  }

  private static func scaledBytes(_ bytes: Double) -> String {
    let units = ["B", "KB", "MB", "GB", "TB"]
    var value = max(bytes, 0)
    var unitIndex = 0

    while value >= 1_024, unitIndex < units.count - 1 {
      value /= 1_024
      unitIndex += 1
    }

    let decimals = value >= 10 || unitIndex == 0 ? 0 : 1
    return "\(String(format: "%.*f", decimals, value)) \(units[unitIndex])"
  }
}
