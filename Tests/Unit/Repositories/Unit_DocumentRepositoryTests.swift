@testable import AppCore
import CoreData
import XCTest

final class UnitDocumentRepositoryTests: XCTestCase {
    // MARK: - Properties

    private var sut: DocumentRepository?
    private var context: NSManagedObjectContext?

    private var sutUnwrapped: DocumentRepository {
        guard let sut else { fatalError("sut not initialized") }
        return sut
    }

    private var contextUnwrapped: NSManagedObjectContext {
        guard let context else { fatalError("context not initialized") }
        return context
    }

    // MARK: - Setup/Teardown

    override func setUp() {
        super.setUp()

        // Create in-memory Core Data stack
        let model = CoreDataStack.model
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try! coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)

        context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        contextUnwrapped.persistentStoreCoordinator = coordinator

        // Create repository
        sut = DocumentRepository(context: contextUnwrapped)
    }

    override func tearDown() {
        sut = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Save Tests

    func testSaveDocument_Success() async throws {
        // Given
        let acquisitionId = UUID()
        let fileName = "test-document.pdf"
        let data = Data("Test content".utf8)
        let contentSummary = "This is a test document"

        // When
        let savedDoc = try await sutUnwrapped.saveDocument(
            fileName: fileName,
            data: data,
            contentSummary: contentSummary,
            acquisitionId: acquisitionId
        )

        // Then
        XCTAssertNotNil(savedDoc)
        XCTAssertEqual(savedDoc.fileName, fileName)
        XCTAssertEqual(savedDoc.data, data)
        XCTAssertEqual(savedDoc.contentSummary, contentSummary)
        XCTAssertNotNil(savedDoc.id)
        XCTAssertNotNil(savedDoc.createdAt)

        // Verify persistence
        let request = NSFetchRequest<DocumentData>(entityName: "DocumentData")
        request.predicate = NSPredicate(format: "id == %@", savedDoc.id as CVarArg)
        let results = try contextUnwrapped.fetch(request)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.fileName, fileName)
    }

    func testSaveDocument_EmptyFileName_ThrowsError() async throws {
        // Given
        let acquisitionId = UUID()
        let fileName = ""
        let data = Data("Test content".utf8)

        // When/Then
        do {
            _ = try await sutUnwrapped.saveDocument(
                fileName: fileName,
                data: data,
                contentSummary: nil,
                acquisitionId: acquisitionId
            )
            XCTFail("Expected error for empty filename")
        } catch {
            XCTAssertTrue(error is DomainError)
        }
    }

    func testSaveDocument_EmptyData_ThrowsError() async throws {
        // Given
        let acquisitionId = UUID()
        let fileName = "test.pdf"
        let data = Data()

        // When/Then
        do {
            _ = try await sutUnwrapped.saveDocument(
                fileName: fileName,
                data: data,
                contentSummary: nil,
                acquisitionId: acquisitionId
            )
            XCTFail("Expected error for empty data")
        } catch {
            XCTAssertTrue(error is DomainError)
        }
    }

    // MARK: - Retrieval Tests

    func testGetDocument_ExistingDocument_Success() async throws {
        // Given
        let acquisitionId = UUID()
        let saved = try await sutUnwrapped.saveDocument(
            fileName: "test.pdf",
            data: Data("content".utf8),
            contentSummary: "Summary",
            acquisitionId: acquisitionId
        )

        // When
        let retrieved = try await sutUnwrapped.getDocument(id: saved.id)

        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, saved.id)
        XCTAssertEqual(retrieved?.fileName, saved.fileName)
        XCTAssertEqual(retrieved?.data, saved.data)
        XCTAssertEqual(retrieved?.contentSummary, saved.contentSummary)
    }

    func testGetDocument_NonExistentDocument_ReturnsNil() async throws {
        // Given
        let nonExistentId = UUID()

        // When
        let retrieved = try await sutUnwrapped.getDocument(id: nonExistentId)

        // Then
        XCTAssertNil(retrieved)
    }

    func testGetDocumentsForAcquisition_Success() async throws {
        // Given
        let acquisitionId = UUID()
        let doc1 = try await sutUnwrapped.saveDocument(
            fileName: "doc1.pdf",
            data: Data("content1".utf8),
            contentSummary: "Summary 1",
            acquisitionId: acquisitionId
        )
        let doc2 = try await sutUnwrapped.saveDocument(
            fileName: "doc2.docx",
            data: Data("content2".utf8),
            contentSummary: "Summary 2",
            acquisitionId: acquisitionId
        )

        // Different acquisition
        let otherAcquisitionId = UUID()
        _ = try await sutUnwrapped.saveDocument(
            fileName: "other.pdf",
            data: Data("other".utf8),
            contentSummary: nil,
            acquisitionId: otherAcquisitionId
        )

        // When
        let documents = try await sutUnwrapped.getDocumentsForAcquisition(id: acquisitionId)

        // Then
        XCTAssertEqual(documents.count, 2)
        let ids = documents.map(\.id)
        XCTAssertTrue(ids.contains(doc1.id))
        XCTAssertTrue(ids.contains(doc2.id))

        // Verify sorted by creation date (newest first)
        if documents.count == 2 {
            XCTAssertGreaterThanOrEqual(documents[0].createdAt, documents[1].createdAt)
        }
    }

    func testGetDocumentsForAcquisition_NoDocuments_ReturnsEmpty() async throws {
        // Given
        let acquisitionId = UUID()

        // When
        let documents = try await sutUnwrapped.getDocumentsForAcquisition(id: acquisitionId)

        // Then
        XCTAssertEqual(documents.count, 0)
    }

    // MARK: - Delete Tests

    func testDeleteDocument_Success() async throws {
        // Given
        let acquisitionId = UUID()
        let doc = try await sutUnwrapped.saveDocument(
            fileName: "to-delete.pdf",
            data: Data("content".utf8),
            contentSummary: nil,
            acquisitionId: acquisitionId
        )

        // When
        try await sutUnwrapped.deleteDocument(id: doc.id)

        // Then
        let retrieved = try await sutUnwrapped.getDocument(id: doc.id)
        XCTAssertNil(retrieved)

        // Verify deletion from Core Data
        let request = NSFetchRequest<DocumentData>(entityName: "DocumentData")
        request.predicate = NSPredicate(format: "id == %@", doc.id as CVarArg)
        let results = try contextUnwrapped.fetch(request)
        XCTAssertEqual(results.count, 0)
    }

    func testDeleteDocument_NonExistentDocument_ThrowsError() async throws {
        // Given
        let nonExistentId = UUID()

        // When/Then
        do {
            try await sutUnwrapped.deleteDocument(id: nonExistentId)
            XCTFail("Expected error for non-existent document")
        } catch {
            XCTAssertTrue(error is DomainError)
        }
    }

    func testDeleteAllDocumentsForAcquisition_Success() async throws {
        // Given
        let acquisitionId = UUID()
        _ = try await sutUnwrapped.saveDocument(
            fileName: "doc1.pdf",
            data: Data("content1".utf8),
            contentSummary: nil,
            acquisitionId: acquisitionId
        )
        _ = try await sutUnwrapped.saveDocument(
            fileName: "doc2.pdf",
            data: Data("content2".utf8),
            contentSummary: nil,
            acquisitionId: acquisitionId
        )

        // Different acquisition (should not be deleted)
        let otherAcquisitionId = UUID()
        let otherDoc = try await sutUnwrapped.saveDocument(
            fileName: "other.pdf",
            data: Data("other".utf8),
            contentSummary: nil,
            acquisitionId: otherAcquisitionId
        )

        // When
        try await sutUnwrapped.deleteAllDocumentsForAcquisition(id: acquisitionId)

        // Then
        let remaining = try await sutUnwrapped.getDocumentsForAcquisition(id: acquisitionId)
        XCTAssertEqual(remaining.count, 0)

        let otherRemaining = try await sutUnwrapped.getDocument(id: otherDoc.id)
        XCTAssertNotNil(otherRemaining)
    }

    // MARK: - Update Tests

    func testUpdateDocumentSummary_Success() async throws {
        // Given
        let acquisitionId = UUID()
        let doc = try await sutUnwrapped.saveDocument(
            fileName: "test.pdf",
            data: Data("content".utf8),
            contentSummary: "Original summary",
            acquisitionId: acquisitionId
        )
        let newSummary = "Updated summary"

        // When
        try await sutUnwrapped.updateDocumentSummary(id: doc.id, summary: newSummary)

        // Then
        let updated = try await sutUnwrapped.getDocument(id: doc.id)
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.contentSummary, newSummary)
        XCTAssertEqual(updated?.fileName, doc.fileName) // Other fields unchanged
        XCTAssertEqual(updated?.data, doc.data)
    }

    func testUpdateDocumentSummary_NonExistentDocument_ThrowsError() async throws {
        // Given
        let nonExistentId = UUID()

        // When/Then
        do {
            try await sutUnwrapped.updateDocumentSummary(id: nonExistentId, summary: "New summary")
            XCTFail("Expected error for non-existent document")
        } catch {
            XCTAssertTrue(error is DomainError)
        }
    }

    // MARK: - Search Tests

    func testSearchDocuments_ByFileName() async throws {
        // Given
        let acquisitionId1 = UUID()
        let acquisitionId2 = UUID()

        _ = try await sutUnwrapped.saveDocument(
            fileName: "contract-draft-v1.pdf",
            data: Data("content1".utf8),
            contentSummary: "Initial draft",
            acquisitionId: acquisitionId1
        )
        _ = try await sutUnwrapped.saveDocument(
            fileName: "contract-final.pdf",
            data: Data("content2".utf8),
            contentSummary: "Final version",
            acquisitionId: acquisitionId1
        )
        _ = try await sutUnwrapped.saveDocument(
            fileName: "invoice.pdf",
            data: Data("content3".utf8),
            contentSummary: "Monthly invoice",
            acquisitionId: acquisitionId2
        )

        // When
        let contractDocs = try await sutUnwrapped.searchDocuments(query: "contract")
        let invoiceDocs = try await sutUnwrapped.searchDocuments(query: "invoice")
        let pdfDocs = try await sutUnwrapped.searchDocuments(query: ".pdf")

        // Then
        XCTAssertEqual(contractDocs.count, 2)
        XCTAssertEqual(invoiceDocs.count, 1)
        XCTAssertEqual(pdfDocs.count, 3)
    }

    func testSearchDocuments_BySummary() async throws {
        // Given
        let acquisitionId = UUID()

        _ = try await sutUnwrapped.saveDocument(
            fileName: "doc1.pdf",
            data: Data("content1".utf8),
            contentSummary: "Requirements analysis document",
            acquisitionId: acquisitionId
        )
        _ = try await sutUnwrapped.saveDocument(
            fileName: "doc2.pdf",
            data: Data("content2".utf8),
            contentSummary: "Technical specifications",
            acquisitionId: acquisitionId
        )
        _ = try await sutUnwrapped.saveDocument(
            fileName: "doc3.pdf",
            data: Data("content3".utf8),
            contentSummary: nil, // No summary
            acquisitionId: acquisitionId
        )

        // When
        let requirementsDocs = try await sutUnwrapped.searchDocuments(query: "requirements")
        let technicalDocs = try await sutUnwrapped.searchDocuments(query: "technical")

        // Then
        XCTAssertEqual(requirementsDocs.count, 1)
        XCTAssertEqual(technicalDocs.count, 1)
    }

    // MARK: - Performance Tests

    func testPerformance_SaveManyDocuments() throws {
        measure {
            let expectation = self.expectation(description: "Save documents")

            Task {
                let acquisitionId = UUID()
                for i in 1 ... 100 {
                    _ = try await sutUnwrapped.saveDocument(
                        fileName: "document-\(i).pdf",
                        data: Data("Content \(i)".utf8),
                        contentSummary: "Summary \(i)",
                        acquisitionId: acquisitionId
                    )
                }
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)
        }
    }

    func testPerformance_SearchDocuments() throws {
        // Setup - create many documents
        let setupExpectation = expectation(description: "Setup documents")
        Task {
            let acquisitionId = UUID()
            for i in 1 ... 200 {
                _ = try await sutUnwrapped.saveDocument(
                    fileName: i % 2 == 0 ? "contract-\(i).pdf" : "invoice-\(i).pdf",
                    data: Data("Content \(i)".utf8),
                    contentSummary: "Document \(i)",
                    acquisitionId: acquisitionId
                )
            }
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 30.0)

        // Measure search performance
        measure {
            let searchExpectation = self.expectation(description: "Search documents")

            Task {
                _ = try await sutUnwrapped.searchDocuments(query: "contract")
                searchExpectation.fulfill()
            }

            wait(for: [searchExpectation], timeout: 5.0)
        }
    }
}
