import ServiceManagement

enum LaunchAtLoginStatus: Equatable, Sendable {
  case disabled
  case enabled
  case requiresApproval
  case unavailable

  var isRegistered: Bool {
    self == .enabled || self == .requiresApproval
  }

  var canChange: Bool {
    self != .unavailable
  }

  var title: String {
    switch self {
    case .disabled: "Off"
    case .enabled: "On"
    case .requiresApproval: "Approval Required"
    case .unavailable: "Unavailable"
    }
  }

  var detail: String {
    switch self {
    case .disabled:
      "PulseBar will not open automatically when you sign in."
    case .enabled:
      "PulseBar will open automatically when you sign in."
    case .requiresApproval:
      "Allow PulseBar in System Settings before it can open at login."
    case .unavailable:
      "macOS could not find the login item for this app build."
    }
  }
}

@MainActor
protocol LaunchAtLoginServicing: AnyObject {
  var status: LaunchAtLoginStatus { get }

  func register() throws
  func unregister() throws
  func openSystemSettings()
}

@MainActor
final class LaunchAtLoginService: LaunchAtLoginServicing {
  private let appService: SMAppService

  init(appService: SMAppService = .mainApp) {
    self.appService = appService
  }

  var status: LaunchAtLoginStatus {
    switch appService.status {
    case .notRegistered:
      .disabled
    case .enabled:
      .enabled
    case .requiresApproval:
      .requiresApproval
    case .notFound:
      .unavailable
    @unknown default:
      .unavailable
    }
  }

  func register() throws {
    try appService.register()
  }

  func unregister() throws {
    try appService.unregister()
  }

  func openSystemSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }
}
