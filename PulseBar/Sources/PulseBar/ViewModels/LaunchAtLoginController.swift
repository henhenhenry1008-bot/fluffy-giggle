import Combine
import Foundation

@MainActor
final class LaunchAtLoginController: ObservableObject {
  @Published private(set) var status: LaunchAtLoginStatus
  @Published private(set) var errorMessage: String?

  private let service: any LaunchAtLoginServicing

  init(service: any LaunchAtLoginServicing = LaunchAtLoginService()) {
    self.service = service
    status = service.status
  }

  var isEnabled: Bool {
    status.isRegistered
  }

  var canChange: Bool {
    status.canChange
  }

  func setEnabled(_ enabled: Bool) {
    guard enabled != isEnabled, canChange else { return }

    errorMessage = nil
    var updateError: Error?

    do {
      if enabled {
        try service.register()
      } else {
        try service.unregister()
      }
    } catch {
      updateError = error
    }

    refresh()

    if let updateError, isEnabled != enabled {
      errorMessage = "Couldn’t update Launch at Login: \(updateError.localizedDescription)"
    }
  }

  func refresh() {
    let latestStatus = service.status
    if latestStatus != status {
      errorMessage = nil
    }
    status = latestStatus
  }

  func openSystemSettings() {
    service.openSystemSettings()
  }
}
