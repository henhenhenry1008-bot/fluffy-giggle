import SwiftUI

struct MenuBarLabelView: View {
  let snapshot: SystemSnapshot

  var body: some View {
    Text("CPU \(MetricFormatter.percentage(snapshot.cpuUsage))")
      .monospacedDigit()
      .accessibilityLabel("CPU \(MetricFormatter.percentage(snapshot.cpuUsage))")
  }
}
