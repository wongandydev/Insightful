import SwiftUI
import Charts

/// One metric's last-7-days series rendered as a labelled line + point chart.
///
/// The day axis is the position of each reading in `values`, oldest → newest.
/// Y axis is whatever unit the underlying ``HealthKitMetric`` produces — we
/// do not display a unit suffix because metric names already imply units in
/// practice (e.g. "Sleep Hours", "Resting Heart Rate").
struct InsightChart: View {
    let metricName: String
    let values: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(humanize(metricName))
                .font(.headline)
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
            }
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
            .frame(height: 160)
        }
    }

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
