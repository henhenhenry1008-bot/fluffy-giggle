import SwiftUI

@main
struct PulseBarApp: App {
  @StateObject private var monitor = SystemMonitorViewModel()

  var body: some Scene {
    MenuBarExtra {
      DashboardView(viewModel: monitor)
    } label: {
      MenuBarLabelView(snapshot: monitor.snapshot)
        .onAppear {
          monitor.startMonitoring()
        }
    }
    .menuBarExtraStyle(.window)

    Settings {
      SettingsView()
    }
  }
}
