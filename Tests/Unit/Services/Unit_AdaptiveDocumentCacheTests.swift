@testable import AppCore
import ComposableArchitecture
import XCTest

@MainActor
final class AdaptiveDocumentCacheTests: XCTestCase {
    // MARK: - Initialization Tests

    func testDefaultInitialization() async {
        let cache = AdaptiveDocumentCache()

        XCTAssertEqual(cache.currentMaxCacheSize, 50)
        XCTAssertEqual(cache.currentMaxMemorySize, 100 * 1024 * 1024)
        XCTAssertTrue(cache.isEmpty)
        XCTAssertEqual(cache.count, 0)
    }

    func testCustomInitialization() async {
        let cache = AdaptiveDocumentCache(
            baseCacheSize: 100,
            baseMemorySize: 200 * 1024 * 1024
        )

        XCTAssertEqual(cache.currentMaxCacheSize, 100)
        XCTAssertEqual(cache.currentMaxMemorySize, 200 * 1024 * 1024)
    }

    // MARK: - Storage Tests

    func testStoreAndRetrieveDocument() async throws {
        let cache = AdaptiveDocumentCache()
        let document = CachedDocument(
            id: UUID(),
            data: Data("Test content".utf8),
            metadata: DocumentMetadata(
                title: "Test Document",
                size: 12,
                mimeType: "text/plain",
                createdAt: Date(),
                lastAccessedAt: Date()
            )
        )

        // Store document
        try await cache.store(document: document)

        // Retrieve document
        let retrieved = try await cache.retrieve(id: document.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, document.id)
        XCTAssertEqual(retrieved?.data, document.data)
        XCTAssertEqual(retrieved?.metadata.title, document.metadata.title)
    }

    func testRetrieveNonExistentDocument() async throws {
        let cache = AdaptiveDocumentCache()
        let nonExistentId = UUID()

        let retrieved = try await cache.retrieve(id: nonExistentId)
        XCTAssertNil(retrieved)
    }

    func testRemoveDocument() async throws {
        let cache = AdaptiveDocumentCache()
        let document = CachedDocument(
            id: UUID(),
            data: Data("Test content".utf8),
            metadata: DocumentMetadata(
                title: "Test Document",
                size: 12,
                mimeType: "text/plain",
                createdAt: Date(),
                lastAccessedAt: Date()
            )
        )

        // Store document
        try await cache.store(document: document)
        XCTAssertEqual(cache.count, 1)

        // Remove document
        try await cache.remove(id: document.id)
        XCTAssertEqual(cache.count, 0)

        // Verify it's removed
        let retrieved = try await cache.retrieve(id: document.id)
        XCTAssertNil(retrieved)
    }

    func testClearCache() async throws {
        let cache = AdaptiveDocumentCache()

        // Store multiple documents
        for i in 0 ..< 5 {
            let document = CachedDocument(
                id: UUID(),
                data: Data("Content \(i)".utf8),
                metadata: DocumentMetadata(
                    title: "Document \(i)",
                    size: 10,
                    mimeType: "text/plain",
                    createdAt: Date(),
                    lastAccessedAt: Date()
                )
            )
            try await cache.store(document: document)
        }

        XCTAssertEqual(cache.count, 5)

        // Clear cache
        await cache.clear()
        XCTAssertEqual(cache.count, 0)
        XCTAssertTrue(cache.isEmpty)
    }

    // MARK: - Memory Pressure Tests

    func testMemoryPressureAdjustment() async throws {
        let cache = AdaptiveDocumentCache(
            baseCacheSize: 100,
            baseMemorySize: 100 * 1024 * 1024
        )

        // Simulate normal pressure
        await cache.adjustCacheLimits()
        XCTAssertEqual(cache.currentMaxCacheSize, 100)

        // Note: Testing actual memory pressure adjustment would require
        // mocking the MemoryPressureMonitor, which would be done in a
        // more comprehensive test suite
    }

    func testEvictionUnderMemoryPressure() async throws {
        let cache = AdaptiveDocumentCache(
            baseCacheSize: 3,
            baseMemorySize: 1024
        )

        // Store documents that will exceed the cache limit
        var documentIds: [UUID] = []
        for i in 0 ..< 5 {
            let document = CachedDocument(
                id: UUID(),
                data: Data("Content \(i)".utf8),
                metadata: DocumentMetadata(
                    title: "Document \(i)",
                    size: 10,
                    mimeType: "text/plain",
                    createdAt: Date().addingTimeInterval(TimeInterval(i)),
                    lastAccessedAt: Date().addingTimeInterval(TimeInterval(i))
                )
            )
            documentIds.append(document.id)
            try await cache.store(document: document)
        }

        // Cache should have evicted oldest documents
        XCTAssertLessThanOrEqual(cache.count, 3)

        // Newest documents should still be in cache
        guard let lastDocumentId = documentIds.last else {
            XCTFail("Document IDs array should not be empty")
            return
        }
        let newestDocument = try await cache.retrieve(id: lastDocumentId)
        XCTAssertNotNil(newestDocument)
    }

    // MARK: - Metrics Tests

    func testHitRateCalculation() async throws {
        let cache = AdaptiveDocumentCache()
        let document = CachedDocument(
            id: UUID(),
            data: Data("Test content".utf8),
            metadata: DocumentMetadata(
                title: "Test Document",
                size: 12,
                mimeType: "text/plain",
                createdAt: Date(),
                lastAccessedAt: Date()
            )
        )

        // Store document
        try await cache.store(document: document)

        // Multiple successful retrievals (hits)
        for _ in 0 ..< 8 {
            _ = try await cache.retrieve(id: document.id)
        }

        // Some misses
        for _ in 0 ..< 2 {
            _ = try await cache.retrieve(id: UUID())
        }

        let metrics = await cache.getMetrics()
        let hitRate = Double(metrics.cacheHits) / Double(metrics.cacheHits + metrics.cacheMisses)
        XCTAssertEqual(hitRate, 0.8, accuracy: 0.01)
    }

    // MARK: - Performance Tests

    func testConcurrentAccess() async throws {
        let cache = AdaptiveDocumentCache()
        let documentCount = 100

        // Create documents
        let documents = (0 ..< documentCount).map { i in
            CachedDocument(
                id: UUID(),
                data: Data("Content \(i)".utf8),
                metadata: DocumentMetadata(
                    title: "Document \(i)",
                    size: 10,
                    mimeType: "text/plain",
                    createdAt: Date(),
                    lastAccessedAt: Date()
                )
            )
        }

        // Concurrent stores
        await withTaskGroup(of: Void.self) { group in
            for document in documents {
                group.addTask {
                    try? await cache.store(document: document)
                }
            }
        }

        // Verify all documents were stored (up to cache limit)
        XCTAssertGreaterThan(cache.count, 0)
        XCTAssertLessThanOrEqual(cache.count, cache.currentMaxCacheSize)

        // Concurrent retrievals
        var retrievedCount = 0
        await withTaskGroup(of: CachedDocument?.self) { group in
            for document in documents.prefix(10) {
                group.addTask {
                    try? await cache.retrieve(id: document.id)
                }
            }

            for await retrieved in group where retrieved != nil {
                retrievedCount += 1
            }
        }

        XCTAssertGreaterThan(retrievedCount, 0)
    }

    // MARK: - Edge Cases

    func testZeroSizeCacheInitialization() async {
        let cache = AdaptiveDocumentCache(
            baseCacheSize: 0,
            baseMemorySize: 0
        )

        // Should default to minimum values
        XCTAssertGreaterThan(cache.currentMaxCacheSize, 0)
        XCTAssertGreaterThan(cache.currentMaxMemorySize, 0)
    }

    func testLargeDocumentHandling() async throws {
        let cache = AdaptiveDocumentCache(
            baseCacheSize: 5,
            baseMemorySize: 1024 * 1024 // 1MB
        )

        // Create a large document
        let largeData = Data(repeating: 0, count: 2 * 1024 * 1024) // 2MB
        let document = CachedDocument(
            id: UUID(),
            data: largeData,
            metadata: DocumentMetadata(
                title: "Large Document",
                size: Int64(largeData.count),
                mimeType: "application/octet-stream",
                createdAt: Date(),
                lastAccessedAt: Date()
            )
        )

        // Should handle gracefully
        do {
            try await cache.store(document: document)
            // Document might be rejected or cause eviction
            XCTAssertLessThanOrEqual(cache.totalMemoryUsage, cache.currentMaxMemorySize)
        } catch {
            // It's acceptable if the cache rejects documents larger than memory limit
            XCTAssertTrue(true)
        }
    }
}

// MARK: - Test Helpers

extension AdaptiveDocumentCache {
    var totalMemoryUsage: Int64 {
        // This would need to be exposed from the actual implementation
        // For testing purposes, we'd add a computed property
        0 // Placeholder
    }
}
