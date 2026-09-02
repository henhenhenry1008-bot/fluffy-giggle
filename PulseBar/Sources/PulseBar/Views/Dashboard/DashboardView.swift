import AppKit
import SwiftUI

struct DashboardView: View {
  @ObservedObject var viewModel: SystemMonitorViewModel

  private let columns = [
    GridItem(.flexible(), spacing: 10),
    GridItem(.flexible(), spacing: 10),
  ]

  var body: some View {
    VStack(spacing: 12) {
      header

      LazyVGrid(columns: columns, spacing: 10) {
        cpuCard
        memoryCard
        diskCard
        batteryCard
      }

      networkCard
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

      Text("Total system usage")
        .font(.caption2)
        .foregroundStyle(.secondary)
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

      Text("Available \(MetricFormatter.bytes(viewModel.snapshot.memoryAvailable))")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
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
        Text(MetricFormatter.rate(value))
          .font(.body.weight(.medium))
          .monospacedDigit()
      }
    }
  }

  private var memoryUsage: Double? {
    Self.memoryUsage(for: viewModel.snapshot)
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
