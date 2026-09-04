import SwiftUI

/// A compact, read-only summary inside a button. Expanded readings stay in MetricCard.
struct SummaryMetricCard<ChartContent: View>: View {
  let title: String
  let systemImage: String
  let tint: Color
  let value: String
  let detail: String
  @ViewBuilder let chart: () -> ChartContent

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: systemImage)
          .foregroundStyle(tint)
        Text(title)
          .foregroundStyle(.primary)
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      .font(.subheadline.weight(.semibold))

      Text(value)
        .font(.system(size: 25, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)

      Text(detail)
        .font(.caption)
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .help(detail)

      Spacer(minLength: 0)
      chart()
        .frame(height: 32)
    }
    .padding(12)
    .frame(maxWidth: .infinity)
    .frame(height: 156)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(.primary.opacity(0.1))
    }
    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}

struct MetricCard<Content: View>: View {
  let title: String
  let systemImage: String
  let tint: Color
  private let content: Content

  init(
    title: String,
    systemImage: String,
    tint: Color,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.systemImage = systemImage
    self.tint = tint
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: systemImage)
          .font(.caption.weight(.semibold))
          .foregroundStyle(tint)
          .frame(width: 24, height: 24)
          .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

        Text(title)
          .font(.subheadline.weight(.semibold))

        Spacer(minLength: 0)
      }

      content
    }
    .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
    .padding(12)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(.primary.opacity(0.08))
    }
  }
}
