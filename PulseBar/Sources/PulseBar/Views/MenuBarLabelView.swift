import SwiftUI

struct MenuBarLabelView: View {
  let snapshot: SystemSnapshot

  var body: some View {
    Text(
      "CPU \(MetricFormatter.percentage(snapshot.cpuUsage))  MEM \(MetricFormatter.percentage(memoryUsage))"
    )
    .monospacedDigit()
    .accessibilityLabel(
      "CPU \(MetricFormatter.percentage(snapshot.cpuUsage)), memory \(MetricFormatter.percentage(memoryUsage))"
    )
  }

  private var memoryUsage: Double? {
    guard let used = snapshot.memoryUsed,
      let total = snapshot.memoryTotal,
      total > 0
    else {
      return nil
    }
    return Double(used) / Double(total)
  }
}
