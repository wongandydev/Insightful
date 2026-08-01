import SwiftUI
import Charts

/// One metric's last-7-days series rendered as a labelled line + point chart.
///
/// The day axis is the position of each reading in ``values``, oldest → newest.
/// The Y axis title comes from a static metric-key → unit map keyed by
/// ``metricName``, falling back to "value" for unknown keys.
///
/// When ``metadata`` is supplied, its title replaces the humanized metric name
/// and its rationale renders as a caption beneath the title.
///
/// Tapping anywhere on the chart selects the nearest day: a ``RuleMark`` overlays
/// the chart with a floating tooltip showing that day's label and exact value.
struct InsightChart: View {
    let metricName: String
    let values: [Double]
    let metadata: ChartMetadata?

    @State private var selectedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metadata?.title ?? humanize(metricName))
                .font(.headline)
            if let rationale = metadata?.rationale {
                Text(rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Chart {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Day", index),
                        y: .value("Value", value)
                    )
                    .interpolationMethod(.monotone)
                    PointMark(
                        x: .value("Day", index),
                        y: .value("Value", value)
                    )
                }
                
                if let selectedIndex, values.indices.contains(selectedIndex) {
                    RuleMark(x: .value("Day", selectedIndex))
                        .foregroundStyle(Color.secondary.opacity(0.4))
                        .annotation(
                            position: .top,
                            alignment: .center,
                            spacing: 6,
                            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                        ) {
                            tooltip(forIndex: selectedIndex)
                        }
                }
            }
            .chartXSelection(value: $selectedIndex)
            .chartXScale(domain: 0...max(values.count - 1, 0))
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: values.count)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let i = value.as(Int.self) {
                            Text(dayLabel(daysAgo: values.count - 1 - i))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxisLabel(yAxisLabel)
            .frame(height: 160)
        }
    }

    private func tooltip(forIndex index: Int) -> some View {
        VStack(spacing: 2) {
            Text(dayLabel(daysAgo: values.count - 1 - index))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(formattedValue(values[index]))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
    }

    private func formattedValue(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    private var yAxisLabel: String {
        Self.yAxisLabels[metricName] ?? "value"
    }

    /// Pinned so toggling the RuleMark doesn't reflow the plot area.
    private var yDomain: ClosedRange<Double> {
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        let pad = max((hi - lo) * 0.1, 0.5)
        return max(lo - pad, 0)...(hi + pad)
    }

    /// Display unit for each metric the backend whitelist accepts, keyed by
    /// ``HealthKitMetric`` raw value.
    private static let yAxisLabels: [String: String] = [
        "activeEnergyBurned": "kcal",
        "basalEnergyBurned": "kcal",
        "appleExerciseTime": "min",
        "bodyMass": "kg",
        "bodyFatPercentage": "%",
        "heartRateVariabilitySDNN": "ms",
        "restingHeartRate": "bpm",
        "heartRateRecoveryOneMinute": "bpm",
        "vo2Max": "ml/kg/min",
        "oxygenSaturation": "%",
        "respiratoryRate": "breaths/min",
        "sleepAnalysis": "hours",
        "sleepHours": "hours",
        "appleSleepingWristTemperature": "°C",
        "distanceWalkingRunning": "m",
        "distanceRunning": "m",
        "distanceCycling": "m",
        "distanceSwimming": "m",
        "runningPower": "W",
        "runningSpeed": "m/s",
        "cyclingPower": "W",
        "cyclingSpeed": "m/s",
        "steps": "steps",
    ]

    /// `sleepHours` → "Sleep Hours". Runs of consecutive capitals are kept
    /// together so acronyms like `heartRateVariabilitySDNN` render as
    /// "Heart Rate Variability SDNN" instead of "S D N N".
    private func humanize(_ camelCase: String) -> String {
        var result = ""
        let chars = Array(camelCase)
        for (i, char) in chars.enumerated() {
            if i > 0 && char.isUppercase {
                let prev = chars[i - 1]
                let next = i + 1 < chars.count ? chars[i + 1] : nil
                if prev.isLowercase || (next?.isLowercase ?? false) {
                    result.append(" ")
                }
            }
            if i == 0 {
                result.append(Character(char.uppercased()))
            } else {
                result.append(char)
            }
        }
        return result
    }

    private func dayLabel(daysAgo: Int) -> String {
        switch daysAgo {
        case 0: return "Today"
        case 1: return "Yesterday"
        default: return "\(daysAgo)d"
        }
    }
}
