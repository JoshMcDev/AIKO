@testable import AppCore
import XCTest

final class UnitAcquisitionAggregateTests: XCTestCase {
    // MARK: - Properties

    private var sut: AcquisitionAggregate?
    private var mockEventPublisherUnwrapped: MockDomainEventPublisher?

    private var sutUnwrapped: AcquisitionAggregate {
        guard let sut else { fatalError("sut not initialized") }
        return sut
    }

    private var mockEventPublisherUnwrappedUnwrapped: MockDomainEventPublisher {
        guard let mockEventPublisherUnwrapped else { fatalError("mockEventPublisherUnwrapped not initialized") }
        return mockEventPublisherUnwrapped
    }

    // MARK: - Setup/Teardown

    override func setUp() {
        super.setUp()

        mockEventPublisherUnwrapped = MockDomainEventPublisher()

        sut = AcquisitionAggregate(
            id: UUID(),
            title: "Test Acquisition",
            requirements: "Test requirements",
            status: .draft,
            createdAt: Date(),
            updatedAt: Date(),
            documents: [],
            forms: [],
            eventPublisher: mockEventPublisherUnwrapped
        )
    }

    override func tearDown() {
        sut = nil
        mockEventPublisherUnwrapped = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_SetsPropertiesCorrectly() {
        // Given
        let id = UUID()
        let title = "New Acquisition"
        let requirements = "Requirements text"
        let status = AcquisitionStatus.draft
        let createdAt = Date()
        let updatedAt = Date()

        // When
        let acquisition = AcquisitionAggregate(
            id: id,
            title: title,
            requirements: requirements,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            documents: [],
            forms: [],
            eventPublisher: mockEventPublisherUnwrapped
        )

        // Then
        XCTAssertEqual(acquisition.id, id)
        XCTAssertEqual(acquisition.title, title)
        XCTAssertEqual(acquisition.requirements, requirements)
        XCTAssertEqual(acquisition.status, status)
        XCTAssertEqual(acquisition.createdAt, createdAt)
        XCTAssertEqual(acquisition.updatedAt, updatedAt)
        XCTAssertEqual(acquisition.documents.count, 0)
        XCTAssertEqual(acquisition.forms.count, 0)
    }

    // MARK: - Update Tests

    func testUpdateTitle_Success() {
        // Given
        let newTitle = "Updated Title"
        let originalUpdatedAt = sutUnwrapped.updatedAt

        // When
        sutUnwrapped.updateTitle(newTitle)

        // Then
        XCTAssertEqual(sutUnwrapped.title, newTitle)
        XCTAssertGreaterThan(sutUnwrapped.updatedAt, originalUpdatedAt)

        // Verify event published
        XCTAssertEqual(mockEventPublisherUnwrapped.publishedEvents.count, 1)
        if let event = mockEventPublisherUnwrapped.publishedEvents.first as? AcquisitionUpdatedEvent {
            XCTAssertEqual(event.aggregateId, sutUnwrapped.id)
            XCTAssertEqual(event.field, "title")
            XCTAssertEqual(event.newValue as? String, newTitle)
        } else {
            XCTFail("Expected AcquisitionUpdatedEvent")
        }
    }

    func testUpdateRequirements_Success() {
        // Given
        let newRequirements = "Updated requirements"
        let originalUpdatedAt = sutUnwrapped.updatedAt

        // When
        sutUnwrapped.updateRequirements(newRequirements)

        // Then
        XCTAssertEqual(sutUnwrapped.requirements, newRequirements)
        XCTAssertGreaterThan(sutUnwrapped.updatedAt, originalUpdatedAt)

        // Verify event published
        XCTAssertEqual(mockEventPublisherUnwrapped.publishedEvents.count, 1)
        if let event = mockEventPublisherUnwrapped.publishedEvents.first as? AcquisitionUpdatedEvent {
            XCTAssertEqual(event.field, "requirements")
            XCTAssertEqual(event.newValue as? String, newRequirements)
        }
    }

    func testUpdateStatus_ValidTransition_Success() {
        // Given
        XCTAssertEqual(sutUnwrapped.status, .draft)

        // When - Draft to In Review
        sutUnwrapped.updateStatus(.inReview)

        // Then
        XCTAssertEqual(sutUnwrapped.status, .inReview)
        XCTAssertEqual(mockEventPublisherUnwrapped.publishedEvents.count, 1)
        if let event = mockEventPublisherUnwrapped.publishedEvents.first as? AcquisitionStatusChangedEvent {
            XCTAssertEqual(event.oldStatus, .draft)
            XCTAssertEqual(event.newStatus, .inReview)
        }
    }

    func testUpdateStatus_InvalidTransition_DoesNotUpdate() {
        // Given
        sutUnwrapped.updateStatus(.completed) // Set to completed
        mockEventPublisherUnwrapped.reset()

        // When - Try to go back to draft (invalid)
        sutUnwrapped.updateStatus(.draft)

        // Then
        XCTAssertEqual(sutUnwrapped.status, .completed) // Should remain completed
        XCTAssertEqual(mockEventPublisherUnwrapped.publishedEvents.count, 0) // No event published
    }

    // MARK: - Document Management Tests

    func testAddDocument_Success() {
        // Given
        let document = Document(
            id: UUID(),
            fileName: "test.pdf",
            data: Data("test".utf8),
            contentSummary: "Test document",
            createdAt: Date()
        )

        // When
        sutUnwrapped.addDocument(document)

        // Then
        XCTAssertEqual(sutUnwrapped.documents.count, 1)
        XCTAssertEqual(sutUnwrapped.documents.first?.id, document.id)

        // Verify event published
        XCTAssertEqual(mockEventPublisherUnwrapped.publishedEvents.count, 1)
        if let event = mockEventPublisherUnwrapped.publishedEvents.first as? DocumentAddedEvent {
            XCTAssertEqual(event.aggregateId, sutUnwrapped.id)
            XCTAssertEqual(event.documentId, document.id)
            XCTAssertEqual(event.fileName, document.fileName)
        }
    }

    func testAddDocument_Duplicate_DoesNotAdd() {
        // Given
        let document = Document(
            id: UUID(),
            fileName: "test.pdf",
            data: Data("test".utf8),
            contentSummary: nil,
            createdAt: Date()
        )
        sutUnwrapped.addDocument(document)
        mockEventPublisherUnwrapped.reset()

        // When - Try to add same document again
        sutUnwrapped.addDocument(document)

        // Then
        XCTAssertEqual(sutUnwrapped.documents.count, 1) // Still only one
        XCTAssertEqual(mockEventPublisherUnwrapped.publishedEvents.count, 0) // No new event
    }

    func testRemoveDocument_Success() {
        // Given
        let document = Document(
            id: UUID(),
            fileName: "test.pdf",
            data: Data("test".utf8),
            contentSummary: nil,
            createdAt: Date()
        )
        sutUnwrapped.addDocument(document)
        mockEventPublisherUnwrapped.reset()

        // When
        sutUnwrapped.removeDocument(withId: document.id)

        // Then
        XCTAssertEqual(sutUnwrapped.documents.count, 0)

        // Verify event published
        XCTAssertEqual(mockEventPublisherUnwrapped.publishedEvents.count, 1)
        if let event = mockEventPublisherUnwrapped.publishedEvents.first as? DocumentRemovedEvent {
            XCTAssertEqual(event.aggregateId, sutUnwrapped.id)
            XCTAssertEqual(event.documentId, document.id)
        }
    }

    func testRemoveDocument_NonExistent_NoChange() {
        // Given
        let nonExistentId = UUID()

        // When
        sutUnwrapped.removeDocument(withId: nonExistentId)

        // Then
        XCTAssertEqual(sutUnwrapped.documents.count, 0)
        XCTAssertEqual(mockEventPublisherUnwrapped.publishedEvents.count, 0)
    }

    // MARK: - Form Management Tests

    func testAddForm_Success() {
        // Given
        let form = createTestForm()

        // When
        sutUnwrapped.addForm(form)

        // Then
        XCTAssertEqual(sutUnwrapped.forms.count, 1)
        XCTAssertTrue(sutUnwrapped.forms.contains { $0.formNumber == form.formNumber })

        // Verify event published
        XCTAssertEqual(mockEventPublisherUnwrapped.publishedEvents.count, 1)
        if let event = mockEventPublisherUnwrapped.publishedEvents.first as? FormAddedEvent {
            XCTAssertEqual(event.aggregateId, sutUnwrapped.id)
            XCTAssertEqual(event.formNumber, form.formNumber)
            XCTAssertEqual(event.formType, String(describing: type(of: form)))
        }
    }

    func testRemoveForm_Success() {
        // Given
        let form = createTestForm()
        sutUnwrapped.addForm(form)
        mockEventPublisherUnwrapped.reset()

        // When
        sutUnwrapped.removeForm(withNumber: form.formNumber)

        // Then
        XCTAssertEqual(sutUnwrapped.forms.count, 0)

        // Verify event published
        XCTAssertEqual(mockEventPublisherUnwrapped.publishedEvents.count, 1)
        if let event = mockEventPublisherUnwrapped.publishedEvents.first as? FormRemovedEvent {
            XCTAssertEqual(event.aggregateId, sutUnwrapped.id)
            XCTAssertEqual(event.formNumber, form.formNumber)
        }
    }

    // MARK: - Validation Tests

    func testIsValidForSubmission_AllRequirementsMet_ReturnsTrue() {
        // Given
        sutUnwrapped.updateStatus(.approved)
        sutUnwrapped.addDocument(Document(
            id: UUID(),
            fileName: "requirements.pdf",
            data: Data("content".utf8),
            contentSummary: nil,
            createdAt: Date()
        ))
        sutUnwrapped.addForm(createTestForm())

        // When
        let isValid = sutUnwrapped.isValidForSubmission()

        // Then
        XCTAssertTrue(isValid)
    }

    func testIsValidForSubmission_WrongStatus_ReturnsFalse() {
        // Given - In draft status
        sutUnwrapped.addDocument(Document(
            id: UUID(),
            fileName: "requirements.pdf",
            data: Data("content".utf8),
            contentSummary: nil,
            createdAt: Date()
        ))
        sutUnwrapped.addForm(createTestForm())

        // When
        let isValid = sutUnwrapped.isValidForSubmission()

        // Then
        XCTAssertFalse(isValid)
    }

    func testIsValidForSubmission_NoDocuments_ReturnsFalse() {
        // Given
        sutUnwrapped.updateStatus(.approved)
        sutUnwrapped.addForm(createTestForm())

        // When
        let isValid = sutUnwrapped.isValidForSubmission()

        // Then
        XCTAssertFalse(isValid)
    }

    func testIsValidForSubmission_NoForms_ReturnsFalse() {
        // Given
        sutUnwrapped.updateStatus(.approved)
        sutUnwrapped.addDocument(Document(
            id: UUID(),
            fileName: "requirements.pdf",
            data: Data("content".utf8),
            contentSummary: nil,
            createdAt: Date()
        ))

        // When
        let isValid = sutUnwrapped.isValidForSubmission()

        // Then
        XCTAssertFalse(isValid)
    }

    // MARK: - Event Recording Tests

    func testGetDomainEvents_ReturnsAllEvents() {
        // Given
        sutUnwrapped.updateTitle("New Title")
        sutUnwrapped.updateStatus(.inReview)
        sutUnwrapped.addDocument(Document(
            id: UUID(),
            fileName: "test.pdf",
            data: Data("test".utf8),
            contentSummary: nil,
            createdAt: Date()
        ))

        // When
        let events = sutUnwrapped.getDomainEvents()

        // Then
        XCTAssertEqual(events.count, 3)
        XCTAssertTrue(events[0] is AcquisitionUpdatedEvent)
        XCTAssertTrue(events[1] is AcquisitionStatusChangedEvent)
        XCTAssertTrue(events[2] is DocumentAddedEvent)
    }

    func testClearDomainEvents_RemovesAllEvents() {
        // Given
        sutUnwrapped.updateTitle("New Title")
        sutUnwrapped.updateStatus(.inReview)

        // When
        sutUnwrapped.clearDomainEvents()
        let events = sutUnwrapped.getDomainEvents()

        // Then
        XCTAssertEqual(events.count, 0)
    }

    // MARK: - Helper Methods

    private func createTestForm() -> GovernmentForm {
        let formData = FormData()
        formData["formNumber"] = "SF1449"
        formData["title"] = "Test Form"
        formData["revision"] = "10/2023"

        let factory = SF1449Factory()
        return try! factory.create(with: formData)
    }
}

// MARK: - Mock Event Publisher

private class MockDomainEventPublisher: DomainEventPublisher {
    var publishedEvents: [DomainEvent] = []

    func publish(_ event: DomainEvent) {
        publishedEvents.append(event)
    }

    func reset() {
        publishedEvents.removeAll()
    }
}
