import SwiftUI

struct MonitoredMenuBarLabel: View {
  @ObservedObject var monitor: SystemMonitorViewModel

  var body: some View {
    MenuBarLabelView(snapshot: monitor.snapshot)
  }
}

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

    MenuBarPresentationView(presentation: presentation)
      .equatable()
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

// Compare only the rendered text and accessibility values, not the full
// snapshot's changing UUID, timestamps or metrics that the user has hidden.
struct MenuBarPresentationView: View, Equatable {
  let presentation: MenuBarPresentation

  var body: some View {
    HStack(spacing: 8) {
      if presentation.metrics.isEmpty {
        Text("PulseBar")
      } else {
        ForEach(presentation.metrics) { metric in
          MenuBarMetricView(presentation: metric)
        }
      }
    }
    .fixedSize()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(presentation.accessibilityLabel)
  }

  nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.presentation == rhs.presentation
  }
}

struct MenuBarPresentation: Equatable, Sendable {
  let metrics: [MenuBarMetricPresentation]

  var title: String {
    metrics.isEmpty ? "PulseBar" : metrics.map(\.title).joined(separator: "  ")
  }

  var accessibilityLabel: String {
    metrics.isEmpty
      ? "PulseBar" : metrics.map(\.accessibilityLabel).joined(separator: ", ")
  }

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
    metrics = MenuBarMetric.allCases.compactMap { metric in
      guard visibility.isVisible(metric) else { return nil }

      return MenuBarMetricPresentation(
        metric: metric,
        cpuUsage: cpuUsage,
        memoryUsage: memoryUsage,
        downloadBytesPerSecond: downloadBytesPerSecond,
        uploadBytesPerSecond: uploadBytesPerSecond,
        batteryPercentage: batteryPercentage,
        networkUnit: networkUnit
      )
    }
  }
}
