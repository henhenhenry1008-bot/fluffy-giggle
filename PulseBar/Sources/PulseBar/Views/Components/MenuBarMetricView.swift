import SwiftUI

struct MenuBarMetricView: View {
  let presentation: MenuBarMetricPresentation

  var body: some View {
    Text(presentation.title)
      .lineLimit(1)
      .fixedSize(horizontal: true, vertical: false)
      .monospacedDigit()
      .accessibilityLabel(presentation.accessibilityLabel)
  }
}

struct MenuBarMetricToggle: View {
  let metric: MenuBarMetric

  @AppStorage private var isVisible: Bool

  init(metric: MenuBarMetric) {
    self.metric = metric
    _isVisible = AppStorage(
      wrappedValue: metric.isVisibleByDefault,
      metric.preferenceKey
    )
  }

  var body: some View {
    Toggle(metric.settingsTitle, isOn: $isVisible)
  }
}

struct MenuBarMetricPresentation: Equatable, Identifiable, Sendable {
  let metric: MenuBarMetric
  let title: String
  let accessibilityLabel: String

  var id: MenuBarMetric { metric }

  init(
    metric: MenuBarMetric,
    cpuUsage: Double?,
    memoryUsage: Double?,
    downloadBytesPerSecond: Double?,
    uploadBytesPerSecond: Double?,
    batteryPercentage: Double?,
    networkUnit: NetworkDisplayUnit
  ) {
    self.metric = metric

    switch metric {
    case .cpu:
      title = "CPU \(MetricFormatter.compactPercentage(cpuUsage))"
      accessibilityLabel = "CPU \(MetricFormatter.percentage(cpuUsage))"
    case .memory:
      title = "MEM \(MetricFormatter.compactPercentage(memoryUsage))"
      accessibilityLabel = "memory \(MetricFormatter.percentage(memoryUsage))"
    case .networkDownload:
      title = "↓ \(MetricFormatter.compactRate(downloadBytesPerSecond, unit: networkUnit))"
      accessibilityLabel =
        "download \(MetricFormatter.rate(downloadBytesPerSecond, unit: networkUnit))"
    case .networkUpload:
      title = "↑ \(MetricFormatter.compactRate(uploadBytesPerSecond, unit: networkUnit))"
      accessibilityLabel =
        "upload \(MetricFormatter.rate(uploadBytesPerSecond, unit: networkUnit))"
    case .battery:
      title = "BAT \(MetricFormatter.compactPercentage(batteryPercentage))"
      accessibilityLabel = "battery \(MetricFormatter.percentage(batteryPercentage))"
    }
  }
}
