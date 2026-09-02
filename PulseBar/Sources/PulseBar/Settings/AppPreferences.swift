import SwiftUI

enum AppPreferenceKey {
  static let refreshInterval = "preferences.monitoring.refreshInterval"
  static let historyLength = "preferences.monitoring.historyLength"
  static let networkDisplayUnit = "preferences.monitoring.networkDisplayUnit"
  static let showsCPU = "preferences.menuBar.showsCPU"
  static let showsMemory = "preferences.menuBar.showsMemory"
  static let showsNetworkDownload = "preferences.menuBar.showsNetworkDownload"
  static let showsNetworkUpload = "preferences.menuBar.showsNetworkUpload"
  static let showsBattery = "preferences.menuBar.showsBattery"
  static let appearance = "preferences.appearance.colorScheme"
}

enum MonitoringHistoryLength: Int, CaseIterable, Identifiable, Sendable {
  case oneMinute = 60
  case twoMinutes = 120
  case fiveMinutes = 300

  var id: Int { rawValue }

  var displayName: String {
    "\(rawValue) samples"
  }
}

enum NetworkDisplayUnit: String, CaseIterable, Identifiable, Sendable {
  case automatic
  case bytesPerSecond
  case bitsPerSecond

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .automatic: "Automatic"
    case .bytesPerSecond: "Bytes/sec"
    case .bitsPerSecond: "Bits/sec"
    }
  }
}

enum AppearancePreference: String, CaseIterable, Identifiable, Sendable {
  case system
  case light
  case dark

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .system: "System"
    case .light: "Light"
    case .dark: "Dark"
    }
  }

  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
}

struct MenuBarMetricVisibility: Equatable, Sendable {
  var showsCPU: Bool
  var showsMemory: Bool
  var showsNetworkDownload: Bool
  var showsNetworkUpload: Bool
  var showsBattery: Bool

  static let standard = MenuBarMetricVisibility(
    showsCPU: true,
    showsMemory: true,
    showsNetworkDownload: true,
    showsNetworkUpload: false,
    showsBattery: false
  )

  func isVisible(_ metric: MenuBarMetric) -> Bool {
    switch metric {
    case .cpu: showsCPU
    case .memory: showsMemory
    case .networkDownload: showsNetworkDownload
    case .networkUpload: showsNetworkUpload
    case .battery: showsBattery
    }
  }
}
