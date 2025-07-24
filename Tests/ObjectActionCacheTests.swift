@testable import AppCore
import XCTest

final class ObjectActionCacheTests: XCTestCase {
    func testMultiTierCaching() async throws {
        // Create cache instance
        let cache = ObjectActionCache()

        // Create test action
        let action = ObjectAction(
            type: .analyze,
            objectType: .document,
            objectId: "test-123",
            context: ActionContext(
                userId: "user1",
                sessionId: "session1"
            )
        )

        // Create test result
        let result = ActionResult(
            actionId: action.id,
            status: .completed,
            output: ActionOutput(
                type: .text,
                data: Data("Test output".utf8)
            ),
            metrics: ActionMetrics(
                startTime: Date(),
                endTime: Date().addingTimeInterval(1),
                cpuUsage: 0.5,
                memoryUsage: 0.3,
                successRate: 1.0,
                performanceScore: 0.9,
                effectivenessScore: 0.95
            )
        )

        // Test storing in cache
        await cache.set(action, result: result)

        // Test retrieving from cache
        let cachedResult = await cache.get(action)
        XCTAssertNotNil(cachedResult)
        XCTAssertEqual(cachedResult?.actionId, action.id)
        XCTAssertEqual(cachedResult?.status, .completed)

        // Test cache metrics
        let metrics = await cache.getMetrics()
        XCTAssertEqual(metrics.totalRequests, 1)
        XCTAssertGreaterThan(metrics.l1Hits + metrics.l2Hits + metrics.l3Hits, 0)

        // Test cache invalidation
        await cache.invalidate(pattern: "test-*")
        let invalidatedResult = await cache.get(action)
        XCTAssertNil(invalidatedResult)
    }

    func testCachePerformance() async throws {
        let cache = ObjectActionCache()

        // Measure performance of cache operations
        let start = Date()

        // Create multiple actions
        for i in 0 ..< 100 {
            let action = ObjectAction(
                type: .read,
                objectType: .document,
                objectId: "doc-\(i)",
                context: ActionContext(userId: "user1", sessionId: "session1")
            )

            let result = ActionResult(
                actionId: action.id,
                status: .completed,
                output: nil,
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

            await cache.set(action, result: result)
        }

        let writeTime = Date().timeIntervalSince(start)
        print("Write time for 100 items: \(writeTime)s")

        // Test read performance
        let readStart = Date()
        var hits = 0

        for i in 0 ..< 100 {
            let action = ObjectAction(
                type: .read,
                objectType: .document,
                objectId: "doc-\(i)",
                context: ActionContext(userId: "user1", sessionId: "session1")
            )

            if await cache.get(action) != nil {
                hits += 1
            }
        }

        let readTime = Date().timeIntervalSince(readStart)
        print("Read time for 100 items: \(readTime)s")
        print("Cache hit rate: \(Double(hits) / 100.0 * 100)%")

        let metrics = await cache.getMetrics()
        print("L1 Hit Rate: \(metrics.l1HitRate)%")
        print("L2 Hit Rate: \(metrics.l2HitRate)%")
        print("L3 Hit Rate: \(metrics.l3HitRate)%")

        XCTAssertEqual(hits, 100)
        XCTAssertLessThan(readTime, writeTime) // Reads should be faster than writes
    }
}
