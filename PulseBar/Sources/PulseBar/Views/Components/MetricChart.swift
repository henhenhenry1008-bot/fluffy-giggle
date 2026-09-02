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
  let samples: RingBuffer<SystemSnapshot>
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
    self.samples = samples
    self.primarySeries = primarySeries
    self.secondarySeries = secondarySeries
    self.fixedYDomain = fixedYDomain
    self.accessibilityLabel = accessibilityLabel
  }

  var body: some View {
    Chart {
      ForEach(samples) { sample in
        if let value = sanitized(primarySeries.value(sample)) {
          lineMark(sample: sample, value: value, series: primarySeries)
        }

        if let secondarySeries,
          let value = sanitized(secondarySeries.value(sample))
        {
          lineMark(sample: sample, value: value, series: secondarySeries)
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

  private func lineMark(
    sample: SystemSnapshot,
    value: Double,
    series: MetricChartSeries
  ) -> some ChartContent {
    LineMark(
      x: .value("Time", sample.timestamp),
      y: .value(series.name, value),
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
    for sample in samples {
      maximum = max(maximum, sanitized(primarySeries.value(sample)) ?? 0)
      if let secondarySeries {
        maximum = max(maximum, sanitized(secondarySeries.value(sample)) ?? 0)
      }
    }
    return 0...max(maximum * 1.1, 1)
  }

  private func sanitized(_ value: Double?) -> Double? {
    guard let value, value.isFinite, value >= 0 else { return nil }
    return value
  }
}
