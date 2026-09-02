import SwiftUI

struct MenuBarLabelView: View {
  @AppStorage(AppPreferenceKey.showsCPU) private var showsCPU = true
  @AppStorage(AppPreferenceKey.showsMemory) private var showsMemory = true
  @AppStorage(AppPreferenceKey.showsNetworkDownload) private var showsNetworkDownload = true
  @AppStorage(AppPreferenceKey.showsNetworkUpload) private var showsNetworkUpload = false
  @AppStorage(AppPreferenceKey.showsBattery) private var showsBattery = false
  @AppStorage(AppPreferenceKey.networkDisplayUnit) private var networkDisplayUnitValue =
    NetworkDisplayUnit.automatic.rawValue

  let snapshot: SystemSnapshot

  var body: some View {
    let presentation = MenuBarPresentation(
      snapshot: snapshot,
      visibility: visibility,
      networkUnit: networkDisplayUnit
    )

    Text(presentation.title)
      .lineLimit(1)
      .fixedSize()
      .monospacedDigit()
      .accessibilityLabel(presentation.accessibilityLabel)
  }

  private var visibility: MenuBarMetricVisibility {
    MenuBarMetricVisibility(
      showsCPU: showsCPU,
      showsMemory: showsMemory,
      showsNetworkDownload: showsNetworkDownload,
      showsNetworkUpload: showsNetworkUpload,
      showsBattery: showsBattery
    )
  }

  private var networkDisplayUnit: NetworkDisplayUnit {
    NetworkDisplayUnit(rawValue: networkDisplayUnitValue) ?? .automatic
  }
}

struct MenuBarPresentation: Equatable, Sendable {
  let title: String
  let accessibilityLabel: String

  init(
    snapshot: SystemSnapshot,
    visibility: MenuBarMetricVisibility = .standard,
    networkUnit: NetworkDisplayUnit = .automatic
  ) {
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
      downloadBytesPerSecond: snapshot.networkDownloadBytesPerSecond,
      uploadBytesPerSecond: snapshot.networkUploadBytesPerSecond,
      batteryPercentage: snapshot.batteryPercentage,
      visibility: visibility,
      networkUnit: networkUnit
    )
  }

  init(
    cpuUsage: Double?,
    memoryUsage: Double?,
    downloadBytesPerSecond: Double?,
    uploadBytesPerSecond: Double? = nil,
    batteryPercentage: Double? = nil,
    visibility: MenuBarMetricVisibility = .standard,
    networkUnit: NetworkDisplayUnit = .automatic
  ) {
    var titleSegments: [String] = []
    var accessibilitySegments: [String] = []

    if visibility.showsCPU {
      titleSegments.append("CPU \(MetricFormatter.compactPercentage(cpuUsage))")
      accessibilitySegments.append("CPU \(MetricFormatter.percentage(cpuUsage))")
    }
    if visibility.showsMemory {
      titleSegments.append("MEM \(MetricFormatter.compactPercentage(memoryUsage))")
      accessibilitySegments.append("memory \(MetricFormatter.percentage(memoryUsage))")
    }
    if visibility.showsNetworkDownload {
      titleSegments.append(
        "↓ \(MetricFormatter.compactRate(downloadBytesPerSecond, unit: networkUnit))")
      accessibilitySegments.append(
        "download \(MetricFormatter.rate(downloadBytesPerSecond, unit: networkUnit))"
      )
    }
    if visibility.showsNetworkUpload {
      titleSegments.append(
        "↑ \(MetricFormatter.compactRate(uploadBytesPerSecond, unit: networkUnit))")
      accessibilitySegments.append(
        "upload \(MetricFormatter.rate(uploadBytesPerSecond, unit: networkUnit))"
      )
    }
    if visibility.showsBattery {
      titleSegments.append("BAT \(MetricFormatter.compactPercentage(batteryPercentage))")
      accessibilitySegments.append(
        "battery \(MetricFormatter.percentage(batteryPercentage))"
      )
    }

    title = titleSegments.isEmpty ? "PulseBar" : titleSegments.joined(separator: "  ")
    accessibilityLabel =
      accessibilitySegments.isEmpty
      ? "PulseBar" : accessibilitySegments.joined(separator: ", ")
  }
}
