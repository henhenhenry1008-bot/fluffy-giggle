enum MonitoringRefreshInterval: Double, CaseIterable, Identifiable, Sendable {
  case halfSecond = 0.5
  case oneSecond = 1
  case twoSeconds = 2
  case fiveSeconds = 5

  static let standard: Self = .twoSeconds

  var id: Double { rawValue }

  var duration: Duration {
    switch self {
    case .halfSecond: .milliseconds(500)
    case .oneSecond: .seconds(1)
    case .twoSeconds: .seconds(2)
    case .fiveSeconds: .seconds(5)
    }
  }

  var displayName: String {
    switch self {
    case .halfSecond: "0.5 seconds"
    case .oneSecond: "1 second"
    case .twoSeconds: "2 seconds"
    case .fiveSeconds: "5 seconds"
    }
  }
}
