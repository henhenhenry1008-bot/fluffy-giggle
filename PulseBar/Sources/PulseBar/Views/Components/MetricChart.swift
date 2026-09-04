import Charts
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
    Group {
      if #available(macOS 15, *) {
        vectorizedChart
      } else {
        // Keep the existing renderer on macOS 14, where LinePlot is unavailable.
        Chart {
          ForEach(primaryPoints) { point in
            lineMark(point: point, series: primarySeries)
          }
          if let secondarySeries {
            ForEach(secondaryPoints) { point in
              lineMark(point: point, series: secondarySeries)
            }
          }
        }
      }
    }
    .chartXScale(range: .plotDimension(padding: 0))
    .chartYScale(domain: resolvedYDomain)
    .chartXAxis(.hidden)
    .chartYAxis(.hidden)
    .chartLegend(.hidden)
    .transaction { transaction in
      transaction.animation = nil
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }

  @available(macOS 15, *)
  private var vectorizedChart: some View {
    Chart {
      vectorizedLine(primaryPoints, series: primarySeries)
      if let secondarySeries {
        vectorizedLine(secondaryPoints, series: secondarySeries)
      }
    }
  }

  @available(macOS 15, *)
  private func vectorizedLine(_ points: [MetricChartPoint], series: MetricChartSeries)
    -> some ChartContent
  {
    // Stored-property projections let Charts draw one batch per series instead
    // of maintaining hundreds of independent SwiftUI mark nodes each tick.
    LinePlot(
      points,
      x: .value("Time", \.timestamp),
      y: .value(series.name, \.value),
      series: .value("Metric", \.seriesName)
    )
    .foregroundStyle(series.color)
    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
    .interpolationMethod(.monotone)
  }

  private func lineMark(point: MetricChartPoint, series: MetricChartSeries) -> some ChartContent {
    LineMark(
      x: .value("Time", point.timestamp),
      y: .value(series.name, point.value),
      series: .value("Metric", series.name)
    )
    .foregroundStyle(series.color)
    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
    .interpolationMethod(.monotone)
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
