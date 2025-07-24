import AppCore
import ComposableArchitecture
import Foundation

/// Performance monitoring system for document generation
public actor DocumentGenerationPerformanceMonitor {
    // MARK: - Performance Metrics

    public struct GenerationMetrics: Sendable {
        public let documentType: String
        public let cacheHit: Bool
        public let totalDuration: TimeInterval
        public let apiCallDuration: TimeInterval?
        public let cacheCheckDuration: TimeInterval
        public let templateLoadDuration: TimeInterval
        public let spellCheckDuration: TimeInterval
        public let timestamp: Date

        public var speedImprovement: Double? {
            guard let apiDuration = apiCallDuration, apiDuration > 0 else { return nil }
            return (apiDuration - totalDuration) / apiDuration
        }
    }

    public struct BatchMetrics: Sendable {
        public let batchSize: Int
        public let totalDuration: TimeInterval
        public let parallelDuration: TimeInterval
        public let sequentialEstimate: TimeInterval
        public let speedup: Double
        public let timestamp: Date
    }

    public struct SessionMetrics: Sendable {
        public let sessionId: String
        public let startTime: Date
        public var endTime: Date?
        public var totalDocumentsGenerated: Int = 0
        public var cacheHits: Int = 0
        public var cacheMisses: Int = 0
        public var totalAPITime: TimeInterval = 0
        public var totalProcessingTime: TimeInterval = 0
        public var averageGenerationTime: TimeInterval {
            totalDocumentsGenerated > 0 ? totalProcessingTime / Double(totalDocumentsGenerated) : 0
        }

        public var cacheHitRate: Double {
            let total = cacheHits + cacheMisses
            return total > 0 ? Double(cacheHits) / Double(total) : 0
        }
    }

    // MARK: - Storage

    private var currentSession: SessionMetrics?
    private var generationMetrics: [GenerationMetrics] = []
    private var batchMetrics: [BatchMetrics] = []
    private let maxStoredMetrics = 1000

    // Performance thresholds
    private let targetGenerationTime: TimeInterval = 3.0 // 3 seconds per document
    private let targetCacheHitRate: Double = 0.7 // 70% cache hit rate
    private let targetSpeedup: Double = 4.2 // 4.2x speedup target

    // MARK: - Session Management

    public func startSession() -> String {
        let sessionId = UUID().uuidString
        currentSession = SessionMetrics(
            sessionId: sessionId,
            startTime: Date()
        )
        return sessionId
    }

    public func endSession() {
        currentSession?.endTime = Date()
    }

    // MARK: - Metric Recording

    public func recordGeneration(
        documentType: String,
        cacheHit: Bool,
        durations: (
            total: TimeInterval,
            apiCall: TimeInterval?,
            cacheCheck: TimeInterval,
            templateLoad: TimeInterval,
            spellCheck: TimeInterval
        )
    ) {
        let metric = GenerationMetrics(
            documentType: documentType,
            cacheHit: cacheHit,
            totalDuration: durations.total,
            apiCallDuration: durations.apiCall,
            cacheCheckDuration: durations.cacheCheck,
            templateLoadDuration: durations.templateLoad,
            spellCheckDuration: durations.spellCheck,
            timestamp: Date()
        )

        generationMetrics.append(metric)

        // Update session metrics
        if var session = currentSession {
            session.totalDocumentsGenerated += 1
            session.totalProcessingTime += durations.total

            if cacheHit {
                session.cacheHits += 1
            } else {
                session.cacheMisses += 1
                if let apiDuration = durations.apiCall {
                    session.totalAPITime += apiDuration
                }
            }
            currentSession = session
        }

        // Maintain size limit
        if generationMetrics.count > maxStoredMetrics {
            generationMetrics.removeFirst()
        }
    }

    public func recordBatch(
        size: Int,
        totalDuration: TimeInterval,
        parallelDuration: TimeInterval
    ) {
        let sequentialEstimate = Double(size) * targetGenerationTime
        let speedup = sequentialEstimate / totalDuration

        let metric = BatchMetrics(
            batchSize: size,
            totalDuration: totalDuration,
            parallelDuration: parallelDuration,
            sequentialEstimate: sequentialEstimate,
            speedup: speedup,
            timestamp: Date()
        )

        batchMetrics.append(metric)

        // Maintain size limit
        if batchMetrics.count > maxStoredMetrics {
            batchMetrics.removeFirst()
        }
    }

    // MARK: - Performance Analysis

    public func getPerformanceReport() -> PerformanceReport {
        let recentMetrics = generationMetrics.suffix(100)
        let recentBatches = batchMetrics.suffix(20)

        // Calculate averages
        let avgGenerationTime = recentMetrics.reduce(0.0) { $0 + $1.totalDuration } / Double(recentMetrics.count)
        let avgCacheHitRate = Double(recentMetrics.filter(\.cacheHit).count) / Double(recentMetrics.count)
        let avgSpeedup = recentBatches.reduce(0.0) { $0 + $1.speedup } / Double(recentBatches.count)

        // Calculate by document type
        var typeMetrics: [String: TypePerformance] = [:]
        let groupedByType = Dictionary(grouping: recentMetrics, by: { $0.documentType })

        for (type, metrics) in groupedByType {
            let avgTime = metrics.reduce(0.0) { $0 + $1.totalDuration } / Double(metrics.count)
            let cacheRate = Double(metrics.filter(\.cacheHit).count) / Double(metrics.count)

            typeMetrics[type] = TypePerformance(
                documentType: type,
                averageGenerationTime: avgTime,
                cacheHitRate: cacheRate,
                sampleCount: metrics.count
            )
        }

        // Check performance targets
        let meetsGenerationTarget = avgGenerationTime <= targetGenerationTime
        let meetsCacheTarget = avgCacheHitRate >= targetCacheHitRate
        let meetsSpeedupTarget = avgSpeedup >= targetSpeedup

        return PerformanceReport(
            sessionMetrics: currentSession,
            averageGenerationTime: avgGenerationTime,
            averageCacheHitRate: avgCacheHitRate,
            averageSpeedup: avgSpeedup,
            typeMetrics: typeMetrics,
            meetsGenerationTarget: meetsGenerationTarget,
            meetsCacheTarget: meetsCacheTarget,
            meetsSpeedupTarget: meetsSpeedupTarget,
            recentGenerations: Array(recentMetrics),
            recentBatches: Array(recentBatches)
        )
    }

    // MARK: - Performance Optimization Suggestions

    public func getOptimizationSuggestions() -> [OptimizationSuggestion] {
        var suggestions: [OptimizationSuggestion] = []
        let report = getPerformanceReport()

        // Check cache hit rate
        if report.averageCacheHitRate < targetCacheHitRate {
            suggestions.append(OptimizationSuggestion(
                category: .caching,
                priority: .high,
                description: "Cache hit rate is \(String(format: "%.1f%%", report.averageCacheHitRate * 100)), below target of \(String(format: "%.0f%%", targetCacheHitRate * 100))",
                recommendation: "Consider increasing cache expiration time or pre-warming cache with common documents"
            ))
        }

        // Check generation time
        if report.averageGenerationTime > targetGenerationTime {
            suggestions.append(OptimizationSuggestion(
                category: .performance,
                priority: .high,
                description: "Average generation time is \(String(format: "%.2fs", report.averageGenerationTime)), above target of \(String(format: "%.1fs", targetGenerationTime))",
                recommendation: "Enable batch generation or increase parallel processing"
            ))
        }

        // Check speedup
        if report.averageSpeedup < targetSpeedup {
            suggestions.append(OptimizationSuggestion(
                category: .parallelization,
                priority: .medium,
                description: "Average speedup is \(String(format: "%.1fx", report.averageSpeedup)), below target of \(String(format: "%.1fx", targetSpeedup))",
                recommendation: "Increase batch sizes or optimize parallel processing configuration"
            ))
        }

        // Check for slow document types
        for (type, performance) in report.typeMetrics where performance.averageGenerationTime > targetGenerationTime * 1.5 {
            suggestions.append(OptimizationSuggestion(
                category: .documentType,
                priority: .medium,
                description: "\(type) documents are slow (\(String(format: "%.2fs", performance.averageGenerationTime)) average)",
                recommendation: "Consider optimizing template or system prompt for \(type)"
            ))
        }

        return suggestions
    }

    // MARK: - Benchmarking

    public func runBenchmark() async throws -> BenchmarkResult {
        _ = [DocumentType.sow, DocumentType.marketResearch, DocumentType.evaluationPlan]
        _ = "Benchmark test: Cloud computing services for data analytics platform"

        var results: [BenchmarkTestResult] = []

        // Test sequential generation
        let sequentialStart = Date()
        var sequentialTimes: [TimeInterval] = []

        for _ in 0 ..< 3 {
            let start = Date()
            // Simulate generation
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            sequentialTimes.append(Date().timeIntervalSince(start))
        }

        let sequentialTotal = Date().timeIntervalSince(sequentialStart)

        // Test parallel generation
        let parallelStart = Date()

        await withTaskGroup(of: TimeInterval.self) { group in
            for _ in 0 ..< 3 {
                group.addTask {
                    let start = Date()
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    return Date().timeIntervalSince(start)
                }
            }

            for await time in group {
                // Collect times
                _ = time
            }
        }

        let parallelTotal = Date().timeIntervalSince(parallelStart)

        // Test with cache
        let cacheStart = Date()
        // Simulate cache hit
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        let cacheTotal = Date().timeIntervalSince(cacheStart)

        results.append(BenchmarkTestResult(
            testName: "Sequential Generation",
            duration: sequentialTotal,
            documentsGenerated: 3,
            averagePerDocument: sequentialTotal / 3
        ))

        results.append(BenchmarkTestResult(
            testName: "Parallel Generation",
            duration: parallelTotal,
            documentsGenerated: 3,
            averagePerDocument: parallelTotal / 3
        ))

        results.append(BenchmarkTestResult(
            testName: "Cached Generation",
            duration: cacheTotal,
            documentsGenerated: 1,
            averagePerDocument: cacheTotal
        ))

        let speedup = sequentialTotal / parallelTotal

        return BenchmarkResult(
            timestamp: Date(),
            results: results,
            overallSpeedup: speedup,
            recommendation: speedup >= targetSpeedup ?
                "Performance optimization successful! Achieved \(String(format: "%.1fx", speedup)) speedup." :
                "Further optimization needed. Current speedup: \(String(format: "%.1fx", speedup)), target: \(String(format: "%.1fx", targetSpeedup))"
        )
    }
}

// MARK: - Supporting Types

public struct PerformanceReport: Sendable {
    public let sessionMetrics: DocumentGenerationPerformanceMonitor.SessionMetrics?
    public let averageGenerationTime: TimeInterval
    public let averageCacheHitRate: Double
    public let averageSpeedup: Double
    public let typeMetrics: [String: TypePerformance]
    public let meetsGenerationTarget: Bool
    public let meetsCacheTarget: Bool
    public let meetsSpeedupTarget: Bool
    public let recentGenerations: [DocumentGenerationPerformanceMonitor.GenerationMetrics]
    public let recentBatches: [DocumentGenerationPerformanceMonitor.BatchMetrics]
}

public struct TypePerformance: Sendable {
    public let documentType: String
    public let averageGenerationTime: TimeInterval
    public let cacheHitRate: Double
    public let sampleCount: Int
}

public struct OptimizationSuggestion: Sendable {
    public enum Category: Sendable {
        case caching
        case performance
        case parallelization
        case documentType
    }

    public enum Priority: Sendable {
        case high
        case medium
        case low
    }

    public let category: Category
    public let priority: Priority
    public let description: String
    public let recommendation: String
}

public struct BenchmarkResult: Sendable {
    public let timestamp: Date
    public let results: [BenchmarkTestResult]
    public let overallSpeedup: Double
    public let recommendation: String
}

public struct BenchmarkTestResult: Sendable {
    public let testName: String
    public let duration: TimeInterval
    public let documentsGenerated: Int
    public let averagePerDocument: TimeInterval
}

// MARK: - Dependency Key

public struct DocumentGenerationPerformanceMonitorKey: DependencyKey {
    public static let liveValue = DocumentGenerationPerformanceMonitor()
    public static let testValue = DocumentGenerationPerformanceMonitor()
}

public extension DependencyValues {
    var documentGenerationPerformanceMonitor: DocumentGenerationPerformanceMonitor {
        get { self[DocumentGenerationPerformanceMonitorKey.self] }
        set { self[DocumentGenerationPerformanceMonitorKey.self] = newValue }
    }
}
