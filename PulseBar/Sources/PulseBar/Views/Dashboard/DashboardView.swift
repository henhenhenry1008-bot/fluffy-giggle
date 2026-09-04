import AppKit
import SwiftUI

struct DashboardView: View {
  @ObservedObject var viewModel: SystemMonitorViewModel
  var showsOpenWindowButton = true
  @Environment(\.openWindow) private var openWindow
  @AppStorage(AppPreferenceKey.networkDisplayUnit) private var networkDisplayUnitValue =
    NetworkDisplayUnit.automatic.rawValue

  private let columns = [
    GridItem(.flexible(), spacing: 10),
    GridItem(.flexible(), spacing: 10),
  ]

  private let memoryDetailColumns = [
    GridItem(.flexible(), spacing: 6),
    GridItem(.flexible(), spacing: 6),
  ]

  var body: some View {
    VStack(spacing: 12) {
      header

      ScrollView {
        VStack(spacing: 12) {
          LazyVGrid(columns: columns, spacing: 10) {
            cpuCard
            memoryCard
            diskCard
            batteryCard
          }

          gpuCard
          networkCard
          appProcessCard
        }
      }
      .frame(height: 520)

      footer
    }
    .padding(16)
    .frame(width: 390)
    .background(.ultraThinMaterial)
  }

  private var header: some View {
    HStack(spacing: 10) {
      Image(systemName: "waveform.path.ecg")
        .font(.title3.weight(.semibold))
        .foregroundStyle(.white)
        .frame(width: 34, height: 34)
        .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 10))

      VStack(alignment: .leading, spacing: 1) {
        Text("PulseBar")
          .font(.headline)
        Text("System overview")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      Spacer()

      HStack(spacing: 5) {
        Circle()
          .fill(monitoringStatusTint)
          .frame(width: 6, height: 6)
        Text(monitoringStatusTitle)
          .font(.caption2.weight(.semibold))
      }
      .foregroundStyle(monitoringStatusTint)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(monitoringStatusTint.opacity(0.1), in: Capsule())

      if showsOpenWindowButton {
        Button {
          openWindow(id: "dashboard")
          NSApplication.shared.activate(ignoringOtherApps: true)
        } label: {
          Image(systemName: "macwindow")
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help("Open dashboard window")
        .accessibilityLabel("Open dashboard window")
      }

      Button {
        Task {
          await viewModel.refresh()
        }
      } label: {
        Image(systemName: "arrow.clockwise")
          .frame(width: 24, height: 24)
      }
      .buttonStyle(.plain)
      .disabled(viewModel.isRefreshing)
      .help("Refresh now")
      .accessibilityLabel("Refresh system metrics")
    }
  }

  private var cpuCard: some View {
    MetricCard(title: "CPU", systemImage: "cpu", tint: .blue) {
      Text(MetricFormatter.percentage(viewModel.snapshot.cpuUsage))
        .font(.title2.weight(.semibold))
        .monospacedDigit()

      ProgressView(value: viewModel.snapshot.cpuUsage ?? 0, total: 1)
        .tint(.blue)

      MetricChart(
        samples: viewModel.history,
        primarySeries: MetricChartSeries(name: "CPU", color: .blue) { snapshot in
          snapshot.cpuUsage
        },
        fixedYDomain: 0...1,
        accessibilityLabel: "CPU usage history"
      )
      .frame(height: 40)

      CoreUsageStrip(usages: viewModel.snapshot.cpuCoreUsages)

      cpuTopologyDetails
    }
  }

  private var cpuTopologyDetails: some View {
    VStack(alignment: .leading, spacing: 3) {
      if let topology = viewModel.snapshot.cpuTopology {
        Text("\(topology.physicalCoreCount) physical · \(topology.logicalCoreCount) logical")
          .fixedSize(horizontal: false, vertical: true)

        if let levels = topology.performanceLevels {
          ForEach(levels) { level in
            HStack(alignment: .firstTextBaseline, spacing: 4) {
              Text(level.name)
                .lineLimit(1)
                .help(level.name)
              Spacer(minLength: 0)
              Text("\(level.physicalCoreCount) cores")
                .fixedSize()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(level.name)
            .accessibilityValue(
              "\(level.physicalCoreCount) physical cores, \(level.logicalCoreCount) logical cores")
          }
        } else {
          Text("Core types unavailable")
        }
      } else {
        Text("Core topology unavailable")
      }
    }
    .font(.caption2)
    .foregroundStyle(.secondary)
    .monospacedDigit()
    .help(
      "System-reported hardware core counts, not active cores. Core types are not mapped to the usage bars above."
    )
  }

  private var gpuCard: some View {
    MetricCard(title: "GPU", systemImage: "display", tint: .indigo) {
      Text("Experimental · Driver-reported")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .help(
          "Uses undocumented read-only driver statistics. macOS updates may make readings unavailable."
        )

      if viewModel.snapshot.gpuDevices.isEmpty {
        Text("Unavailable")
          .font(.body)
          .foregroundStyle(.secondary)
      }

      ForEach(viewModel.snapshot.gpuDevices) { gpu in
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Text(gpu.name)
              .font(.caption.weight(.medium))
              .lineLimit(1)
              .help(gpu.name)

            Spacer(minLength: 6)

            Text(MetricFormatter.percentage(gpu.usage))
              .font(.body.weight(.semibold))
              .monospacedDigit()
              .fixedSize()
          }

          MetricChart(
            samples: viewModel.history,
            primarySeries: MetricChartSeries(name: "GPU", color: .indigo) { snapshot in
              snapshot.gpuUsage(for: gpu.id)
            },
            fixedYDomain: 0...1,
            accessibilityLabel: "\(gpu.name) GPU usage history"
          )
          .frame(height: 40)
        }
      }
    }
  }

  private var memoryCard: some View {
    MetricCard(title: "Memory", systemImage: "memorychip", tint: .purple) {
      Text(MetricFormatter.percentage(memoryUsage))
        .font(.title2.weight(.semibold))
        .monospacedDigit()

      Text(
        "\(MetricFormatter.bytes(viewModel.snapshot.memoryUsed)) / \(MetricFormatter.bytes(viewModel.snapshot.memoryTotal))"
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      .lineLimit(1)

      ProgressView(value: memoryUsage ?? 0, total: 1)
        .tint(.purple)

      MetricChart(
        samples: viewModel.history,
        primarySeries: MetricChartSeries(name: "Memory", color: .purple) { snapshot in
          Self.memoryUsage(for: snapshot)
        },
        fixedYDomain: 0...1,
        accessibilityLabel: "Memory usage history"
      )
      .frame(height: 40)

      LazyVGrid(columns: memoryDetailColumns, alignment: .leading, spacing: 5) {
        memoryDetail("Available", value: viewModel.snapshot.memoryAvailable)
        memoryDetail("Cached", value: viewModel.snapshot.memoryCached)
        memoryDetail("Wired", value: viewModel.snapshot.memoryWired)
        memoryDetail("Compressed", value: viewModel.snapshot.memoryCompressed)
      }

      Text(swapSummary)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
  }

  private var diskCard: some View {
    MetricCard(title: "Disk", systemImage: "internaldrive", tint: .green) {
      Text(MetricFormatter.percentage(diskUsage))
        .font(.title2.weight(.semibold))
        .monospacedDigit()

      Text(
        "\(MetricFormatter.bytes(viewModel.snapshot.diskUsed)) / \(MetricFormatter.bytes(viewModel.snapshot.diskTotal))"
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      .lineLimit(1)

      ProgressView(value: diskUsage ?? 0, total: 1)
        .tint(.green)

      Text("Available \(MetricFormatter.bytes(viewModel.snapshot.diskAvailable))")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)

      diskRate(
        symbol: "arrow.down",
        title: "Read",
        value: viewModel.snapshot.diskReadBytesPerSecond,
        tint: .green
      )

      diskRate(
        symbol: "arrow.up",
        title: "Write",
        value: viewModel.snapshot.diskWriteBytesPerSecond,
        tint: .orange
      )
    }
  }

  private var batteryCard: some View {
    MetricCard(
      title: "Battery",
      systemImage: batterySystemImage,
      tint: batteryTint
    ) {
      Text(MetricFormatter.percentage(viewModel.snapshot.batteryPercentage))
        .font(.title2.weight(.semibold))
        .monospacedDigit()

      Text(batteryState)
        .font(.caption)
        .foregroundStyle(.secondary)

      ProgressView(value: viewModel.snapshot.batteryPercentage ?? 0, total: 1)
        .tint(batteryTint)

      if let batteryTimeEstimate {
        Text(batteryTimeEstimate)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .monospacedDigit()
          .lineLimit(1)
      }

      if let healthStatus = viewModel.snapshot.batteryHealthStatus {
        Text("Health \(healthStatus)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.75)
      }
    }
  }

  private var networkCard: some View {
    MetricCard(title: "Network", systemImage: "network", tint: .cyan) {
      HStack(spacing: 22) {
        networkValue(
          symbol: "arrow.down",
          title: "Download",
          value: viewModel.snapshot.networkDownloadBytesPerSecond,
          tint: .cyan
        )

        networkValue(
          symbol: "arrow.up",
          title: "Upload",
          value: viewModel.snapshot.networkUploadBytesPerSecond,
          tint: .orange
        )
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      MetricChart(
        samples: viewModel.history,
        primarySeries: MetricChartSeries(name: "Download", color: .cyan) { snapshot in
          snapshot.networkDownloadBytesPerSecond
        },
        secondarySeries: MetricChartSeries(name: "Upload", color: .orange) { snapshot in
          snapshot.networkUploadBytesPerSecond
        },
        accessibilityLabel: "Network throughput history"
      )
      .frame(height: 48)
    }
    .help(
      "Physical network interfaces only. VPN and Apple peer-to-peer interfaces are excluded. Includes local-network traffic and protocol overhead."
    )
  }

  private var appProcessCard: some View {
    MetricCard(title: "App processes · Top CPU", systemImage: "list.bullet", tint: .blue) {
      if let list = viewModel.snapshot.appProcesses, !list.topProcesses.isEmpty {
        HStack {
          Text("Process")
          Spacer()
          Text("CPU").frame(width: 65, alignment: .trailing)
          Text("Resident").frame(width: 72, alignment: .trailing)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)

        ForEach(list.topProcesses) { process in
          HStack(spacing: 6) {
            Text(process.name)
              .lineLimit(1)
              .truncationMode(.middle)
              .help("\(process.name) · PID \(process.id.pid)")
            Spacer(minLength: 0)
            Text(MetricFormatter.processCPU(process.cpuUsage))
              .frame(width: 65, alignment: .trailing)
            Text(MetricFormatter.bytes(process.residentBytes))
              .frame(width: 72, alignment: .trailing)
          }
          .font(.caption)
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        }
      } else {
        Text("Unavailable")
          .foregroundStyle(.secondary)
      }

      if let list = viewModel.snapshot.appProcesses {
        Text("Readable \(list.readableCount) of \(list.listedCount) listed app processes")
          .font(.caption2)
          .foregroundStyle(.secondary)
        if list.queriedCount < list.listedCount {
          Text("Limited to \(list.queriedCount) candidates")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      Text("100% CPU = one core · Apps only")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .help(
          "Not a complete system process list. Child processes are not grouped. Resident memory is not Activity Monitor's memory footprint. A dash means CPU is awaiting a valid interval. Follows the refresh interval selected in Settings."
        )
    }
  }

  private var footer: some View {
    HStack(spacing: 12) {
      SettingsLink {
        Label("Settings", systemImage: "gearshape")
      }

      Button {
        showAboutPanel()
      } label: {
        Label("About", systemImage: "info.circle")
      }

      Spacer()

      Button("Quit PulseBar") {
        NSApplication.shared.terminate(nil)
      }
    }
    .controlSize(.small)
  }

  private func networkValue(
    symbol: String,
    title: String,
    value: Double?,
    tint: Color
  ) -> some View {
    HStack(spacing: 8) {
      Image(systemName: symbol)
        .font(.body.weight(.semibold))
        .foregroundStyle(tint)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption2)
          .foregroundStyle(.secondary)
        Text(MetricFormatter.rate(value, unit: networkDisplayUnit))
          .font(.body.weight(.medium))
          .monospacedDigit()
      }
    }
  }

  private func memoryDetail(_ title: String, value: UInt64?) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)

      Text(MetricFormatter.bytes(value))
        .font(.caption.weight(.medium))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func diskRate(
    symbol: String,
    title: String,
    value: Double?,
    tint: Color
  ) -> some View {
    HStack(spacing: 4) {
      Image(systemName: symbol)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tint)

      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)

      Spacer(minLength: 2)

      Text(MetricFormatter.rate(value))
        .font(.caption2.weight(.medium))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
  }

  private var memoryUsage: Double? {
    Self.memoryUsage(for: viewModel.snapshot)
  }

  private var swapSummary: String {
    guard let used = viewModel.snapshot.swapUsed,
      let total = viewModel.snapshot.swapTotal
    else {
      return "Swap unavailable"
    }

    return "Swap \(MetricFormatter.bytes(used)) / \(MetricFormatter.bytes(total))"
  }

  private static func memoryUsage(for snapshot: SystemSnapshot) -> Double? {
    guard let used = snapshot.memoryUsed,
      let total = snapshot.memoryTotal,
      total > 0
    else {
      return nil
    }
    return Double(used) / Double(total)
  }

  private var diskUsage: Double? {
    guard let used = viewModel.snapshot.diskUsed,
      let total = viewModel.snapshot.diskTotal,
      total > 0
    else {
      return nil
    }
    return Double(used) / Double(total)
  }

  private var networkDisplayUnit: NetworkDisplayUnit {
    NetworkDisplayUnit(rawValue: networkDisplayUnitValue) ?? .automatic
  }

  private var batteryState: String {
    guard viewModel.snapshot.batteryPercentage != nil else {
      return "Unavailable"
    }

    if viewModel.snapshot.batteryIsFullyCharged == true {
      return "Fully Charged"
    }
    if viewModel.snapshot.batteryIsCharging == true {
      return "Charging"
    }
    if viewModel.snapshot.batteryIsACPowered == true {
      return "On AC Power"
    }
    return "On Battery"
  }

  private var batteryTimeEstimate: String? {
    if viewModel.snapshot.batteryIsCharging == true,
      let minutes = viewModel.snapshot.batteryTimeToFullChargeMinutes
    {
      return "Full in \(MetricFormatter.duration(minutes: minutes))"
    }

    if viewModel.snapshot.batteryIsACPowered == false,
      let minutes = viewModel.snapshot.batteryTimeToEmptyMinutes
    {
      return "\(MetricFormatter.duration(minutes: minutes)) remaining"
    }

    return nil
  }

  private var batterySystemImage: String {
    guard let percentage = viewModel.snapshot.batteryPercentage else {
      return "battery.0"
    }
    if viewModel.snapshot.batteryIsCharging == true {
      return "battery.100.bolt"
    }

    switch percentage {
    case 0.875...: return "battery.100"
    case 0.625...: return "battery.75"
    case 0.375...: return "battery.50"
    case 0.125...: return "battery.25"
    default: return "battery.0"
    }
  }

  private var batteryTint: Color {
    guard let percentage = viewModel.snapshot.batteryPercentage else {
      return .secondary
    }
    if viewModel.snapshot.batteryIsCharging == true {
      return .green
    }
    return percentage <= 0.2 ? .orange : .green
  }

  private var hasReceivedMetrics: Bool {
    viewModel.snapshot.cpuUsage != nil
      || viewModel.snapshot.memoryTotal != nil
      || viewModel.snapshot.networkDownloadBytesPerSecond != nil
      || viewModel.snapshot.diskTotal != nil
      || viewModel.snapshot.batteryPercentage != nil
  }

  private var monitoringStatusTitle: String {
    guard viewModel.isMonitoring else { return "PAUSED" }
    return hasReceivedMetrics ? "LIVE" : "STARTING"
  }

  private var monitoringStatusTint: Color {
    guard viewModel.isMonitoring else { return .secondary }
    return hasReceivedMetrics ? .green : .orange
  }

  private func showAboutPanel() {
    NSApplication.shared.activate(ignoringOtherApps: true)
    NSApplication.shared.orderFrontStandardAboutPanel(nil)
  }
}
