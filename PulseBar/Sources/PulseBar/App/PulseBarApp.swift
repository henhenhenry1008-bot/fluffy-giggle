import AppKit
import SwiftUI

@main
struct PulseBarApp: App {
  // Own the reference here; only the individual metric views observe its
  // publications. App-level observation invalidates every scene each sample.
  @State private var monitor = SystemMonitorViewModel()
  @AppStorage(AppPreferenceKey.refreshInterval) private var refreshIntervalValue =
    MonitoringRefreshInterval.standard.rawValue
  @AppStorage(AppPreferenceKey.historyLength) private var historyLengthValue =
    MonitoringHistoryLength.twoMinutes.rawValue
  @AppStorage(AppPreferenceKey.appearance) private var appearanceValue =
    AppearancePreference.system.rawValue

  var body: some Scene {
    Window("PulseBar", id: "dashboard") {
      DashboardView(viewModel: monitor, showsOpenWindowButton: false, compact: true)
        .preferredColorScheme(appearancePreference.colorScheme)
        .onAppear {
          applyStoredMonitoringPreferences()
          monitor.startMonitoring()
        }
    }
    .defaultPosition(.center)
    .windowResizability(.contentSize)

    MenuBarExtra {
      DashboardView(viewModel: monitor, compact: true)
        .preferredColorScheme(appearancePreference.colorScheme)
    } label: {
      MonitoredMenuBarLabel(monitor: monitor)
        .onAppear {
          applyStoredMonitoringPreferences()
          monitor.startMonitoring()
        }
        .onChange(of: refreshIntervalValue) { _, newValue in
          let interval =
            MonitoringRefreshInterval(rawValue: newValue) ?? .standard
          monitor.changeRefreshInterval(to: interval)
        }
        .onChange(of: historyLengthValue) { _, newValue in
          let capacity =
            MonitoringHistoryLength(rawValue: newValue)?.rawValue
            ?? MonitoringHistoryLength.twoMinutes.rawValue
          monitor.changeHistoryCapacity(to: capacity)
        }
        .onReceive(
          NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
        ) { _ in
          monitor.stopMonitoring()
        }
    }
    .menuBarExtraStyle(.window)

    Settings {
      SettingsView()
        .preferredColorScheme(appearancePreference.colorScheme)
    }
  }

  private var appearancePreference: AppearancePreference {
    AppearancePreference(rawValue: appearanceValue) ?? .system
  }

  private func applyStoredMonitoringPreferences() {
    let interval =
      MonitoringRefreshInterval(rawValue: refreshIntervalValue) ?? .standard
    let historyCapacity =
      MonitoringHistoryLength(rawValue: historyLengthValue)?.rawValue
      ?? MonitoringHistoryLength.twoMinutes.rawValue

    monitor.changeRefreshInterval(to: interval)
    monitor.changeHistoryCapacity(to: historyCapacity)
  }
}
