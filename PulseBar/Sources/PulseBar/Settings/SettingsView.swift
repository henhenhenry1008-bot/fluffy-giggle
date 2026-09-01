import SwiftUI

struct SettingsView: View {
  var body: some View {
    Form {
      Section("Development status") {
        LabeledContent("Monitoring source", value: "Placeholder data")
        LabeledContent("Refresh loop", value: "Not enabled")
        LabeledContent("Minimum system", value: "macOS 14")
      }

      Section {
        Text(
          "Real monitoring, refresh controls, history, and launch at login will be added incrementally after this architecture is verified."
        )
        .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .frame(width: 440, height: 260)
  }
}
