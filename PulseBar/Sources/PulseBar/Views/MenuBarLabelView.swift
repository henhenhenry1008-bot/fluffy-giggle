import SwiftUI

struct MenuBarLabelView: View {
  let snapshot: SystemSnapshot

  var body: some View {
    let presentation = MenuBarPresentation(snapshot: snapshot)

    Text(presentation.title)
      .lineLimit(1)
      .fixedSize()
      .monospacedDigit()
      .accessibilityLabel(presentation.accessibilityLabel)
  }
}

struct MenuBarPresentation: Equatable, Sendable {
  let title: String
  let accessibilityLabel: String

  init(snapshot: SystemSnapshot) {
    let memoryUsage: Double?
    if let used = snapshot.memoryUsed,
      let total = snapshot.memoryTotal,
      total > 0
    {
      memoryUsage = Double(used) / Double(total)
    } else {
      memoryUsage = nil
    }

    self.init(
      cpuUsage: snapshot.cpuUsage,
      memoryUsage: memoryUsage,
      downloadBytesPerSecond: snapshot.networkDownloadBytesPerSecond
    )
  }

  init(cpuUsage: Double?, memoryUsage: Double?, downloadBytesPerSecond: Double?) {
    title =
      "CPU \(MetricFormatter.compactPercentage(cpuUsage))  "
      + "MEM \(MetricFormatter.compactPercentage(memoryUsage))  "
      + "↓ \(MetricFormatter.compactRate(downloadBytesPerSecond))"
    accessibilityLabel =
      "CPU \(MetricFormatter.percentage(cpuUsage)), "
      + "memory \(MetricFormatter.percentage(memoryUsage)), "
      + "download \(MetricFormatter.rate(downloadBytesPerSecond))"
  }
}
