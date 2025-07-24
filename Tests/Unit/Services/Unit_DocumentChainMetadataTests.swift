@testable import AppCore
import CoreData
import XCTest

@MainActor
final class DocumentChainMetadataTests: XCTestCase {
    // MARK: - Test Metrics

    struct TestMetrics {
        var mop: Double = 0.0 // Measure of Performance
        var moe: Double = 0.0 // Measure of Effectiveness

        var overallScore: Double { (mop + moe) / 2.0 }
        var passed: Bool { overallScore >= 0.8 }
    }

    var context: NSManagedObjectContext?

    private var contextUnwrapped: NSManagedObjectContext {
        guard let context else { fatalError("context not initialized") }
        return context
    }

    override func setUp() async throws {
        try await super.setUp()
        context = CoreDataStack.shared.viewContext
    }

    // MARK: - Unit Tests

    func testDocumentChainStorage() async throws {
        var metrics = TestMetrics()

        // Create test acquisition
        let acquisition = CoreDataAcquisition(context: contextUnwrapped)
        acquisition.id = UUID()
        acquisition.title = "Test Acquisition"
        acquisition.createdDate = Date()

        // Create test document chain
        let testChain = DocumentChain(
            currentDocumentID: UUID(),
            previousVersionID: nil,
            documentType: .requirementsDocument,
            generatedAt: Date(),
            metadata: ["test": "value"]
        )

        let startTime = Date()

        do {
            // Test storage
            try acquisition.setDocumentChainCodable(testChain)
            let endTime = Date()

            // MOP: Storage speed
            let timeTaken = endTime.timeIntervalSince(startTime)
            metrics.mop = timeTaken < 0.1 ? 1.0 : max(0, 1.0 - timeTaken * 10)

            // MOE: Verify retrieval
            if let retrieved: DocumentChain = acquisition.getDocumentChainCodable() {
                let dataMatches = retrieved.currentDocumentID == testChain.currentDocumentID &&
                    retrieved.documentType == testChain.documentType
                metrics.moe = dataMatches ? 1.0 : 0.5
            } else {
                metrics.moe = 0.0
            }

            XCTAssertTrue(metrics.passed, "Document chain storage failed with score: \(metrics.overallScore)")
            print(" Chain Storage - MOP: \(metrics.mop), MOE: \(metrics.moe), Score: \(metrics.overallScore)")

        } catch {
            XCTFail("Storage failed: \(error)")
        }
    }

    func testDocumentChainCodable() async throws {
        var metrics = TestMetrics()

        // Create complex document chain
        var chains: [DocumentType: [DocumentChain]] = [:]
        chains[.requirementsDocument] = [
            DocumentChain(
                currentDocumentID: UUID(),
                previousVersionID: nil,
                documentType: .requirementsDocument,
                generatedAt: Date()
            ),
        ]
        chains[.performanceWorkStatement] = [
            DocumentChain(
                currentDocumentID: UUID(),
                previousVersionID: UUID(),
                documentType: .performanceWorkStatement,
                generatedAt: Date(),
                metadata: ["version": "2.0"]
            ),
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let startTime = Date()

        do {
            // Test encoding
            let encoded = try encoder.encode(chains)
            let endTime = Date()

            // MOP: Encoding performance
            let encodingTime = endTime.timeIntervalSince(startTime)
            metrics.mop = encodingTime < 0.05 ? 1.0 : max(0, 1.0 - encodingTime * 20)

            // Test decoding
            let decoded = try decoder.decode([DocumentType: [DocumentChain]].self, from: encoded)

            // MOE: Data integrity
            let chainsMatch = decoded.count == chains.count &&
                decoded[.requirementsDocument]?.count == 1 &&
                decoded[.performanceWorkStatement]?.count == 1
            metrics.moe = chainsMatch ? 1.0 : 0.0

            XCTAssertTrue(metrics.passed, "Codable test failed with score: \(metrics.overallScore)")
            print(" Chain Codable - MOP: \(metrics.mop), MOE: \(metrics.moe), Score: \(metrics.overallScore)")

        } catch {
            XCTFail("Codable test failed: \(error)")
        }
    }

    func testDocumentChainManagerIntegration() async throws {
        var metrics = TestMetrics()

        let manager = DocumentChainManager()
        let acquisitionID = UUID()
        let documentID = UUID()

        // Create test chain
        let chain = DocumentChain(
            currentDocumentID: documentID,
            previousVersionID: nil,
            documentType: .statementOfWork,
            generatedAt: Date()
        )

        let startTime = Date()

        // Test adding chain
        manager.addDocumentToChain(
            acquisitionID: acquisitionID.uuidString,
            documentID: documentID.uuidString,
            documentType: .statementOfWork,
            previousVersionID: nil
        )

        // Test persistence
        do {
            try await manager.persistChainsToCoreData()
            let endTime = Date()

            // MOP: Persistence speed
            let persistTime = endTime.timeIntervalSince(startTime)
            metrics.mop = persistTime < 0.5 ? 1.0 : max(0, 1.0 - persistTime * 2)

            // MOE: Verify chain retrieval
            let chains = manager.getDocumentChain(for: acquisitionID.uuidString, documentType: .statementOfWork)
            metrics.moe = chains.isEmpty ? 0.0 : 1.0

            XCTAssertTrue(metrics.passed, "Manager integration failed with score: \(metrics.overallScore)")
            print(" Manager Integration - MOP: \(metrics.mop), MOE: \(metrics.moe), Score: \(metrics.overallScore)")

        } catch {
            XCTFail("Manager test failed: \(error)")
        }
    }

    // MARK: - Performance Tests

    func testLargeChainPerformance() async throws {
        var metrics = TestMetrics()

        let acquisition = CoreDataAcquisition(context: contextUnwrapped)
        acquisition.id = UUID()
        acquisition.title = "Performance Test"

        // Create large chain with many versions
        var chains: [DocumentType: [DocumentChain]] = [:]
        let documentTypes: [DocumentType] = [.requirementsDocument, .statementOfWork, .performanceWorkStatement]

        for docType in documentTypes {
            var typeChains: [DocumentChain] = []
            var previousID: UUID?

            // Create 50 versions
            for i in 0 ..< 50 {
                let chain = DocumentChain(
                    currentDocumentID: UUID(),
                    previousVersionID: previousID,
                    documentType: docType,
                    generatedAt: Date(),
                    metadata: ["version": "\(i + 1)"]
                )
                typeChains.append(chain)
                previousID = chain.currentDocumentID
            }
            chains[docType] = typeChains
        }

        let startTime = Date()

        do {
            // Test storing large chain
            try acquisition.setDocumentChainCodable(chains)
            let storeEndTime = Date()

            // Test retrieving large chain
            let retrieved: [DocumentType: [DocumentChain]]? = acquisition.getDocumentChainCodable()
            let retrieveEndTime = Date()

            // MOP: Combined storage and retrieval performance
            let totalTime = retrieveEndTime.timeIntervalSince(startTime)
            metrics.mop = totalTime < 1.0 ? 1.0 : max(0, 1.0 - (totalTime - 1.0) / 2.0)

            // MOE: Data completeness
            if let retrieved {
                let totalStored = chains.values.reduce(0) { $0 + $1.count }
                let totalRetrieved = retrieved.values.reduce(0) { $0 + $1.count }
                metrics.moe = totalStored == totalRetrieved ? 1.0 : Double(totalRetrieved) / Double(totalStored)
            } else {
                metrics.moe = 0.0
            }

            XCTAssertTrue(metrics.passed, "Large chain performance failed with score: \(metrics.overallScore)")
            print(" Large Chain Performance - MOP: \(metrics.mop), MOE: \(metrics.moe), Score: \(metrics.overallScore)")

        } catch {
            XCTFail("Performance test failed: \(error)")
        }
    }
}
