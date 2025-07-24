import ComposableArchitecture
import Foundation

/// Cache warming strategies for preloading frequently accessed data
public actor CacheWarmingStrategy {
    // MARK: - Properties

    private let cache: ObjectActionCache
    private let objectActionHandler: OptimizedObjectActionHandler
    private var warmingTasks: [String: Task<Void, Never>] = [:]
    private var warmingMetrics = WarmingMetrics()

    // Configuration
    private let configuration: WarmingConfiguration

    // MARK: - Configuration

    public struct WarmingConfiguration: Sendable {
        let maxConcurrentWarming: Int
        let warmingBatchSize: Int
        let priorityThreshold: Double
        let preloadDepth: Int
        let adaptiveLearning: Bool
        let warmingTimeout: TimeInterval

        public init(
            maxConcurrentWarming: Int = 5,
            warmingBatchSize: Int = 50,
            priorityThreshold: Double = 0.7,
            preloadDepth: Int = 2,
            adaptiveLearning: Bool = true,
            warmingTimeout: TimeInterval = 30.0
        ) {
            self.maxConcurrentWarming = maxConcurrentWarming
            self.warmingBatchSize = warmingBatchSize
            self.priorityThreshold = priorityThreshold
            self.preloadDepth = preloadDepth
            self.adaptiveLearning = adaptiveLearning
            self.warmingTimeout = warmingTimeout
        }
    }

    // MARK: - Warming Strategies

    public enum WarmingStrategy: Sendable {
        case predictive(PredictiveConfig)
        case scheduled(ScheduleConfig)
        case onDemand(patterns: [String])
        case related(depth: Int)
        case trending(window: TimeInterval)
        case userBased(userId: String)
        case hybrid([WarmingStrategy])

        public struct PredictiveConfig: Sendable {
            let historyWindow: TimeInterval
            let minConfidence: Double
            let maxPredictions: Int
        }

        public struct ScheduleConfig: Sendable {
            let schedule: [DateComponents]
            let actions: [ActionPattern]
        }
    }

    // MARK: - Action Patterns

    public struct ActionPattern: @unchecked Sendable {
        let actionType: ActionType
        let objectType: ObjectType
        let predicate: ((ObjectAction) -> Bool)?
        let priority: Double

        public init(
            actionType: ActionType,
            objectType: ObjectType,
            predicate: ((ObjectAction) -> Bool)? = nil,
            priority: Double = 1.0
        ) {
            self.actionType = actionType
            self.objectType = objectType
            self.predicate = predicate
            self.priority = priority
        }
    }

    // MARK: - Initialization

    public init(
        cache: ObjectActionCache,
        objectActionHandler: OptimizedObjectActionHandler,
        configuration: WarmingConfiguration = .init()
    ) {
        self.cache = cache
        self.objectActionHandler = objectActionHandler
        self.configuration = configuration
    }

    // MARK: - Public Methods

    /// Warm cache using specified strategy
    public func warmCache(using strategy: WarmingStrategy) async throws {
        let warmingId = UUID().uuidString

        let task = Task {
            await executeWarmingStrategy(strategy, warmingId: warmingId)
        }

        warmingTasks[warmingId] = task

        // Cleanup after completion
        defer {
            warmingTasks.removeValue(forKey: warmingId)
        }

        // Wait with timeout
        try await withTaskCancellationHandler {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(self.configuration.warmingTimeout * 1_000_000_000))
                    task.cancel()
                    throw CacheWarmingError.timeout
                }

                group.addTask {
                    _ = await task.result
                }

                try await group.next()
                group.cancelAll()
            }
        } onCancel: {
            task.cancel()
        }
    }

    /// Start background warming with multiple strategies
    public func startBackgroundWarming(strategies: [WarmingStrategy]) -> Task<Void, Never> {
        Task {
            while !Task.isCancelled {
                for strategy in strategies {
                    guard !Task.isCancelled else { break }

                    do {
                        try await warmCache(using: strategy)
                    } catch {
                        print("[CacheWarming] Strategy failed: \(error)")
                    }

                    // Pause between strategies
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                }

                // Pause before next cycle
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 1 minute
            }
        }
    }

    /// Get warming metrics
    public func getMetrics() -> WarmingMetrics {
        warmingMetrics
    }

    /// Cancel all warming tasks
    public func cancelAllWarming() {
        for (_, task) in warmingTasks {
            task.cancel()
        }
        warmingTasks.removeAll()
    }

    // MARK: - Private Methods

    private func executeWarmingStrategy(_ strategy: WarmingStrategy, warmingId _: String) async {
        let startTime = Date()

        switch strategy {
        case let .predictive(config):
            await executePredictiveWarming(config)

        case let .scheduled(config):
            await executeScheduledWarming(config)

        case let .onDemand(patterns):
            await executeOnDemandWarming(patterns)

        case let .related(depth):
            await executeRelatedWarming(depth: depth)

        case let .trending(window):
            await executeTrendingWarming(window: window)

        case let .userBased(userId):
            await executeUserBasedWarming(userId: userId)

        case let .hybrid(strategies):
            await executeHybridWarming(strategies)
        }

        warmingMetrics.recordWarming(
            strategy: String(describing: strategy),
            duration: Date().timeIntervalSince(startTime)
        )
    }

    // MARK: - Predictive Warming

    private func executePredictiveWarming(_ config: WarmingStrategy.PredictiveConfig) async {
        // Analyze access patterns
        let predictions = await analyzePredictivePatterns(
            historyWindow: config.historyWindow,
            minConfidence: config.minConfidence
        )

        // Warm top predictions
        let topPredictions = Array(predictions.prefix(config.maxPredictions))
        await warmActions(topPredictions.map(\.action))
    }

    private func analyzePredictivePatterns(
        historyWindow _: TimeInterval,
        minConfidence: Double
    ) async -> [CachePredictedAction] {
        // Get historical access patterns from cache metrics
        _ = await cache.getMetrics()

        // Analyze patterns (simplified)
        var predictions: [CachePredictedAction] = []

        // Time-based patterns
        let currentHour = Calendar.current.component(.hour, from: Date())
        let currentDayOfWeek = Calendar.current.component(.weekday, from: Date())

        // Common patterns
        if currentHour >= 9, currentHour <= 17 { // Business hours
            predictions.append(CachePredictedAction(
                action: ObjectAction(
                    id: UUID(),
                    type: .generate,
                    objectType: .document,
                    objectId: "cached-doc-\(UUID().uuidString.prefix(8))",
                    context: ActionContext(
                        userId: "system",
                        sessionId: "warming-\(UUID().uuidString.prefix(8))",
                        timestamp: Date(),
                        environment: .production,
                        metadata: ["warming": "predictive"]
                    )
                ),
                confidence: 0.8,
                reason: "Business hours - document generation likely"
            ))
        }

        if currentDayOfWeek == 2 { // Monday
            predictions.append(CachePredictedAction(
                action: ObjectAction(
                    id: UUID(),
                    type: .analyze,
                    objectType: .requirement,
                    objectId: "cached-req-\(UUID().uuidString.prefix(8))",
                    context: ActionContext(
                        userId: "system",
                        sessionId: "warming-\(UUID().uuidString.prefix(8))",
                        timestamp: Date(),
                        environment: .production,
                        metadata: ["warming": "predictive"]
                    )
                ),
                confidence: 0.75,
                reason: "Monday - requirement analysis common"
            ))
        }

        return predictions.filter { $0.confidence >= minConfidence }
    }

    // MARK: - Scheduled Warming

    private func executeScheduledWarming(_ config: WarmingStrategy.ScheduleConfig) async {
        let calendar = Calendar.current
        let now = Date()

        // Check if any schedule matches current time
        for schedule in config.schedule where calendar.dateComponents([.hour, .minute], from: now) == schedule {
            // Warm all configured actions
            for pattern in config.actions {
                await warmPattern(pattern)
            }
            break
        }
    }

    // MARK: - On-Demand Warming

    private func executeOnDemandWarming(_ patterns: [String]) async {
        // Parse patterns and warm matching actions
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                await warmMatchingPattern(regex)
            }
        }
    }

    // MARK: - Related Warming

    private func executeRelatedWarming(depth: Int) async {
        // Get recently accessed items
        let recentKeys = await cache.getRecentlyAccessedKeys(limit: 10)

        // For each recent item, warm related items
        for key in recentKeys {
            await warmRelatedActions(for: key, depth: depth, visited: Set())
        }
    }

    private func warmRelatedActions(
        for key: ObjectActionCache.CacheKey,
        depth: Int,
        visited: Set<String>
    ) async {
        guard depth > 0 else { return }

        var newVisited = visited
        newVisited.insert(key.actionType + key.objectType)

        // Find related actions
        let relatedActions = await findRelatedActions(for: key)

        // Warm related actions
        for action in relatedActions {
            let relatedKey = ObjectActionCache.CacheKey(action: action)

            if !newVisited.contains(relatedKey.actionType + relatedKey.objectType) {
                await warmAction(action)
                await warmRelatedActions(for: relatedKey, depth: depth - 1, visited: newVisited)
            }
        }
    }

    // MARK: - Trending Warming

    private func executeTrendingWarming(window: TimeInterval) async {
        // Analyze trending actions in the time window
        let trendingActions = await analyzeTrendingActions(window: window)

        // Warm trending actions
        await warmActions(trendingActions.map(\.action))
    }

    private func analyzeTrendingActions(window _: TimeInterval) async -> [TrendingAction] {
        // Get access patterns from cache
        _ = await cache.getMetrics()

        // Simplified trending analysis
        var trending: [TrendingAction] = []

        // Most common action types
        trending.append(TrendingAction(
            action: ObjectAction(
                id: UUID(),
                type: .generate,
                objectType: .document,
                objectId: "cached-trending-\(UUID().uuidString.prefix(8))",
                context: ActionContext(
                    userId: "system",
                    sessionId: "warming-\(UUID().uuidString.prefix(8))",
                    timestamp: Date(),
                    environment: .production,
                    metadata: ["warming": "trending"]
                )
            ),
            score: 0.9,
            accessCount: 100
        ))

        return trending
    }

    // MARK: - User-Based Warming

    private func executeUserBasedWarming(userId: String) async {
        // Get user's common actions
        let userPatterns = await analyzeUserPatterns(userId: userId)

        // Warm user's likely actions
        for pattern in userPatterns {
            await warmPattern(pattern)
        }
    }

    private func analyzeUserPatterns(userId _: String) async -> [ActionPattern] {
        // Analyze user's historical patterns
        // This would integrate with user tracking service

        [
            ActionPattern(
                actionType: .generate,
                objectType: .document,
                priority: 0.9
            ),
            ActionPattern(
                actionType: .analyze,
                objectType: .requirement,
                priority: 0.8
            ),
        ]
    }

    // MARK: - Hybrid Warming

    private func executeHybridWarming(_ strategies: [WarmingStrategy]) async {
        // Execute multiple strategies with priority
        await withTaskGroup(of: Void.self) { group in
            for strategy in strategies.prefix(configuration.maxConcurrentWarming) {
                group.addTask {
                    await self.executeWarmingStrategy(strategy, warmingId: UUID().uuidString)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func warmActions(_ actions: [ObjectAction]) async {
        // Batch warm actions
        for batch in actions.chunked(into: configuration.warmingBatchSize) {
            await withTaskGroup(of: Void.self) { group in
                for action in batch {
                    group.addTask {
                        await self.warmAction(action)
                    }
                }
            }
        }
    }

    private func warmAction(_ action: ObjectAction) async {
        // Create a simulated result for cache warming
        let result = ActionResult(
            actionId: action.id,
            status: .completed,
            output: ActionOutput(
                type: .json,
                data: Data("warmed".utf8),
                metadata: ["warmed": "true"]
            ),
            metrics: ActionMetrics(
                startTime: Date(),
                endTime: Date(),
                cpuUsage: 0.1,
                memoryUsage: 0.1,
                successRate: 1.0,
                performanceScore: 0.9,
                effectivenessScore: 0.9
            )
        )

        // Cache the action with its result
        await cache.set(action, result: result, ttl: 3600)
        warmingMetrics.recordSuccess()
    }

    private func warmPattern(_ pattern: ActionPattern) async {
        // Create sample action matching pattern
        let action = ObjectAction(
            id: UUID(),
            type: pattern.actionType,
            objectType: pattern.objectType,
            objectId: "cached-pattern-\(UUID().uuidString.prefix(8))",
            context: ActionContext(
                userId: "system",
                sessionId: "warming-\(UUID().uuidString.prefix(8))",
                timestamp: Date(),
                environment: .production,
                metadata: ["warming": "pattern", "priority": String(pattern.priority)]
            )
        )

        if let predicate = pattern.predicate, !predicate(action) {
            return
        }

        await warmAction(action)
    }

    private func warmMatchingPattern(_: NSRegularExpression) async {
        // This would search for matching patterns in historical data
        // For now, warm common patterns
        let commonPatterns = [
            ActionPattern(actionType: .generate, objectType: .document),
            ActionPattern(actionType: .analyze, objectType: .requirement),
        ]

        for pattern in commonPatterns {
            await warmPattern(pattern)
        }
    }

    private func findRelatedActions(for key: ObjectActionCache.CacheKey) async -> [ObjectAction] {
        // Find actions related to the given key
        var related: [ObjectAction] = []

        // Related by object type
        if key.objectType == ObjectType.document.rawValue {
            related.append(ObjectAction(
                id: UUID(),
                type: .validate,
                objectType: .document,
                objectId: key.objectId.isEmpty ? "cached-related-\(UUID().uuidString.prefix(8))" : key.objectId,
                context: ActionContext(
                    userId: "system",
                    sessionId: "warming-\(UUID().uuidString.prefix(8))",
                    timestamp: Date(),
                    environment: .production,
                    metadata: ["warming": "related"]
                )
            ))
        }

        // Related by action type
        if key.actionType == ActionType.generate.rawValue {
            related.append(ObjectAction(
                id: UUID(),
                type: .analyze,
                objectType: ObjectType(rawValue: key.objectType) ?? .document,
                objectId: "cached-related-\(UUID().uuidString.prefix(8))",
                context: ActionContext(
                    userId: "system",
                    sessionId: "warming-\(UUID().uuidString.prefix(8))",
                    timestamp: Date(),
                    environment: .production,
                    metadata: ["warming": "related"]
                )
            ))
        }

        return related
    }
}

// MARK: - Supporting Types

private struct CachePredictedAction {
    let action: ObjectAction
    let confidence: Double
    let reason: String
}

private struct TrendingAction {
    let action: ObjectAction
    let score: Double
    let accessCount: Int
}

public struct WarmingMetrics: Sendable {
    private var totalWarmed: Int = 0
    private var successfulWarmed: Int = 0
    private var failedWarmed: Int = 0
    private var totalDuration: TimeInterval = 0
    private var strategyMetrics: [String: StrategyMetric] = [:]

    struct StrategyMetric: Sendable {
        var executions: Int = 0
        var totalDuration: TimeInterval = 0
        var lastExecution: Date?
    }

    public var successRate: Double {
        totalWarmed > 0 ? Double(successfulWarmed) / Double(totalWarmed) : 0
    }

    public var averageDuration: TimeInterval {
        totalWarmed > 0 ? totalDuration / Double(totalWarmed) : 0
    }

    mutating func recordSuccess() {
        totalWarmed += 1
        successfulWarmed += 1
    }

    mutating func recordFailure() {
        totalWarmed += 1
        failedWarmed += 1
    }

    mutating func recordWarming(strategy: String, duration: TimeInterval) {
        totalDuration += duration

        var metric = strategyMetrics[strategy] ?? StrategyMetric()
        metric.executions += 1
        metric.totalDuration += duration
        metric.lastExecution = Date()
        strategyMetrics[strategy] = metric
    }
}

// MARK: - Errors

enum CacheWarmingError: Error {
    case timeout
    case strategyFailed(String)
    case noDataAvailable
}

// MARK: - Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Cache Extension

extension ObjectActionCache {
    func getRecentlyAccessedKeys(limit _: Int) async -> [CacheKey] {
        // This would be implemented to track recent access
        // For now, return empty
        []
    }
}

// MARK: - Dependency Registration

extension CacheWarmingStrategy: DependencyKey {
    public static var liveValue: CacheWarmingStrategy {
        @Dependency(\.objectActionCache) var cache
        @Dependency(\.optimizedObjectActionHandler) var handler

        return CacheWarmingStrategy(
            cache: cache,
            objectActionHandler: handler
        )
    }
}

public extension DependencyValues {
    var cacheWarmingStrategy: CacheWarmingStrategy {
        get { self[CacheWarmingStrategy.self] }
        set { self[CacheWarmingStrategy.self] = newValue }
    }
}
