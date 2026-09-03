import SwiftUI

struct CoreUsageStrip: View {
  let usages: [Double?]
  var tint: Color = .blue

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .bottom, spacing: 2) {
        ForEach(Array(usages.enumerated()), id: \.offset) { _, usage in
          CoreUsageBar(usage: usage, tint: tint)
        }
      }
      .frame(height: 18)

      Text(statusText)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Per-core CPU usage")
    .accessibilityValue(accessibilityValue)
  }

  private var statusText: String {
    guard !usages.isEmpty else { return "Cores unavailable" }
    guard usages.contains(where: { $0 != nil }) else {
      return "\(usages.count) logical cores · Sampling"
    }
    return "\(usages.count) logical cores"
  }

  private var accessibilityValue: String {
    guard !usages.isEmpty else { return "Unavailable" }

    return usages.enumerated().map { index, usage in
      "Core \(index + 1), \(MetricFormatter.percentage(usage))"
    }.joined(separator: ", ")
  }
}

private struct CoreUsageBar: View {
  let usage: Double?
  let tint: Color

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .bottom) {
        RoundedRectangle(cornerRadius: 2)
          .fill(.quaternary)

        if let usage {
          RoundedRectangle(cornerRadius: 2)
            .fill(tint.gradient)
            .frame(height: geometry.size.height * normalized(usage))
        }
      }
    }
    .frame(minWidth: 2, maxWidth: .infinity)
    .accessibilityHidden(true)
  }

  private func normalized(_ value: Double) -> Double {
    min(max(value, 0), 1)
  }
}
