import SwiftUI

struct SettingsView: View {
  var body: some View {
    Form {
      Section("Development status") {
        LabeledContent("CPU source", value: "Live Mach statistics")
        LabeledContent("Memory source", value: "Live Mach VM statistics")
        LabeledContent("Network source", value: "Live BSD interface statistics")
        LabeledContent("Disk source", value: "Live Foundation volume capacity")
        LabeledContent("Other metrics", value: "Battery placeholder")
        LabeledContent("Refresh loop", value: "1 second")
        LabeledContent("Minimum system", value: "macOS 14")
      }

      Section {
        Text(
          "Battery monitoring, refresh controls, history, and launch at login will be added incrementally."
        )
        .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .frame(width: 440, height: 260)
  }
}
