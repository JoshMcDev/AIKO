@testable import AppCore
import ComposableArchitecture
import XCTest

@MainActor
final class UnifiedDocumentCacheServiceTests: XCTestCase {
    var service: UnifiedDocumentCacheService?

    private var serviceUnwrapped: UnifiedDocumentCacheService {
        guard let service else { fatalError("service not initialized") }
        return service
    }

    override func setUp() async throws {
        try await super.setUp()
        service = UnifiedDocumentCacheService()
    }

    override func tearDown() async throws {
        await serviceUnwrapped.clear()
        service = nil
        try await super.tearDown()
    }

    // MARK: - Configuration Tests

    func testDefaultConfiguration() async {
        let config = await serviceUnwrapped.currentConfiguration()
        XCTAssertEqual(config.mode, .standard)
        XCTAssertFalse(config.encryptionEnabled)
        XCTAssertFalse(config.adaptiveSizingEnabled)
        XCTAssertEqual(config.maxCacheSize, 50)
        XCTAssertEqual(config.maxMemorySize, 100 * 1024 * 1024)
    }

    func testConfigurationUpdate() async throws {
        let newConfig = CacheConfiguration(
            mode: .encrypted,
            encryptionEnabled: true,
            adaptiveSizingEnabled: true,
            maxCacheSize: 100,
            maxMemorySize: 200 * 1024 * 1024
        )

        try await serviceUnwrapped.updateConfiguration(newConfig)

        let currentConfig = await serviceUnwrapped.currentConfiguration()
        XCTAssertEqual(currentConfig, newConfig)
    }

    func testCacheModeTransitions() async throws {
        // Standard mode
        let standardDoc = CachedDocument(
            id: UUID(),
            data: Data("Standard content".utf8),
            metadata: DocumentMetadata(
                title: "Standard Doc",
                size: 16,
                mimeType: "text/plain",
                createdAt: Date(),
                lastAccessedAt: Date()
            )
        )

        try await serviceUnwrapped.store(document: standardDoc)
        var retrieved = try await serviceUnwrapped.retrieve(id: standardDoc.id)
        XCTAssertNotNil(retrieved)

        // Switch to encrypted mode
        let encryptedConfig = CacheConfiguration(
            mode: .encrypted,
            encryptionEnabled: true,
            adaptiveSizingEnabled: false,
            maxCacheSize: 50,
            maxMemorySize: 100 * 1024 * 1024
        )

        try await serviceUnwrapped.updateConfiguration(encryptedConfig)

        // Store encrypted document
        let encryptedDoc = CachedDocument(
            id: UUID(),
            data: Data("Encrypted content".utf8),
            metadata: DocumentMetadata(
                title: "Encrypted Doc",
                size: 18,
                mimeType: "text/plain",
                createdAt: Date(),
                lastAccessedAt: Date()
            )
        )

        try await serviceUnwrapped.store(document: encryptedDoc)
        retrieved = try await serviceUnwrapped.retrieve(id: encryptedDoc.id)
        XCTAssertNotNil(retrieved)

        // Previous document might not be accessible after mode switch
        // depending on implementation
    }

    // MARK: - Storage Tests

    func testBasicStorageOperations() async throws {
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

        // Store
        try await serviceUnwrapped.store(document: document)
        let count = await serviceUnwrapped.count()
        XCTAssertEqual(count, 1)

        // Retrieve
        let retrieved = try await serviceUnwrapped.retrieve(id: document.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, document.id)

        // List
        let allDocs = await serviceUnwrapped.listDocuments()
        XCTAssertEqual(allDocs.count, 1)
        XCTAssertEqual(allDocs.first?.id, document.id)

        // Remove
        try await serviceUnwrapped.remove(id: document.id)
        let countAfterRemove = await serviceUnwrapped.count()
        XCTAssertEqual(countAfterRemove, 0)
    }

    func testBatchOperations() async throws {
        let documents = (0 ..< 10).map { i in
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

        // Batch store
        try await serviceUnwrapped.batchStore(documents: documents)
        let count = await serviceUnwrapped.count()
        XCTAssertEqual(count, 10)

        // Batch retrieve
        let ids = documents.map(\.id)
        let retrieved = await serviceUnwrapped.batchRetrieve(ids: ids)
        XCTAssertEqual(retrieved.count, 10)

        // Clear
        await serviceUnwrapped.clear()
        let isEmpty = await serviceUnwrapped.isEmpty()
        XCTAssertTrue(isEmpty)
    }

    // MARK: - Statistics Tests

    func testCacheStatistics() async throws {
        let documents = (0 ..< 5).map { i in
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

        // Store documents
        try await serviceUnwrapped.batchStore(documents: documents)

        // Perform some retrievals
        for _ in 0 ..< 3 {
            _ = try await serviceUnwrapped.retrieve(id: documents[0].id)
        }
        _ = try await serviceUnwrapped.retrieve(id: documents[1].id)
        _ = try await serviceUnwrapped.retrieve(id: UUID()) // Miss

        let stats = await serviceUnwrapped.statistics()
        XCTAssertEqual(stats.totalDocuments, 5)
        XCTAssertEqual(stats.cacheHits, 4)
        XCTAssertEqual(stats.cacheMisses, 1)
        XCTAssertEqual(stats.hitRate, 0.8, accuracy: 0.01)
    }

    // MARK: - Encryption Mode Tests

    func testEncryptionMode() async throws {
        // Enable encryption
        let encryptedConfig = CacheConfiguration(
            mode: .encrypted,
            encryptionEnabled: true,
            adaptiveSizingEnabled: false,
            maxCacheSize: 50,
            maxMemorySize: 100 * 1024 * 1024
        )

        try await serviceUnwrapped.updateConfiguration(encryptedConfig)

        let sensitiveData = "Sensitive information"
        let document = CachedDocument(
            id: UUID(),
            data: Data(sensitiveData.utf8),
            metadata: DocumentMetadata(
                title: "Sensitive Document",
                size: Int64(sensitiveData.count),
                mimeType: "text/plain",
                createdAt: Date(),
                lastAccessedAt: Date(),
                isEncrypted: true
            )
        )

        // Store encrypted
        try await serviceUnwrapped.store(document: document)

        // Retrieve and verify
        let retrieved = try await serviceUnwrapped.retrieve(id: document.id)
        XCTAssertNotNil(retrieved)

        guard let retrievedDocument = retrieved else {
            XCTFail("Failed to retrieve encrypted document - retrieved document is nil")
            return
        }

        XCTAssertEqual(String(data: retrievedDocument.data, encoding: .utf8), sensitiveData)
        XCTAssertTrue(retrievedDocument.metadata.isEncrypted ?? false)
    }

    // MARK: - Adaptive Mode Tests

    func testAdaptiveMode() async throws {
        // Enable adaptive sizing
        let adaptiveConfig = CacheConfiguration(
            mode: .adaptive,
            encryptionEnabled: false,
            adaptiveSizingEnabled: true,
            maxCacheSize: 100,
            maxMemorySize: 200 * 1024 * 1024
        )

        try await serviceUnwrapped.updateConfiguration(adaptiveConfig)

        // Store many documents to trigger adaptive behavior
        let documents = (0 ..< 50).map { i in
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

        try await serviceUnwrapped.batchStore(documents: documents)

        // Access some documents frequently
        for _ in 0 ..< 10 {
            _ = try await serviceUnwrapped.retrieve(id: documents[0].id)
            _ = try await serviceUnwrapped.retrieve(id: documents[1].id)
        }

        let stats = await serviceUnwrapped.statistics()
        XCTAssertGreaterThan(stats.totalMemoryUsage, 0)

        // The adaptive cache should maintain good performance
        XCTAssertGreaterThan(stats.hitRate, 0.5)
    }

    // MARK: - Error Handling Tests

    func testInvalidDocumentHandling() async throws {
        // Test storing document with empty data
        let emptyDoc = CachedDocument(
            id: UUID(),
            data: Data(),
            metadata: DocumentMetadata(
                title: "Empty Document",
                size: 0,
                mimeType: "text/plain",
                createdAt: Date(),
                lastAccessedAt: Date()
            )
        )

        // Should handle gracefully
        do {
            try await serviceUnwrapped.store(document: emptyDoc)
            let retrieved = try await serviceUnwrapped.retrieve(id: emptyDoc.id)
            XCTAssertNotNil(retrieved)
            XCTAssertEqual(retrieved?.data.count, 0)
        } catch {
            // Also acceptable if it rejects empty documents
            XCTAssertTrue(true)
        }
    }

    // MARK: - Performance Tests

    func testLargeScaleOperations() async throws {
        let measure = XCTMeasureOptions()
        measure.iterationCount = 3

        self.measure(options: measure) {
            let expectation = self.expectation(description: "Large scale operations")

            Task {
                // Store 1000 documents
                let documents = (0 ..< 1000).map { i in
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

                try await serviceUnwrapped.batchStore(documents: documents)

                // Random retrievals
                for _ in 0 ..< 100 {
                    let randomIndex = Int.random(in: 0 ..< documents.count)
                    _ = try await serviceUnwrapped.retrieve(id: documents[randomIndex].id)
                }

                await serviceUnwrapped.clear()
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)
        }
    }
}
