@testable import AppCore
import CoreData
import XCTest

final class UnitAcquisitionRepositoryTests: XCTestCase {
    // MARK: - Properties

    private var sut: AcquisitionRepository?
    private var context: NSManagedObjectContext?
    private var mockEventStore: InMemoryEventStore?

    private var sutUnwrapped: AcquisitionRepository {
        guard let sut else { fatalError("sut not initialized") }
        return sut
    }

    private var contextUnwrapped: NSManagedObjectContext {
        guard let context else { fatalError("context not initialized") }
        return context
    }

    private var mockEventStoreUnwrapped: InMemoryEventStore {
        guard let mockEventStore else { fatalError("mockEventStore not initialized") }
        return mockEventStore
    }

    // MARK: - Setup/Teardown

    override func setUp() {
        super.setUp()

        // Create in-memory Core Data stack
        let model = CoreDataStack.model
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try! coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)

        context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        // Create mock event store
        mockEventStore = InMemoryEventStore()

        // Create repository
        sut = AcquisitionRepository(context: context, eventStore: mockEventStore)
    }

    override func tearDown() {
        sut = nil
        context = nil
        mockEventStore = nil
        super.tearDown()
    }

    // MARK: - Creation Tests

    func testCreateAcquisition_Success() async throws {
        // Given
        let title = "Test Acquisition"
        let requirements = "Test requirements"

        // When
        let acquisition = try await sutUnwrapped.create(title: title, requirements: requirements)

        // Then
        XCTAssertNotNil(acquisition)
        XCTAssertEqual(acquisition.title, title)
        XCTAssertEqual(acquisition.requirements, requirements)
        XCTAssertEqual(acquisition.status, .draft)
        XCTAssertNotNil(acquisition.id)
        XCTAssertNotNil(acquisition.createdAt)
        XCTAssertNotNil(acquisition.updatedAt)

        // Verify domain event was stored
        let events = try await mockEventStoreUnwrapped.eventsForAggregate(id: acquisition.id, after: nil)
        XCTAssertEqual(events.count, 1)
    }

    func testCreateAcquisitionWithDocuments_Success() async throws {
        // Given
        let title = "Test Acquisition"
        let requirements = "Test requirements"
        let documents: [(fileName: String, data: Data, contentSummary: String?)] = [
            ("test1.pdf", Data("test1".utf8), "Summary 1"),
            ("test2.docx", Data("test2".utf8), nil),
        ]

        // When
        let acquisition = try await sutUnwrapped.createWithDocuments(
            title: title,
            requirements: requirements,
            uploadedDocuments: documents
        )

        // Then
        XCTAssertNotNil(acquisition)
        XCTAssertEqual(acquisition.title, title)
        XCTAssertEqual(acquisition.requirements, requirements)
        XCTAssertEqual(acquisition.documents.count, 2)

        // Verify documents
        let doc1 = acquisition.documents.first { $0.fileName == "test1.pdf" }
        XCTAssertNotNil(doc1)
        XCTAssertEqual(doc1?.contentSummary, "Summary 1")

        let doc2 = acquisition.documents.first { $0.fileName == "test2.docx" }
        XCTAssertNotNil(doc2)
        XCTAssertNil(doc2?.contentSummary)

        // Verify domain events
        let events = try await mockEventStoreUnwrapped.eventsForAggregate(id: acquisition.id, after: nil)
        XCTAssertGreaterThanOrEqual(events.count, 3) // Created + 2 document added events
    }

    // MARK: - Retrieval Tests

    func testFindById_ExistingAcquisition_Success() async throws {
        // Given
        let created = try await sutUnwrapped.create(title: "Test", requirements: "Requirements")

        // When
        let found = try await sutUnwrapped.findById(created.id)

        // Then
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, created.id)
        XCTAssertEqual(found?.title, created.title)
        XCTAssertEqual(found?.requirements, created.requirements)
    }

    func testFindById_NonExistentAcquisition_ReturnsNil() async throws {
        // Given
        let nonExistentId = UUID()

        // When
        let found = try await sutUnwrapped.findById(nonExistentId)

        // Then
        XCTAssertNil(found)
    }

    func testFindAll_Success() async throws {
        // Given
        let acquisition1 = try await sutUnwrapped.create(title: "Test 1", requirements: "Req 1")
        let acquisition2 = try await sutUnwrapped.create(title: "Test 2", requirements: "Req 2")
        let acquisition3 = try await sutUnwrapped.create(title: "Test 3", requirements: "Req 3")

        // When
        let all = try await sutUnwrapped.findAll()

        // Then
        XCTAssertEqual(all.count, 3)
        let ids = all.map(\.id)
        XCTAssertTrue(ids.contains(acquisition1.id))
        XCTAssertTrue(ids.contains(acquisition2.id))
        XCTAssertTrue(ids.contains(acquisition3.id))
    }

    func testFindByStatus_Success() async throws {
        // Given
        let draft1 = try await sutUnwrapped.create(title: "Draft 1", requirements: "Req")
        let draft2 = try await sutUnwrapped.create(title: "Draft 2", requirements: "Req")

        // Create one in review
        let inReview = try await sutUnwrapped.create(title: "In Review", requirements: "Req")
        try await sutUnwrapped.update(inReview.id) { acquisition in
            acquisition.updateStatus(.inReview)
        }

        // When
        let drafts = try await sutUnwrapped.findByStatus(.draft)
        let reviews = try await sutUnwrapped.findByStatus(.inReview)

        // Then
        XCTAssertEqual(drafts.count, 2)
        XCTAssertEqual(reviews.count, 1)
        XCTAssertEqual(reviews.first?.id, inReview.id)
    }

    // MARK: - Update Tests

    func testUpdate_Success() async throws {
        // Given
        let acquisition = try await sutUnwrapped.create(title: "Original", requirements: "Original Req")
        let newTitle = "Updated Title"
        let newRequirements = "Updated Requirements"

        // When
        try await sutUnwrapped.update(acquisition.id) { acq in
            acq.updateTitle(newTitle)
            acq.updateRequirements(newRequirements)
        }

        // Then
        let updated = try await sutUnwrapped.findById(acquisition.id)
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.title, newTitle)
        XCTAssertEqual(updated?.requirements, newRequirements)
        XCTAssertGreaterThan(updated?.updatedAt ?? Date.distantPast, acquisition.updatedAt)

        // Verify domain events
        let events = try await mockEventStoreUnwrapped.eventsForAggregate(id: acquisition.id, after: nil)
        XCTAssertGreaterThanOrEqual(events.count, 3) // Created + 2 update events
    }

    func testUpdate_NonExistentAcquisition_ThrowsError() async throws {
        // Given
        let nonExistentId = UUID()

        // When/Then
        do {
            try await sutUnwrapped.update(nonExistentId) { _ in }
            XCTFail("Expected error but succeeded")
        } catch {
            XCTAssertTrue(error is DomainError)
        }
    }

    // MARK: - Delete Tests

    func testDelete_Success() async throws {
        // Given
        let acquisition = try await sutUnwrapped.create(title: "To Delete", requirements: "Req")

        // When
        try await sutUnwrapped.delete(acquisition.id)

        // Then
        let found = try await sutUnwrapped.findById(acquisition.id)
        XCTAssertNil(found)
    }

    func testDelete_NonExistentAcquisition_ThrowsError() async throws {
        // Given
        let nonExistentId = UUID()

        // When/Then
        do {
            try await sutUnwrapped.delete(nonExistentId)
            XCTFail("Expected error but succeeded")
        } catch {
            XCTAssertTrue(error is DomainError)
        }
    }

    // MARK: - Document Management Tests

    func testAddDocument_Success() async throws {
        // Given
        let acquisition = try await sutUnwrapped.create(title: "Test", requirements: "Req")
        let fileName = "new-doc.pdf"
        let data = Data("test content".utf8)
        let summary = "Test document"

        // When
        try await sutUnwrapped.update(acquisition.id) { acq in
            let doc = Document(
                id: UUID(),
                fileName: fileName,
                data: data,
                contentSummary: summary,
                createdAt: Date()
            )
            acq.addDocument(doc)
        }

        // Then
        let updated = try await sutUnwrapped.findById(acquisition.id)
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.documents.count, 1)
        XCTAssertEqual(updated?.documents.first?.fileName, fileName)
        XCTAssertEqual(updated?.documents.first?.contentSummary, summary)
    }

    func testRemoveDocument_Success() async throws {
        // Given
        let documents: [(fileName: String, data: Data, contentSummary: String?)] = [
            ("doc1.pdf", Data("test1".utf8), "Doc 1"),
            ("doc2.pdf", Data("test2".utf8), "Doc 2"),
        ]
        let acquisition = try await sutUnwrapped.createWithDocuments(
            title: "Test",
            requirements: "Req",
            uploadedDocuments: documents
        )
        guard let docToRemove = acquisition.documents.first else {
            XCTFail("Expected at least one document in acquisition")
            return
        }

        // When
        try await sutUnwrapped.update(acquisition.id) { acq in
            acq.removeDocument(withId: docToRemove.id)
        }

        // Then
        let updated = try await sutUnwrapped.findById(acquisition.id)
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.documents.count, 1)
        XCTAssertNotEqual(updated?.documents.first?.id, docToRemove.id)
    }

    // MARK: - Status Transition Tests

    func testStatusTransitions_Valid() async throws {
        // Given
        let acquisition = try await sutUnwrapped.create(title: "Test", requirements: "Req")

        // Draft -> In Review
        try await sutUnwrapped.update(acquisition.id) { acq in
            acq.updateStatus(.inReview)
        }
        var updated = try await sutUnwrapped.findById(acquisition.id)
        XCTAssertEqual(updated?.status, .inReview)

        // In Review -> Approved
        try await sutUnwrapped.update(acquisition.id) { acq in
            acq.updateStatus(.approved)
        }
        updated = try await sutUnwrapped.findById(acquisition.id)
        XCTAssertEqual(updated?.status, .approved)

        // Approved -> Submitted
        try await sutUnwrapped.update(acquisition.id) { acq in
            acq.updateStatus(.submitted)
        }
        updated = try await sutUnwrapped.findById(acquisition.id)
        XCTAssertEqual(updated?.status, .submitted)

        // Submitted -> Completed
        try await sutUnwrapped.update(acquisition.id) { acq in
            acq.updateStatus(.completed)
        }
        updated = try await sutUnwrapped.findById(acquisition.id)
        XCTAssertEqual(updated?.status, .completed)
    }

    // MARK: - Concurrency Tests

    func testConcurrentUpdates_HandleGracefully() async throws {
        // Given
        let acquisition = try await sutUnwrapped.create(title: "Concurrent Test", requirements: "Req")

        // When - Perform concurrent updates
        await withTaskGroup(of: Void.self) { group in
            for i in 1 ... 10 {
                group.addTask {
                    try? await self.sutUnwrapped.update(acquisition.id) { acq in
                        acq.updateTitle("Update \(i)")
                    }
                }
            }
        }

        // Then - Should have last update
        let final = try await sutUnwrapped.findById(acquisition.id)
        XCTAssertNotNil(final)
        XCTAssertTrue(final?.title.starts(with: "Update") ?? false)
    }

    // MARK: - Performance Tests

    func testPerformance_CreateManyAcquisitions() throws {
        measure {
            let expectation = self.expectation(description: "Create acquisitions")

            Task {
                for i in 1 ... 100 {
                    _ = try await sutUnwrapped.create(
                        title: "Acquisition \(i)",
                        requirements: "Requirements \(i)"
                    )
                }
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)
        }
    }
}
