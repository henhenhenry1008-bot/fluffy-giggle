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
      Label(title, systemImage: systemImage)
        .font(.headline)
        .foregroundStyle(tint)

      content
    }
    .frame(maxWidth: .infinity, minHeight: 94, alignment: .topLeading)
    .padding(12)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(.primary.opacity(0.08))
    }
  }
}
