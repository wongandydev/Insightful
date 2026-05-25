import SwiftUI

/// Renders today's insight: the agent's writeup, alert pills, recommended
/// actions, and charts for the metrics the insight calls out. A gear in the
/// toolbar lets the user open settings (sign out / re-do goal setup).
struct DailyInsightView: View {
    @State private var viewModel: DailyInsightViewModel
    private let onOpenSettings: () -> Void

    init(
        healthKitService: any HealthKitServicing,
        insightService: any InsightServicing,
        onOpenSettings: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: DailyInsightViewModel(
            healthKitService: healthKitService,
            insightService: insightService
        ))
        self.onOpenSettings = onOpenSettings
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
                case .error(let message):
                    ErrorState(message: message) {
                        Task { await viewModel.load() }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onOpenSettings()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
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
            Text("Crunching today's data…")
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

private struct InsightContent: View {
    let insight: Insight
    let metricsPayload: [String: MetricValue]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if !insight.alerts.isEmpty {
                    alertSection
                }
                insightSection
                if !chartEntries.isEmpty {
                    chartSection
                }
                if !insight.recommendedActions.isEmpty {
                    actionSection
                }
            }
            .padding()
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
                InsightChart(metricName: entry.name, values: entry.values)
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
