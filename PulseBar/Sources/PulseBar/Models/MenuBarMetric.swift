enum MenuBarMetric: String, CaseIterable, Identifiable, Sendable {
  case cpu
  case memory
  case networkDownload
  case networkUpload
  case battery

  var id: String { rawValue }

  var settingsTitle: String {
    switch self {
    case .cpu: "CPU"
    case .memory: "Memory"
    case .networkDownload: "Network Download"
    case .networkUpload: "Network Upload"
    case .battery: "Battery"
    }
  }

  var preferenceKey: String {
    switch self {
    case .cpu: AppPreferenceKey.showsCPU
    case .memory: AppPreferenceKey.showsMemory
    case .networkDownload: AppPreferenceKey.showsNetworkDownload
    case .networkUpload: AppPreferenceKey.showsNetworkUpload
    case .battery: AppPreferenceKey.showsBattery
    }
  }

  var isVisibleByDefault: Bool {
    switch self {
    case .cpu, .memory, .networkDownload:
      true
    case .networkUpload, .battery:
      false
    }
  }
}
