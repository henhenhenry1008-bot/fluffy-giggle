import SwiftUI

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
