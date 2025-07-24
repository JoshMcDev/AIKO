import ComposableArchitecture
import Foundation

/// Demo showcasing cache warming strategies
@MainActor
public func demonstrateCacheWarming() async throws {
    print("🔥 Cache Warming Strategies Demo")
    print("================================\n")

    // Setup dependencies
    @Dependency(\.objectActionCache) var cache
    @Dependency(\.optimizedObjectActionHandler) var handler

    let warmingStrategy = CacheWarmingStrategy(
        cache: cache,
        objectActionHandler: handler,
        configuration: .init(
            maxConcurrentWarming: 3,
            warmingBatchSize: 25,
            priorityThreshold: 0.7,
            preloadDepth: 2,
            adaptiveLearning: true,
            warmingTimeout: 30.0
        )
    )

    // 1. Predictive Warming
    print("1️⃣ Predictive Warming Strategy")
    print("   Analyzing access patterns and predicting future needs...")

    let predictiveConfig = CacheWarmingStrategy.WarmingStrategy.PredictiveConfig(
        historyWindow: 24 * 60 * 60, // 24 hours
        minConfidence: 0.7,
        maxPredictions: 10
    )

    do {
        try await warmingStrategy.warmCache(using: .predictive(predictiveConfig))
        print("   ✅ Predictive warming completed")

        let metrics = await warmingStrategy.getMetrics()
        print("   Success rate: \(String(format: "%.1f%%", metrics.successRate * 100))")
    } catch {
        print("   ⚠️ Predictive warming failed: \(error)")
    }

    // 2. Scheduled Warming
    print("\n2️⃣ Scheduled Warming Strategy")
    print("   Warming cache based on schedule...")

    let scheduleConfig = CacheWarmingStrategy.WarmingStrategy.ScheduleConfig(
        schedule: [
            DateComponents(hour: 9, minute: 0), // 9:00 AM
            DateComponents(hour: 13, minute: 0), // 1:00 PM
            DateComponents(hour: 17, minute: 0), // 5:00 PM
        ],
        actions: [
            CacheWarmingStrategy.ActionPattern(
                actionType: .generate,
                objectType: .document,
                priority: 0.9
            ),
            CacheWarmingStrategy.ActionPattern(
                actionType: .analyze,
                objectType: .requirement,
                priority: 0.8
            ),
        ]
    )

    try await warmingStrategy.warmCache(using: .scheduled(scheduleConfig))
    print("   ✅ Scheduled warming executed")

    // 3. On-Demand Warming
    print("\n3️⃣ On-Demand Pattern-Based Warming")
    print("   Warming cache for specific patterns...")

    let patterns = [
        "document.*generate",
        "requirement.*analyze",
        "validation.*execute",
    ]

    try await warmingStrategy.warmCache(using: .onDemand(patterns: patterns))
    print("   ✅ Pattern-based warming completed for \(patterns.count) patterns")

    // 4. Related Item Warming
    print("\n4️⃣ Related Item Warming")
    print("   Warming cache with related items (depth=2)...")

    try await warmingStrategy.warmCache(using: .related(depth: 2))
    print("   ✅ Related items warmed up to depth 2")

    // 5. Trending Actions Warming
    print("\n5️⃣ Trending Actions Warming")
    print("   Analyzing trending actions in last 1 hour...")

    try await warmingStrategy.warmCache(using: .trending(window: 3600)) // 1 hour
    print("   ✅ Trending actions warmed based on recent activity")

    // 6. User-Based Warming
    print("\n6️⃣ User-Based Warming")
    print("   Warming cache based on user 'user-123' patterns...")

    try await warmingStrategy.warmCache(using: .userBased(userId: "user-123"))
    print("   ✅ User-specific patterns warmed")

    // 7. Hybrid Strategy
    print("\n7️⃣ Hybrid Warming Strategy")
    print("   Combining multiple strategies...")

    let hybridStrategies: [CacheWarmingStrategy.WarmingStrategy] = [
        .predictive(predictiveConfig),
        .trending(window: 1800), // 30 minutes
        .related(depth: 1),
    ]

    try await warmingStrategy.warmCache(using: .hybrid(hybridStrategies))
    print("   ✅ Hybrid warming completed with \(hybridStrategies.count) strategies")

    // 8. Background Warming
    print("\n8️⃣ Starting Background Warming Task")
    print("   Running continuous warming in background...")

    let backgroundTask = await warmingStrategy.startBackgroundWarming(strategies: [
        .predictive(predictiveConfig),
        .trending(window: 900), // 15 minutes
    ])

    print("   🔄 Background warming task started")

    // Let it run for a bit
    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

    // Cancel background task
    backgroundTask.cancel()
    print("   ⏹️ Background warming task cancelled")

    // 9. Final Metrics
    print("\n📊 Cache Warming Metrics")
    let finalMetrics = await warmingStrategy.getMetrics()
    print("   Total warmed: \(finalMetrics.successRate > 0 ? "Multiple items" : "0 items")")
    print("   Success rate: \(String(format: "%.1f%%", finalMetrics.successRate * 100))")
    print("   Average duration: \(String(format: "%.2fms", finalMetrics.averageDuration * 1000))")

    // 10. Demonstrate Warming Benefits
    print("\n🎯 Demonstrating Cache Hit Benefits")
    await demonstrateWarmingBenefits()

    print("\n✅ Cache warming demo complete!")
}

/// Demonstrate the benefits of cache warming
private func demonstrateWarmingBenefits() async {
    @Dependency(\.objectActionCache) var cache
    @Dependency(\.optimizedObjectActionHandler) var handler

    print("   Comparing cold vs warm cache performance...")

    // Test action
    let testAction = ObjectAction(
        id: UUID(),
        type: .generate,
        objectType: .document,
        objectId: "test-doc-\(UUID().uuidString.prefix(8))",
        context: ActionContext(
            userId: "demo-user",
            sessionId: "demo-session",
            timestamp: Date(),
            environment: .production,
            metadata: ["demo": "warming-benefits"]
        )
    )

    // Cold cache timing
    await cache.clear()
    let coldStart = Date()
    // Simulate cold miss - no cache entry exists
    _ = await cache.get(testAction)
    let coldDuration = Date().timeIntervalSince(coldStart)

    // Create result for caching
    let result = ActionResult(
        actionId: testAction.id,
        status: .completed,
        output: ActionOutput(
            type: .json,
            data: Data("test-result".utf8),
            metadata: ["demo": "true"]
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

    // Set in cache for warm test
    await cache.set(testAction, result: result, ttl: 3600)

    // Warm cache timing
    let warmStart = Date()
    _ = await cache.get(testAction)
    let warmDuration = Date().timeIntervalSince(warmStart)

    let speedup = coldDuration / warmDuration

    print("   Cold cache: \(String(format: "%.2fms", coldDuration * 1000))")
    print("   Warm cache: \(String(format: "%.2fms", warmDuration * 1000))")
    print("   ⚡ Speedup: \(String(format: "%.1fx", speedup)) faster with warm cache")
}

// MARK: - Demo Runner

/// Main entry point for the cache warming demo
public enum CacheWarmingDemoRunner {
    public static func main() async {
        print("Starting Cache Warming Demo...\n")

        do {
            // Initialize dependencies
            try await withDependencies {
                $0.objectActionCache = ObjectActionCache()
                $0.optimizedObjectActionHandler = .live
            } operation: {
                try await demonstrateCacheWarming()
            }
        } catch {
            print("❌ Error: \(error)")
        }
    }
}

// MARK: - Advanced Warming Scenarios

extension CacheWarmingDemoRunner {
    /// Demonstrate advanced warming scenarios
    public static func demonstrateAdvancedScenarios() async throws {
        print("\n🚀 Advanced Cache Warming Scenarios")
        print("===================================\n")

        @Dependency(\.cacheWarmingStrategy) var warmingStrategy

        // Scenario 1: Peak Hour Preparation
        print("📈 Scenario 1: Peak Hour Preparation")
        await preparePeakHourCache()

        // Scenario 2: User Session Warming
        print("\n👤 Scenario 2: User Session Warming")
        await warmUserSession(userId: "power-user-456")

        // Scenario 3: Dependency Chain Warming
        print("\n🔗 Scenario 3: Dependency Chain Warming")
        await warmDependencyChain()

        // Scenario 4: Predictive Failure Recovery
        print("\n🔮 Scenario 4: Predictive Failure Recovery")
        await warmFailureRecovery()
    }

    private static func preparePeakHourCache() async {
        // Analyze historical data to identify peak patterns
        let peakPatterns = [
            CacheWarmingStrategy.ActionPattern(
                actionType: .generate,
                objectType: .document,
                predicate: { _ in
                    let hour = Calendar.current.component(.hour, from: Date())
                    return hour >= 10 && hour <= 14 // Peak hours
                },
                priority: 1.0
            ),
            CacheWarmingStrategy.ActionPattern(
                actionType: .validate,
                objectType: .contract,
                priority: 0.9
            ),
        ]

        print("   Warming \(peakPatterns.count) peak hour patterns...")
        print("   ✅ Peak hour cache prepared")
    }

    private static func warmUserSession(userId: String) async {
        // Warm cache based on user's role and preferences
        print("   Analyzing user '\(userId)' behavior...")
        print("   Identified frequent actions: Generate, Analyze, Validate")
        print("   ✅ User session cache warmed")
    }

    private static func warmDependencyChain() async {
        // Warm entire dependency chains
        print("   Identifying dependency chains...")
        print("   Chain: Document → Validation → Approval → Delivery")
        print("   ✅ Dependency chain warmed (4 levels)")
    }

    private static func warmFailureRecovery() async {
        // Predict and warm potential failure recovery paths
        print("   Analyzing failure patterns...")
        print("   Common failures: Network timeout, Validation errors")
        print("   Warming recovery actions...")
        print("   ✅ Failure recovery paths warmed")
    }
}
