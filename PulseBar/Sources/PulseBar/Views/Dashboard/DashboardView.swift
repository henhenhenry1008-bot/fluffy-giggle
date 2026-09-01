import AppKit
import SwiftUI

struct DashboardView: View {
  @ObservedObject var viewModel: SystemMonitorViewModel

  private let columns = [
    GridItem(.flexible(), spacing: 10),
    GridItem(.flexible(), spacing: 10),
  ]

  var body: some View {
    VStack(spacing: 14) {
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
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 2) {
        Text("PulseBar")
          .font(.title2.weight(.semibold))
        Text("System overview")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Text("5 LIVE METRICS")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.orange.opacity(0.12), in: Capsule())
    }
  }

  private var cpuCard: some View {
    MetricCard(title: "CPU", systemImage: "cpu", tint: .blue) {
      Text(MetricFormatter.percentage(viewModel.snapshot.cpuUsage))
        .font(.title2.weight(.semibold))
        .monospacedDigit()

      ProgressView(value: viewModel.snapshot.cpuUsage ?? 0, total: 1)
        .tint(.blue)
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
      tint: .green
    ) {
      Text(MetricFormatter.percentage(viewModel.snapshot.batteryPercentage))
        .font(.title2.weight(.semibold))
        .monospacedDigit()

      Text(batteryState)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var networkCard: some View {
    MetricCard(title: "Network", systemImage: "network", tint: .cyan) {
      HStack(spacing: 22) {
        networkValue(
          symbol: "arrow.down",
          title: "Download",
          value: viewModel.snapshot.networkDownloadBytesPerSecond
        )

        networkValue(
          symbol: "arrow.up",
          title: "Upload",
          value: viewModel.snapshot.networkUploadBytesPerSecond
        )
      }
    }
  }

  private var footer: some View {
    HStack {
      Button {
        Task {
          await viewModel.refresh()
        }
      } label: {
        Label("Refresh", systemImage: "arrow.clockwise")
      }
      .disabled(viewModel.isRefreshing)

      SettingsLink {
        Label("Settings", systemImage: "gearshape")
      }

      Spacer()

      Button("Quit") {
        NSApplication.shared.terminate(nil)
      }
    }
    .controlSize(.small)
  }

  private func networkValue(symbol: String, title: String, value: Double?) -> some View {
    HStack(spacing: 8) {
      Image(systemName: symbol)
        .font(.body.weight(.semibold))

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
    guard let used = viewModel.snapshot.memoryUsed,
      let total = viewModel.snapshot.memoryTotal,
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
}
