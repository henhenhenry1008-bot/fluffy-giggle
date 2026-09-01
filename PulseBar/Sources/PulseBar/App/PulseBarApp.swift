import SwiftUI

@main
struct PulseBarApp: App {
  @StateObject private var monitor = SystemMonitorViewModel()

  var body: some Scene {
    MenuBarExtra {
      DashboardView(viewModel: monitor)
        .task {
          await monitor.refresh()
        }
    } label: {
      MenuBarLabelView(snapshot: monitor.snapshot)
    }
    .menuBarExtraStyle(.window)

    Settings {
      SettingsView()
    }
  }
}
