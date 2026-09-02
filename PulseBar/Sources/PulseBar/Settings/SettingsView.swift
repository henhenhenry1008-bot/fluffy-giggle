import SwiftUI

struct SettingsView: View {
  var body: some View {
    Form {
      Section("Development status") {
        LabeledContent("CPU source", value: "Live Mach statistics")
        LabeledContent("Memory source", value: "Live Mach VM statistics")
        LabeledContent("Network source", value: "Live BSD interface statistics")
        LabeledContent("Disk source", value: "Live Foundation volume capacity")
        LabeledContent("Battery source", value: "Live IOKit power sources")
        LabeledContent("Refresh loop", value: "0.5 / 1 / 2 / 5 seconds")
        LabeledContent("History", value: "120 samples")
        LabeledContent("Minimum system", value: "macOS 14")
      }

      Section {
        Text(
          "Refresh controls and launch at login will be added incrementally."
        )
        .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .frame(width: 440, height: 260)
  }
}
