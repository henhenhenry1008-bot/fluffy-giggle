import AppKit
import SwiftUI

struct SettingsView: View {
  @StateObject private var launchAtLogin = LaunchAtLoginController()
  @AppStorage(AppPreferenceKey.refreshInterval) private var refreshIntervalValue =
    MonitoringRefreshInterval.standard.rawValue
  @AppStorage(AppPreferenceKey.historyLength) private var historyLengthValue =
    MonitoringHistoryLength.twoMinutes.rawValue
  @AppStorage(AppPreferenceKey.networkDisplayUnit) private var networkDisplayUnitValue =
    NetworkDisplayUnit.automatic.rawValue
  @AppStorage(AppPreferenceKey.appearance) private var appearanceValue =
    AppearancePreference.system.rawValue

  var body: some View {
    Form {
      Section("General") {
        Toggle(
          "Launch at Login",
          isOn: Binding(
            get: { launchAtLogin.isEnabled },
            set: { launchAtLogin.setEnabled($0) }
          )
        )
        .disabled(!launchAtLogin.canChange)

        LabeledContent("Status", value: launchAtLogin.status.title)

        Text(launchAtLogin.status.detail)
          .font(.caption)
          .foregroundStyle(.secondary)

        if launchAtLogin.status == .requiresApproval {
          Button("Open Login Items Settings") {
            launchAtLogin.openSystemSettings()
          }
        }

        if let errorMessage = launchAtLogin.errorMessage {
          Text(errorMessage)
            .font(.caption)
            .foregroundStyle(.red)
            .textSelection(.enabled)
        }
      }

      Section("Menu Bar") {
        ForEach(MenuBarMetric.allCases) { metric in
          MenuBarMetricToggle(metric: metric)
        }
      }

      Section("Monitoring") {
        Picker("Refresh Interval", selection: $refreshIntervalValue) {
          ForEach(MonitoringRefreshInterval.allCases) { interval in
            Text(interval.displayName).tag(interval.rawValue)
          }
        }

        Picker("History Length", selection: $historyLengthValue) {
          ForEach(MonitoringHistoryLength.allCases) { length in
            Text(length.displayName).tag(length.rawValue)
          }
        }

        Picker("Network Units", selection: $networkDisplayUnitValue) {
          ForEach(NetworkDisplayUnit.allCases) { unit in
            Text(unit.displayName).tag(unit.rawValue)
          }
        }
      }

      Section("Appearance") {
        Picker("Color Scheme", selection: $appearanceValue) {
          ForEach(AppearancePreference.allCases) { appearance in
            Text(appearance.displayName).tag(appearance.rawValue)
          }
        }
        .pickerStyle(.segmented)
      }
    }
    .formStyle(.grouped)
    .frame(width: 480, height: 500)
    .onAppear {
      launchAtLogin.refresh()
    }
    .onReceive(
      NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
    ) { _ in
      launchAtLogin.refresh()
    }
  }
}
