@testable import AppCore
import ComposableArchitecture
import XCTest

/// Comprehensive performance testing suite for AIKO-IOS
@MainActor
final class PerformanceTestSuite: XCTestCase {
    // MARK: - Configuration

    private let standardIterations = 10
    private let stressIterations = 100
    private let largeDataSetSize = 1000

    override func setUp() async throws {
        try await super.setUp()
        // Warm up caches and services
        _ = AdaptiveDocumentCache()
        _ = UnifiedDocumentCacheService()
    }

    // MARK: - Memory Management Performance Tests

    func testMemoryPoolAllocatorPerformance() throws {
        let allocator = MemoryPoolAllocator(poolSize: 100, bufferSize: 1024 * 1024)

        measure(metrics: [XCTMemoryMetric(), XCTClockMetric()]) {
            for _ in 0 ..< standardIterations {
                // Allocate and deallocate buffers
                var buffers: [MemoryPoolAllocator.BufferHandle] = []

                for _ in 0 ..< 50 {
                    if let buffer = allocator.allocate() {
                        buffers.append(buffer)
                    }
                }

                // Random deallocations
                buffers.shuffle()
                for buffer in buffers {
                    allocator.deallocate(buffer)
                }
            }
        }
    }

    func testAsyncMemoryPoolPerformance() async throws {
        let pool = AsyncMemoryPool<Data>()

        let metrics = XCTMeasureOptions()
        metrics.iterationCount = 5

        measure(options: metrics) {
            let expectation = self.expectation(description: "Async operations")

            Task {
                // Concurrent allocations
                await withTaskGroup(of: Void.self) { group in
                    for index in 0 ..< 100 {
                        group.addTask {
                            let data = Data(repeating: UInt8(index), count: 1024)
                            await pool.store(data, for: "\(index)")
                        }
                    }
                }

                // Concurrent retrievals
                await withTaskGroup(of: Data?.self) { group in
                    for index in 0 ..< 100 {
                        group.addTask {
                            await pool.retrieve(for: "\(index)")
                        }
                    }

                    for await _ in group {
                        // Process results
                    }
                }

                await pool.clear()
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)
        }
    }

    // MARK: - Document Cache Performance Tests

    func testAdaptiveCachePerformance() async throws {
        let cache = AdaptiveDocumentCache(
            baseCacheSize: 500,
            baseMemorySize: 100 * 1024 * 1024
        )

        // Prepare test documents
        let documents = (0 ..< largeDataSetSize).map { documentIndex in
            CachedDocument(
                id: UUID(),
                data: Data(repeating: UInt8(documentIndex % 256), count: 1024),
                metadata: DocumentMetadata(
                    title: "Document \(documentIndex)",
                    size: 1024,
                    mimeType: "text/plain",
                    createdAt: Date(),
                    lastAccessedAt: Date()
                )
            )
        }

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = self.expectation(description: "Cache operations")

            Task {
                // Store documents
                for document in documents.prefix(500) {
                    try? await cache.store(document: document)
                }

                // Random access pattern
                for _ in 0 ..< 1000 {
                    let randomIndex = Int.random(in: 0 ..< documents.count)
                    _ = try? await cache.retrieve(id: documents[randomIndex].id)
                }

                // Clear and repeat
                await cache.clear()
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 30.0)
        }
    }

    func testCacheEvictionPerformance() async throws {
        let cache = AdaptiveDocumentCache(
            baseCacheSize: 100,
            baseMemorySize: 10 * 1024 * 1024
        )

        measure(metrics: [XCTClockMetric()]) {
            let expectation = self.expectation(description: "Eviction performance")

            Task {
                // Fill cache beyond capacity
                for documentIndex in 0 ..< 200 {
                    let document = CachedDocument(
                        id: UUID(),
                        data: Data(repeating: UInt8(documentIndex), count: 100 * 1024), // 100KB each
                        metadata: DocumentMetadata(
                            title: "Large Document \(documentIndex)",
                            size: 100 * 1024,
                            mimeType: "application/octet-stream",
                            createdAt: Date().addingTimeInterval(TimeInterval(documentIndex)),
                            lastAccessedAt: Date().addingTimeInterval(TimeInterval(documentIndex))
                        )
                    )
                    try? await cache.store(document: document)
                }

                // Verify eviction occurred
                let metrics = await cache.getMetrics()
                XCTAssertGreaterThan(metrics.totalEvictions, 0)

                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)
        }
    }

    // MARK: - API Optimization Performance Tests

    func testBatchedAPIRequestPerformance() async throws {
        let optimizer = OptimizedLLMService()

        // Create test prompts
        let prompts = (0 ..< 100).map { promptIndex in
            LLMRequest(
                id: UUID(),
                prompt: "Test prompt \(promptIndex)",
                model: "claude-3-opus",
                maxTokens: 100,
                temperature: 0.7,
                metadata: ["index": promptIndex]
            )
        }

        measure(metrics: [XCTClockMetric()]) {
            let expectation = self.expectation(description: "Batch processing")

            Task {
                // Process in batches
                let batchSize = 10
                for batchStartIndex in stride(from: 0, to: prompts.count, by: batchSize) {
                    let batch = Array(prompts[batchStartIndex ..< min(batchStartIndex + batchSize, prompts.count)])
                    _ = await optimizer.processBatch(batch)
                }

                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 20.0)
        }
    }

    func testResponseCachePerformance() async throws {
        let cache = LLMResponseCache()

        // Generate test responses
        let responses = (0 ..< 500).map { responseIndex in
            CachedLLMResponse(
                requestHash: "hash_\(responseIndex)",
                response: "Response content \(responseIndex)",
                model: "claude-3-opus",
                timestamp: Date(),
                tokenCount: 50
            )
        }

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = self.expectation(description: "Cache operations")

            Task {
                // Store responses
                for response in responses {
                    await cache.store(response)
                }

                // Retrieve with various hit rates
                var hits = 0
                var misses = 0

                for _ in 0 ..< 1000 {
                    let shouldHit = Int.random(in: 0 ..< 100) < 80 // 80% hit rate
                    let hash = if shouldHit {
                        "hash_\(Int.random(in: 0 ..< responses.count))"
                    } else {
                        "miss_\(Int.random(in: 1000 ..< 2000))"
                    }

                    if await cache.retrieve(for: hash) != nil {
                        hits += 1
                    } else {
                        misses += 1
                    }
                }

                XCTAssertGreaterThan(hits, misses)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)
        }
    }

    // MARK: - Service Layer Performance Tests

    func testUnifiedServicePerformance() async throws {
        let service = UnifiedDocumentCacheService()

        // Configure for performance testing
        let config = CacheConfiguration(
            mode: .adaptive,
            encryptionEnabled: false,
            adaptiveSizingEnabled: true,
            maxCacheSize: 1000,
            maxMemorySize: 200 * 1024 * 1024
        )

        try await service.updateConfiguration(config)

        measure(metrics: [XCTClockMetric()]) {
            let expectation = self.expectation(description: "Service operations")

            Task {
                // Mixed operations
                let documents = (0 ..< 200).map { documentIndex in
                    CachedDocument(
                        id: UUID(),
                        data: Data("Content \(documentIndex)".utf8),
                        metadata: DocumentMetadata(
                            title: "Doc \(documentIndex)",
                            size: 100,
                            mimeType: "text/plain",
                            createdAt: Date(),
                            lastAccessedAt: Date()
                        )
                    )
                }

                // Batch store
                try await service.batchStore(documents: documents)

                // Random operations
                for _ in 0 ..< 500 {
                    let operation = Int.random(in: 0 ..< 4)

                    switch operation {
                    case 0: // Retrieve
                        guard let randomDocument = documents.randomElement() else {
                            continue // Skip this iteration if no documents available
                        }
                        let id = randomDocument.id
                        _ = try await service.retrieve(id: id)
                    case 1: // List
                        _ = await service.listDocuments()
                    case 2: // Count
                        _ = await service.count()
                    case 3: // Statistics
                        _ = await service.statistics()
                    default:
                        break
                    }
                }

                await service.clear()
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 15.0)
        }
    }

    // MARK: - TCA Reducer Performance Tests

    func testReducerCompositionPerformance() async throws {
        let store = TestStore(
            initialState: OptimizedAppFeature.State()
        ) {
            OptimizedAppFeature()
        }

        measure(metrics: [XCTClockMetric()]) {
            let expectation = self.expectation(description: "Reducer actions")

            Task {
                // Simulate user interactions
                for actionIndex in 0 ..< 100 {
                    let action = actionIndex % 5

                    switch action {
                    case 0:
                        await store.send(.navigation(.navigate(to: .profile)))
                    case 1:
                        await store.send(.authentication(.authenticate))
                    case 2:
                        await store.send(.share(.selectDocument(UUID())))
                    case 3:
                        await store.send(.navigation(.toggleMenu(true)))
                    case 4:
                        await store.send(.navigation(.toggleMenu(false)))
                    default:
                        break
                    }
                }

                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)
        }
    }

    // MARK: - Encryption Performance Tests

    func testDocumentEncryptionPerformance() async throws {
        let encryptionService = DocumentEncryptionService()

        // Create test documents of various sizes
        let documents = [
            Data(repeating: 0, count: 1024), // 1KB
            Data(repeating: 0, count: 10 * 1024), // 10KB
            Data(repeating: 0, count: 100 * 1024), // 100KB
            Data(repeating: 0, count: 1024 * 1024), // 1MB
        ]

        for (index, documentData) in documents.enumerated() {
            let size = documentData.count / 1024

            measure(metrics: [XCTClockMetric()]) {
                let expectation = self.expectation(description: "Encryption \(size)KB")

                Task {
                    for _ in 0 ..< standardIterations {
                        // Encrypt
                        let encrypted = try await encryptionService.encrypt(documentData)

                        // Decrypt
                        let decrypted = try await encryptionService.decrypt(encrypted)

                        XCTAssertEqual(documentData, decrypted)
                    }

                    expectation.fulfill()
                }

                wait(for: [expectation], timeout: 30.0)
            }
        }
    }

    // MARK: - Template Service Performance Tests

    func testTemplateSearchPerformance() async throws {
        let service = UnifiedTemplateService()

        measure(metrics: [XCTClockMetric()]) {
            let expectation = self.expectation(description: "Template search")

            Task {
                // Search with various queries
                let queries = [
                    "contract",
                    "performance work statement",
                    "evaluation",
                    "far compliant",
                    "template",
                ]

                for query in queries {
                    _ = try await service.searchTemplates(
                        query: query,
                        in: TemplateSource.allCases
                    )
                }

                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)
        }
    }

    // MARK: - Stress Tests

    func testConcurrentAccessStress() async throws {
        let cache = AdaptiveDocumentCache()
        let concurrentTasks = 50

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = self.expectation(description: "Concurrent stress")

            Task {
                await withTaskGroup(of: Void.self) { group in
                    // Concurrent writes
                    for taskIndex in 0 ..< concurrentTasks {
                        group.addTask {
                            let document = CachedDocument(
                                id: UUID(),
                                data: Data("Concurrent \(taskIndex)".utf8),
                                metadata: DocumentMetadata(
                                    title: "Concurrent \(taskIndex)",
                                    size: 100,
                                    mimeType: "text/plain",
                                    createdAt: Date(),
                                    lastAccessedAt: Date()
                                )
                            )
                            try? await cache.store(document: document)
                        }
                    }

                    // Concurrent reads
                    for _ in 0 ..< concurrentTasks {
                        group.addTask {
                            _ = await cache.getAllDocuments()
                        }
                    }
                }

                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 30.0)
        }
    }

    // MARK: - Memory Pressure Tests

    func testMemoryPressureHandling() async throws {
        let cache = AdaptiveDocumentCache(
            baseCacheSize: 1000,
            baseMemorySize: 50 * 1024 * 1024 // 50MB
        )

        measure(metrics: [XCTMemoryMetric()]) {
            let expectation = self.expectation(description: "Memory pressure")

            Task {
                // Fill memory aggressively
                for memoryTestIndex in 0 ..< 1000 {
                    autoreleasepool {
                        let largeData = Data(repeating: UInt8(memoryTestIndex % 256), count: 100 * 1024) // 100KB each
                        let document = CachedDocument(
                            id: UUID(),
                            data: largeData,
                            metadata: DocumentMetadata(
                                title: "Large \(memoryTestIndex)",
                                size: Int64(largeData.count),
                                mimeType: "application/octet-stream",
                                createdAt: Date(),
                                lastAccessedAt: Date()
                            )
                        )

                        Task {
                            try? await cache.store(document: document)
                        }
                    }

                    // Allow memory pressure to trigger
                    if memoryTestIndex % 100 == 0 {
                        await cache.adjustCacheLimits()
                    }
                }

                // Verify adaptive behavior
                let finalSize = cache.currentMaxCacheSize
                XCTAssertLessThan(finalSize, 1000) // Should have reduced size

                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 60.0)
        }
    }
}

// MARK: - Performance Baseline Tests

extension PerformanceTestSuite {
    /// Establishes performance baselines for critical operations
    func testEstablishBaselines() async throws {
        var baselines: [String: Double] = [:]

        // Document store baseline
        let storeBaseline = await measureAsync {
            let cache = AdaptiveDocumentCache()
            let document = CachedDocument(
                id: UUID(),
                data: Data("Baseline content".utf8),
                metadata: DocumentMetadata(
                    title: "Baseline",
                    size: 16,
                    mimeType: "text/plain",
                    createdAt: Date(),
                    lastAccessedAt: Date()
                )
            )
            try? await cache.store(document: document)
        }
        baselines["document_store"] = storeBaseline

        // Document retrieve baseline
        let retrieveBaseline = await measureAsync {
            let cache = AdaptiveDocumentCache()
            let id = UUID()
            _ = try? await cache.retrieve(id: id)
        }
        baselines["document_retrieve"] = retrieveBaseline

        // API request baseline
        let apiBaseline = await measureAsync {
            let request = LLMRequest(
                id: UUID(),
                prompt: "Test",
                model: "claude-3-opus",
                maxTokens: 100,
                temperature: 0.7,
                metadata: [:]
            )
            // Simulate processing
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
        baselines["api_request"] = apiBaseline

        // Log baselines
        for (operation, time) in baselines {
            print("Performance baseline - \(operation): \(String(format: "%.3f", time * 1000))ms")
        }

        // Store baselines for regression testing
        UserDefaults.standard.set(baselines, forKey: "performance_baselines")
    }

    private func measureAsync(_ block: @escaping () async throws -> Void) async -> Double {
        let start = CFAbsoluteTimeGetCurrent()
        try? await block()
        return CFAbsoluteTimeGetCurrent() - start
    }
}

// MARK: - Mock Types

private struct CachedLLMResponse {
    let requestHash: String
    let response: String
    let model: String
    let timestamp: Date
    let tokenCount: Int
}

private actor LLMResponseCache {
    private var cache: [String: CachedLLMResponse] = [:]

    func store(_ response: CachedLLMResponse) {
        cache[response.requestHash] = response
    }

    func retrieve(for hash: String) -> CachedLLMResponse? {
        cache[hash]
    }
}
