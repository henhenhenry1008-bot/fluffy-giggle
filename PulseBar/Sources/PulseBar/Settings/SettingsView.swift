import SwiftUI

struct SettingsView: View {
  @AppStorage(AppPreferenceKey.launchAtLogin) private var launchAtLogin = false
  @AppStorage(AppPreferenceKey.showsCPU) private var showsCPU = true
  @AppStorage(AppPreferenceKey.showsMemory) private var showsMemory = true
  @AppStorage(AppPreferenceKey.showsNetworkDownload) private var showsNetworkDownload = true
  @AppStorage(AppPreferenceKey.showsNetworkUpload) private var showsNetworkUpload = false
  @AppStorage(AppPreferenceKey.showsBattery) private var showsBattery = false
  @AppStorage(AppPreferenceKey.refreshInterval) private var refreshIntervalValue =
    MonitoringRefreshInterval.oneSecond.rawValue
  @AppStorage(AppPreferenceKey.historyLength) private var historyLengthValue =
    MonitoringHistoryLength.twoMinutes.rawValue
  @AppStorage(AppPreferenceKey.networkDisplayUnit) private var networkDisplayUnitValue =
    NetworkDisplayUnit.automatic.rawValue
  @AppStorage(AppPreferenceKey.appearance) private var appearanceValue =
    AppearancePreference.system.rawValue

  var body: some View {
    Form {
      Section("General") {
        Toggle("Launch at Login", isOn: $launchAtLogin)
          .disabled(true)

        Text("Launch at Login will be connected in the next development stage.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section("Menu Bar") {
        Toggle("CPU", isOn: $showsCPU)
        Toggle("Memory", isOn: $showsMemory)
        Toggle("Network Download", isOn: $showsNetworkDownload)
        Toggle("Network Upload", isOn: $showsNetworkUpload)
        Toggle("Battery", isOn: $showsBattery)
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
  }
}
