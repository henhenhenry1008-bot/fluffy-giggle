import SwiftUI

struct MetricChartSeries {
  let name: String
  let color: Color
  let value: (SystemSnapshot) -> Double?

  init(
    name: String,
    color: Color,
    value: @escaping (SystemSnapshot) -> Double?
  ) {
    self.name = name
    self.color = color
    self.value = value
  }
}

struct MetricChart: View {
  let primaryPoints: [MetricChartPoint]
  let secondaryPoints: [MetricChartPoint]
  let primarySeries: MetricChartSeries
  let secondarySeries: MetricChartSeries?
  let fixedYDomain: ClosedRange<Double>?
  let accessibilityLabel: String

  init(
    samples: RingBuffer<SystemSnapshot>,
    primarySeries: MetricChartSeries,
    secondarySeries: MetricChartSeries? = nil,
    fixedYDomain: ClosedRange<Double>? = nil,
    accessibilityLabel: String
  ) {
    primaryPoints = Self.points(samples: samples, series: primarySeries)
    secondaryPoints = secondarySeries.map { Self.points(samples: samples, series: $0) } ?? []
    self.primarySeries = primarySeries
    self.secondarySeries = secondarySeries
    self.fixedYDomain = fixedYDomain
    self.accessibilityLabel = accessibilityLabel
  }

  var body: some View {
    // These sparklines have no axes, legend, selection or per-point interaction.
    // Draw their paths directly instead of rebuilding a full chart layout.
    Canvas { context, size in
      guard let timeDomain = Self.timeDomain(primaryPoints + secondaryPoints) else { return }
      let valueDomain = resolvedYDomain
      let stroke = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
      context.clip(to: Path(CGRect(origin: .zero, size: size)))
      context.stroke(
        SparklineGeometry.path(
          points: primaryPoints, size: size, timeDomain: timeDomain, valueDomain: valueDomain),
        with: .color(primarySeries.color), style: stroke)
      if let secondarySeries {
        context.stroke(
          SparklineGeometry.path(
            points: secondaryPoints, size: size, timeDomain: timeDomain, valueDomain: valueDomain),
          with: .color(secondarySeries.color), style: stroke)
      }
    }
    .transaction { transaction in
      transaction.animation = nil
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }

  private var resolvedYDomain: ClosedRange<Double> {
    if let fixedYDomain {
      return fixedYDomain
    }

    var maximum = 0.0
    for point in primaryPoints {
      maximum = max(maximum, point.value)
    }
    for point in secondaryPoints {
      maximum = max(maximum, point.value)
    }
    return 0...Self.upperBound(for: maximum)
  }

  nonisolated static func upperBound(for maximum: Double) -> Double {
    guard maximum.isFinite, maximum > 0 else { return 1 }

    // Even finite samples can overflow when adding space above the chart.
    let paddedMaximum = maximum * 1.1
    return max(paddedMaximum.isFinite ? paddedMaximum : maximum, 1)
  }

  nonisolated static func timeDomain(_ points: [MetricChartPoint]) -> ClosedRange<Double>? {
    let times = points.map { $0.timestamp.timeIntervalSinceReferenceDate }.filter(\.isFinite)
    guard let lower = times.min(), let upper = times.max(), upper > lower,
      (upper - lower).isFinite
    else { return nil }
    return lower...upper
  }

  static func points(samples: RingBuffer<SystemSnapshot>, series: MetricChartSeries)
    -> [MetricChartPoint]
  {
    samples.compactMap { sample in
      guard let value = series.value(sample), value.isFinite, value >= 0 else { return nil }
      return MetricChartPoint(
        id: sample.id, timestamp: sample.timestamp, value: value, seriesName: series.name)
    }
  }
}

struct MetricChartPoint: Identifiable, Equatable, Sendable {
  let id: UUID
  let timestamp: Date
  let value: Double
  let seriesName: String
}

/// Pure geometry, independent of SwiftUI state and of any refresh timer.
enum SparklineGeometry {
  static func projectedPoints(
    _ points: [MetricChartPoint], size: CGSize,
    timeDomain: ClosedRange<Double>, valueDomain: ClosedRange<Double>
  ) -> [CGPoint] {
    let duration = timeDomain.upperBound - timeDomain.lowerBound
    let span = valueDomain.upperBound - valueDomain.lowerBound
    guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0,
      duration.isFinite, duration > 0, span.isFinite, span > 0
    else { return [] }
    return points.compactMap { point in
      let x = (point.timestamp.timeIntervalSinceReferenceDate - timeDomain.lowerBound) / duration
      let y = (point.value - valueDomain.lowerBound) / span
      guard x.isFinite, y.isFinite else { return nil }
      return CGPoint(
        x: min(max(x, 0), 1) * size.width,
        y: (1 - min(max(y, 0), 1)) * size.height)
    }
  }

  static func path(
    points: [MetricChartPoint], size: CGSize,
    timeDomain: ClosedRange<Double>, valueDomain: ClosedRange<Double>
  ) -> Path {
    let projected = projectedPoints(
      points, size: size, timeDomain: timeDomain, valueDomain: valueDomain)
    var path = Path()
    for segment in segments(projected) {
      if path.currentPoint != segment.start { path.move(to: segment.start) }
      path.addCurve(to: segment.end, control1: segment.control1, control2: segment.control2)
    }
    return path
  }

  struct Segment: Equatable {
    let start: CGPoint
    let control1: CGPoint
    let control2: CGPoint
    let end: CGPoint
  }

  /// Monotone cubic interpolation: smooth trends without invented overshoot.
  /// Duplicate/backward timestamps break the path instead of dividing by zero.
  static func segments(_ points: [CGPoint]) -> [Segment] {
    guard points.count >= 2 else { return [] }
    func slope(_ left: CGPoint, _ right: CGPoint) -> Double? {
      let dx = right.x - left.x
      guard dx.isFinite, dx > 0 else { return nil }
      let value = (right.y - left.y) / dx
      return value.isFinite ? value : nil
    }
    func tangent(at index: Int, fallback: Double) -> Double {
      guard index > 0, index + 1 < points.count,
        let left = slope(points[index - 1], points[index]),
        let right = slope(points[index], points[index + 1])
      else { return fallback }
      guard left != 0, right != 0, left.sign == right.sign else { return 0 }
      // A conservative slope limiter keeps control points within both neighbors.
      return (left.sign == .minus ? -1 : 1) * min(abs(left), abs(right))
    }
    var result: [Segment] = []
    result.reserveCapacity(points.count - 1)
    for index in 0..<(points.count - 1) {
      let start = points[index]
      let end = points[index + 1]
      guard start.x.isFinite, start.y.isFinite, end.x.isFinite, end.y.isFinite,
        let secant = slope(start, end)
      else { continue }
      let third = (end.x - start.x) / 3
      let lower = min(start.y, end.y)
      let upper = max(start.y, end.y)
      result.append(
        Segment(
          start: start,
          control1: CGPoint(
            x: start.x + third,
            y: min(max(start.y + tangent(at: index, fallback: secant) * third, lower), upper)),
          control2: CGPoint(
            x: end.x - third,
            y: min(max(end.y - tangent(at: index + 1, fallback: secant) * third, lower), upper)),
          end: end))
    }
    return result
  }
}
