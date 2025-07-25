import ComposableArchitecture
import SwiftUI

struct PerformanceMonitorView: View {
    @Dependency(\.documentGenerationPerformanceMonitor) var performanceMonitor
    @State private var performanceReport: PerformanceReport?
    @State private var optimizationSuggestions: [OptimizationSuggestion] = []
    @State private var isRunningBenchmark = false
    @State private var benchmarkResult: BenchmarkResult?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Document Generation Performance")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Monitor and optimize document generation performance")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)

                // Performance Metrics
                if let report = performanceReport {
                    PerformanceMetricsView(report: report)
                }

                // Optimization Suggestions
                if !optimizationSuggestions.isEmpty {
                    OptimizationSuggestionsView(suggestions: optimizationSuggestions)
                }

                // Benchmark Section
                BenchmarkView(
                    isRunning: $isRunningBenchmark,
                    result: $benchmarkResult,
                    onRunBenchmark: runBenchmark
                )

                // Refresh Button
                Button(action: loadPerformanceData) {
                    Label("Refresh Performance Data", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            .padding()
        }
        .onAppear {
            loadPerformanceData()
        }
    }

    private func loadPerformanceData() {
        Task {
            performanceReport = await performanceMonitor.getPerformanceReport()
            optimizationSuggestions = await performanceMonitor.getOptimizationSuggestions()
        }
    }

    private func runBenchmark() {
        Task {
            isRunningBenchmark = true
            do {
                benchmarkResult = try await performanceMonitor.runBenchmark()
            } catch {
                print("Benchmark failed: \(error)")
            }
            isRunningBenchmark = false
        }
    }
}

// MARK: - Performance Metrics View

struct PerformanceMetricsView: View {
    let report: PerformanceReport

    var body: some View {
        VStack(spacing: 16) {
            Text("Performance Metrics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Overview Cards
            HStack(spacing: 12) {
                MetricCard(
                    title: "Avg Generation Time",
                    value: String(format: "%.2fs", report.averageGenerationTime),
                    icon: "clock",
                    color: report.meetsGenerationTarget ? .green : .orange
                )

                MetricCard(
                    title: "Cache Hit Rate",
                    value: String(format: "%.0f%%", report.averageCacheHitRate * 100),
                    icon: "memorychip",
                    color: report.meetsCacheTarget ? .green : .orange
                )

                MetricCard(
                    title: "Speedup",
                    value: String(format: "%.1fx", report.averageSpeedup),
                    icon: "speedometer",
                    color: report.meetsSpeedupTarget ? .green : .orange
                )
            }

            // Session Metrics
            if let session = report.sessionMetrics {
                SessionMetricsView(session: session)
            }

            // Document Type Performance
            if !report.typeMetrics.isEmpty {
                DocumentTypePerformanceView(typeMetrics: report.typeMetrics)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}

struct SessionMetricsView: View {
    let session: DocumentGenerationPerformanceMonitor.SessionMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Session")
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack {
                Label("\(session.totalDocumentsGenerated) documents", systemImage: "doc.text")
                Spacer()
                Label(String(format: "%.1fs avg", session.averageGenerationTime), systemImage: "timer")
            }
            .font(.caption)

            HStack {
                Label("\(session.cacheHits) cache hits", systemImage: "checkmark.circle")
                Spacer()
                Label("\(session.cacheMisses) cache misses", systemImage: "xmark.circle")
            }
            .font(.caption)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct DocumentTypePerformanceView: View {
    let typeMetrics: [String: TypePerformance]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance by Document Type")
                .font(.subheadline)
                .fontWeight(.semibold)

            ForEach(typeMetrics.sorted(by: { $0.key < $1.key }), id: \.key) { type, performance in
                HStack {
                    Text(type)
                        .font(.caption)

                    Spacer()

                    Text(String(format: "%.2fs", performance.averageGenerationTime))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(performance.averageGenerationTime > 3.0 ? .orange : .primary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(String(format: "%.0f%%", performance.cacheHitRate * 100))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(performance.cacheHitRate > 0.7 ? .green : .orange)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Optimization Suggestions View

struct OptimizationSuggestionsView: View {
    let suggestions: [OptimizationSuggestion]

    var body: some View {
        VStack(spacing: 16) {
            Text("Optimization Suggestions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(suggestions.indices, id: \.self) { index in
                OptimizationCard(suggestion: suggestions[index])
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct OptimizationCard: View {
    let suggestion: OptimizationSuggestion

    var priorityColor: Color {
        switch suggestion.priority {
        case .high: .red
        case .medium: .orange
        case .low: .yellow
        }
    }

    var categoryIcon: String {
        switch suggestion.category {
        case .caching: "memorychip"
        case .performance: "speedometer"
        case .parallelization: "square.3.layers.3d"
        case .documentType: "doc.text"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: categoryIcon)
                .font(.title3)
                .foregroundColor(priorityColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.description)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(suggestion.recommendation)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}

// MARK: - Benchmark View

struct BenchmarkView: View {
    @Binding var isRunning: Bool
    @Binding var result: BenchmarkResult?
    let onRunBenchmark: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Performance Benchmark")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isRunning {
                ProgressView("Running benchmark...")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let result {
                BenchmarkResultView(result: result)
            } else {
                Button(action: onRunBenchmark) {
                    Label("Run Performance Benchmark", systemImage: "chart.line.uptrend.xyaxis")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct BenchmarkResultView: View {
    let result: BenchmarkResult

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Overall Speedup")
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.1fx", result.overallSpeedup))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(result.overallSpeedup >= 4.2 ? .green : .orange)
            }

            Divider()

            ForEach(result.results, id: \.testName) { test in
                HStack {
                    Text(test.testName)
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.2fs", test.averagePerDocument))
                        .font(.caption.monospacedDigit())
                }
            }

            Divider()

            Text(result.recommendation)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// Preview removed for cross-platform compatibility
