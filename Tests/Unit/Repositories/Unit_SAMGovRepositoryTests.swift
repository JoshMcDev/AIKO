@testable import AppCore
import CoreData
import XCTest

final class UnitSAMGovRepositoryTests: XCTestCase {
    // MARK: - Properties

    private var sut: SAMGovRepository?
    private var context: NSManagedObjectContext?
    private var mockAPIClient: MockSAMGovAPIClient?

    private var sutUnwrapped: SAMGovRepository {
        guard let sut else { fatalError("sut not initialized") }
        return sut
    }

    private var contextUnwrapped: NSManagedObjectContext {
        guard let context else { fatalError("context not initialized") }
        return context
    }

    private var mockAPIClientUnwrapped: MockSAMGovAPIClient {
        guard let mockAPIClient else { fatalError("mockAPIClient not initialized") }
        return mockAPIClient
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

        // Create mock API client
        mockAPIClient = MockSAMGovAPIClient()

        // Create repository
        sut = SAMGovRepository(context: context, apiClient: mockAPIClient)
    }

    override func tearDown() {
        sut = nil
        context = nil
        mockAPIClient = nil
        super.tearDown()
    }

    // MARK: - Search Tests

    func testSearchEntities_Success() async throws {
        // Given
        let query = "Test Company"
        mockAPIClientUnwrapped.searchResponse = [
            createMockEntity(name: "Test Company Inc", uei: "TEST123456"),
            createMockEntity(name: "Test Company LLC", uei: "TEST789012"),
        ]

        // When
        let results = try await sutUnwrapped.searchEntities(query: query)

        // Then
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].legalBusinessName, "Test Company Inc")
        XCTAssertEqual(results[0].ueiSAM, "TEST123456")
        XCTAssertEqual(results[1].legalBusinessName, "Test Company LLC")
        XCTAssertEqual(results[1].ueiSAM, "TEST789012")

        // Verify API was called
        XCTAssertEqual(mockAPIClientUnwrapped.searchCalls.count, 1)
        XCTAssertEqual(mockAPIClientUnwrapped.searchCalls.first, query)
    }

    func testSearchEntities_EmptyQuery_ThrowsError() async throws {
        // Given
        let query = ""

        // When/Then
        do {
            _ = try await sutUnwrapped.searchEntities(query: query)
            XCTFail("Expected error for empty query")
        } catch {
            XCTAssertTrue(error is DomainError)
        }
    }

    func testSearchEntities_APIError_ThrowsError() async throws {
        // Given
        let query = "Test Company"
        mockAPIClientUnwrapped.shouldThrowError = true

        // When/Then
        do {
            _ = try await sutUnwrapped.searchEntities(query: query)
            XCTFail("Expected error from API")
        } catch {
            // Expected error
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Get Entity Tests

    func testGetEntity_Success() async throws {
        // Given
        let uei = "TEST123456"
        let mockEntity = createMockEntity(
            name: "Test Company",
            uei: uei,
            exclusions: [createMockExclusion()]
        )
        mockAPIClientUnwrapped.getEntityResponse = mockEntity

        // When
        let entity = try await sutUnwrapped.getEntity(uei: uei)

        // Then
        XCTAssertNotNil(entity)
        XCTAssertEqual(entity?.ueiSAM, uei)
        XCTAssertEqual(entity?.legalBusinessName, "Test Company")
        XCTAssertEqual(entity?.exclusions.count, 1)

        // Verify API was called
        XCTAssertEqual(mockAPIClientUnwrapped.getEntityCalls.count, 1)
        XCTAssertEqual(mockAPIClientUnwrapped.getEntityCalls.first, uei)
    }

    func testGetEntity_NotFound_ReturnsNil() async throws {
        // Given
        let uei = "NOTFOUND123"
        mockAPIClientUnwrapped.getEntityResponse = nil

        // When
        let entity = try await sutUnwrapped.getEntity(uei: uei)

        // Then
        XCTAssertNil(entity)
    }

    func testGetEntity_CachedEntity_ReturnsCachedVersion() async throws {
        // Given
        let uei = "TEST123456"
        let mockEntity = createMockEntity(name: "Test Company", uei: uei)

        // First call to populate cache
        mockAPIClientUnwrapped.getEntityResponse = mockEntity
        _ = try await sutUnwrapped.getEntity(uei: uei)

        // Change API response
        mockAPIClientUnwrapped.getEntityResponse = createMockEntity(name: "Different Company", uei: uei)

        // When - Second call should use cache
        let cachedEntity = try await sutUnwrapped.getEntity(uei: uei)

        // Then
        XCTAssertEqual(cachedEntity?.legalBusinessName, "Test Company") // Original cached value
        XCTAssertEqual(mockAPIClientUnwrapped.getEntityCalls.count, 1) // API only called once
    }

    func testGetEntity_ExpiredCache_RefreshesFromAPI() async throws {
        // Given
        let uei = "TEST123456"
        let originalEntity = createMockEntity(name: "Original Company", uei: uei)
        mockAPIClientUnwrapped.getEntityResponse = originalEntity

        // First call to populate cache
        _ = try await sutUnwrapped.getEntity(uei: uei)

        // Manually expire cache by updating timestamp
        let request = NSFetchRequest<CachedEntity>(entityName: "CachedEntity")
        request.predicate = NSPredicate(format: "uei == %@", uei)
        if let cached = try contextUnwrapped.fetch(request).first {
            cached.lastUpdated = Date().addingTimeInterval(-25 * 60 * 60) // 25 hours ago
            try contextUnwrapped.save()
        }

        // Update API response
        let updatedEntity = createMockEntity(name: "Updated Company", uei: uei)
        mockAPIClientUnwrapped.getEntityResponse = updatedEntity

        // When
        let refreshedEntity = try await sutUnwrapped.getEntity(uei: uei)

        // Then
        XCTAssertEqual(refreshedEntity?.legalBusinessName, "Updated Company")
        XCTAssertEqual(mockAPIClientUnwrapped.getEntityCalls.count, 2) // API called twice
    }

    // MARK: - Exclusions Tests

    func testGetExclusions_Success() async throws {
        // Given
        let uei = "TEST123456"
        let exclusions = [
            createMockExclusion(classificationType: "Debarment", activeDate: "2023-01-01"),
            createMockExclusion(classificationType: "Suspension", activeDate: "2023-06-01"),
        ]
        let mockEntity = createMockEntity(name: "Test Company", uei: uei, exclusions: exclusions)
        mockAPIClientUnwrapped.getEntityResponse = mockEntity

        // When
        let retrievedExclusions = try await sutUnwrapped.getExclusions(for: uei)

        // Then
        XCTAssertEqual(retrievedExclusions.count, 2)
        XCTAssertEqual(retrievedExclusions[0].classificationType, "Debarment")
        XCTAssertEqual(retrievedExclusions[1].classificationType, "Suspension")
    }

    func testGetExclusions_NoExclusions_ReturnsEmpty() async throws {
        // Given
        let uei = "TEST123456"
        let mockEntity = createMockEntity(name: "Test Company", uei: uei, exclusions: [])
        mockAPIClientUnwrapped.getEntityResponse = mockEntity

        // When
        let exclusions = try await sutUnwrapped.getExclusions(for: uei)

        // Then
        XCTAssertEqual(exclusions.count, 0)
    }

    // MARK: - Multiple UEI Tests

    func testGetEntities_MultipleUEIs_Success() async throws {
        // Given
        let ueis = ["TEST123456", "TEST789012", "TEST345678"]
        mockAPIClientUnwrapped.getEntityResponse = nil // Will be set per call

        // Setup different responses for each UEI
        mockAPIClientUnwrapped.getEntitiesHandler = { uei in
            switch uei {
            case "TEST123456":
                self.createMockEntity(name: "Company 1", uei: uei)
            case "TEST789012":
                self.createMockEntity(name: "Company 2", uei: uei)
            case "TEST345678":
                self.createMockEntity(name: "Company 3", uei: uei)
            default:
                nil
            }
        }

        // When
        let entities = try await sutUnwrapped.getEntities(ueis: ueis)

        // Then
        XCTAssertEqual(entities.count, 3)
        XCTAssertTrue(entities.contains { $0.legalBusinessName == "Company 1" })
        XCTAssertTrue(entities.contains { $0.legalBusinessName == "Company 2" })
        XCTAssertTrue(entities.contains { $0.legalBusinessName == "Company 3" })
    }

    func testGetEntities_SomeNotFound_ReturnsOnlyFound() async throws {
        // Given
        let ueis = ["TEST123456", "NOTFOUND", "TEST345678"]
        mockAPIClientUnwrapped.getEntitiesHandler = { uei in
            if uei == "NOTFOUND" {
                return nil
            }
            return self.createMockEntity(name: "Company \(uei)", uei: uei)
        }

        // When
        let entities = try await sutUnwrapped.getEntities(ueis: ueis)

        // Then
        XCTAssertEqual(entities.count, 2)
        XCTAssertFalse(entities.contains { $0.ueiSAM == "NOTFOUND" })
    }

    // MARK: - Cache Management Tests

    func testClearCache_Success() async throws {
        // Given - Populate cache with entities
        let uei1 = "TEST123456"
        let uei2 = "TEST789012"
        mockAPIClientUnwrapped.getEntityResponse = createMockEntity(name: "Company 1", uei: uei1)
        _ = try await sutUnwrapped.getEntity(uei: uei1)
        mockAPIClientUnwrapped.getEntityResponse = createMockEntity(name: "Company 2", uei: uei2)
        _ = try await sutUnwrapped.getEntity(uei: uei2)

        // Verify cache is populated
        let request = NSFetchRequest<CachedEntity>(entityName: "CachedEntity")
        let beforeClear = try contextUnwrapped.fetch(request)
        XCTAssertEqual(beforeClear.count, 2)

        // When
        try await sutUnwrapped.clearCache()

        // Then
        let afterClear = try contextUnwrapped.fetch(request)
        XCTAssertEqual(afterClear.count, 0)
    }

    // MARK: - Performance Tests

    func testPerformance_SearchEntities() throws {
        // Given
        mockAPIClientUnwrapped.searchResponse = (1 ... 100).map { i in
            createMockEntity(name: "Company \(i)", uei: "UEI\(i)")
        }

        // Measure
        measure {
            let expectation = self.expectation(description: "Search entities")

            Task {
                _ = try await sutUnwrapped.searchEntities(query: "Company")
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    // MARK: - Helper Methods

    private func createMockEntity(
        name: String,
        uei: String,
        cage: String? = "12345",
        exclusions: [SAMExclusion] = [],
        isSmallBusiness: Bool = false
    ) -> SAMEntity {
        SAMEntity(
            ueiSAM: uei,
            cageCode: cage,
            legalBusinessName: name,
            registrationStatus: "Active",
            registrationExpirationDate: "2025-12-31",
            purposeOfRegistrationCode: "Z2",
            purposeOfRegistrationDesc: "All Awards",
            entityStructureCode: "2L",
            entityStructureDesc: "Corporate Entity (Not Tax Exempt)",
            entityTypeCode: "F",
            entityTypeDesc: "Business or Organization",
            exclusions: exclusions,
            isSmallBusiness: isSmallBusiness
        )
    }

    private func createMockExclusion(
        classificationType: String = "Debarment",
        activeDate: String = "2023-01-01"
    ) -> SAMExclusion {
        SAMExclusion(
            classificationType: classificationType,
            exclusionType: "Ineligible (Proceedings Completed)",
            exclusionProgram: "Reciprocal",
            excludingAgencyCode: "DOD",
            excludingAgencyName: "Department of Defense",
            activeDate: activeDate,
            terminationDate: nil,
            recordStatus: "Active",
            crossReference: nil,
            samAdditionalComments: nil
        )
    }
}

// MARK: - Mock API Client

private class MockSAMGovAPIClient: SAMGovAPIClientProtocol {
    var searchCalls: [String] = []
    var getEntityCalls: [String] = []
    var searchResponse: [SAMEntity] = []
    var getEntityResponse: SAMEntity?
    var getEntitiesHandler: ((String) -> SAMEntity?)?
    var shouldThrowError = false

    enum MockError: Error {
        case testError
    }

    func searchEntities(query: String) async throws -> [SAMEntity] {
        searchCalls.append(query)
        if shouldThrowError {
            throw MockError.testError
        }
        return searchResponse
    }

    func getEntity(uei: String) async throws -> SAMEntity? {
        getEntityCalls.append(uei)
        if shouldThrowError {
            throw MockError.testError
        }
        if let handler = getEntitiesHandler {
            return handler(uei)
        }
        return getEntityResponse
    }
}
