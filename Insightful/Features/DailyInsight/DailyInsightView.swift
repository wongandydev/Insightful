import SwiftUI
import UIKit

/// Renders today's insight: the agent's writeup, alert pills, recommended
/// actions, and charts for the metrics the insight calls out.
struct DailyInsightView: View {
    @Environment(\.openURL) private var openURL
    @State private var viewModel: DailyInsightViewModel

    init(
        healthKitService: any HealthKitServicing,
        insightService: any InsightServicing
    ) {
        _viewModel = State(initialValue: DailyInsightViewModel(
            healthKitService: healthKitService,
            insightService: insightService
        ))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .loading:
                    LoadingState()
                case .ready(let insight):
                    InsightContent(
                        insight: insight,
                        metricsPayload: viewModel.metricsPayload
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                Task { await viewModel.load(force: true) }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .accessibilityLabel("Regenerate today's insight")
                        }
                    }
                case .noHealthData:
                    NoHealthDataState(
                        onOpenSettings: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        },
                        onRetry: { Task { await viewModel.load() } }
                    )
                case .error(let message):
                    ErrorState(message: message) {
                        Task { await viewModel.load() }
                    }
                }
            }
        }
        .task { await viewModel.load() }
    }
}

private struct LoadingState: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Crunching your daily insight data…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ErrorState: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message).multilineTextAlignment(.center)
            Button("Try again", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NoHealthDataState: View {
    let onOpenSettings: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("We can't see any Apple Health data yet.")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Open Settings to grant access, then come back.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings", action: onOpenSettings)
                .buttonStyle(.borderedProminent)
            Button("Try again", action: onRetry)
                .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct InsightContent: View {
    let insight: Insight
    let metricsPayload: [String: MetricValue]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                
                if let progress = insight.progress {
                    ProgressCallout(progress: progress)
                }
                
                if !insight.alerts.isEmpty {
                    alertSection
                }
                insightSection
                
                if !insight.recommendedActions.isEmpty {
                    actionSection
                }
                
                if !chartEntries.isEmpty {
                    chartSection
                }
            }
            .padding(.horizontal)
            .padding(.top, 24)
            .padding(.bottom)
        }
    }

    /// Resolves ``Insight/chartsToShow`` against ``metricsPayload``, dropping
    /// names that have no payload entry or whose entry is a scalar (single
    /// reading — not chartable).
    private var chartEntries: [(name: String, values: [Double])] {
        insight.chartsToShow.compactMap { name in
            guard case .series(let values) = metricsPayload[name], values.count > 1 else {
                return nil
            }
            return (name: name, values: values)
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(chartEntries, id: \.name) { entry in
                InsightChart(
                    metricName: entry.name,
                    values: entry.values,
                    metadata: insight.chartMetadata[entry.name]
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today's Insight")
                .font(.title.bold())
            Text(Date(), style: .date)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let generatedAt = insight.generatedAtDate {
                Text("Generated at \(generatedAt, format: .dateTime.hour().minute())")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var alertSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(insight.alerts, id: \.self) { alert in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                    Text(alert)
                        .font(.subheadline)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var insightSection: some View {
        Text(insight.insightText)
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommended actions")
                .font(.headline)
            ForEach(insight.recommendedActions, id: \.self) { action in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(Color.accentColor)
                    Text(action)
                        .font(.subheadline)
                }
            }
        }
    }
}

