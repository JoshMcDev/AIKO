@testable import AppCore
import CoreData
import XCTest

/// Integration tests for SAMGovRepository using mock API client
final class IntegrationSAMGovRepositoryTests: XCTestCase {
    // MARK: - Properties

    private var sut: SAMGovRepository?
    private var context: NSManagedObjectContext?

    private var sutUnwrapped: SAMGovRepository {
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

        // Create repository with mock API client
        sut = SAMGovRepository.createMock(context: contextUnwrapped)
    }

    override func tearDown() {
        sut = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Integration Tests

    func testSearchEntitiesIntegration() async throws {
        // Test 1: Search for Lockheed Martin
        let lockheedResults = try await sutUnwrapped.searchEntities(query: "Lockheed")
        XCTAssertEqual(lockheedResults.count, 1)
        XCTAssertEqual(lockheedResults.first?.legalBusinessName, SAMGovTestData.lockheedName)
        XCTAssertEqual(lockheedResults.first?.cageCode, SAMGovTestData.lockheedCAGE)

        // Test 2: Search for Booz Allen
        let boozResults = try await sutUnwrapped.searchEntities(query: "Booz Allen")
        XCTAssertEqual(boozResults.count, 1)
        XCTAssertEqual(boozResults.first?.legalBusinessName, SAMGovTestData.boozAllenName)
        XCTAssertEqual(boozResults.first?.cageCode, SAMGovTestData.boozAllenCAGE)

        // Test 3: Search by CAGE code
        let cageResults = try await sutUnwrapped.searchEntities(query: "1F353")
        XCTAssertEqual(cageResults.count, 1)
        XCTAssertEqual(cageResults.first?.cageCode, SAMGovTestData.lockheedCAGE)

        // Test 4: No results
        let noResults = try await sutUnwrapped.searchEntities(query: "NonExistentCompany")
        XCTAssertEqual(noResults.count, 0)
    }

    func testGetEntityIntegration() async throws {
        // Test 1: Get by UEI
        let lockheedByUEI = try await sutUnwrapped.getEntity(uei: SAMGovTestData.lockheedUEI)
        XCTAssertNotNil(lockheedByUEI)
        XCTAssertEqual(lockheedByUEI?.legalBusinessName, SAMGovTestData.lockheedName)

        // Test 2: Get by CAGE
        let lockheedByCAGE = try await sutUnwrapped.getEntity(uei: SAMGovTestData.lockheedCAGE)
        XCTAssertNotNil(lockheedByCAGE)
        XCTAssertEqual(lockheedByCAGE?.legalBusinessName, SAMGovTestData.lockheedName)

        // Test 3: Non-existent entity
        let nonExistent = try await sutUnwrapped.getEntity(uei: "NOTFOUND123")
        XCTAssertNil(nonExistent)
    }

    func testCachingIntegration() async throws {
        // First call - should hit API
        let firstCall = try await sutUnwrapped.getEntity(uei: SAMGovTestData.lockheedUEI)
        XCTAssertNotNil(firstCall)

        // Second call - should use cache
        let secondCall = try await sutUnwrapped.getEntity(uei: SAMGovTestData.lockheedUEI)
        XCTAssertNotNil(secondCall)
        XCTAssertEqual(firstCall?.legalBusinessName, secondCall?.legalBusinessName)

        // Verify entity is cached
        let request = NSFetchRequest<CachedEntity>(entityName: "CachedEntity")
        request.predicate = NSPredicate(format: "uei == %@", SAMGovTestData.lockheedUEI)
        let cachedEntities = try contextUnwrapped.fetch(request)
        XCTAssertEqual(cachedEntities.count, 1)
        XCTAssertEqual(cachedEntities.first?.legalBusinessName, SAMGovTestData.lockheedName)
    }

    func testMultipleEntitiesIntegration() async throws {
        let ueis = [
            SAMGovTestData.lockheedUEI,
            SAMGovTestData.boozAllenUEI,
            "NOTFOUND123",
        ]

        let entities = try await sutUnwrapped.getEntities(ueis: ueis)
        XCTAssertEqual(entities.count, 2) // Should find 2 out of 3

        let names = entities.map(\.legalBusinessName)
        XCTAssertTrue(names.contains(SAMGovTestData.lockheedName))
        XCTAssertTrue(names.contains(SAMGovTestData.boozAllenName))
    }

    func testErrorHandlingIntegration() async throws {
        // Search that triggers error
        do {
            _ = try await sutUnwrapped.searchEntities(query: "error")
            XCTFail("Expected error but got success")
        } catch {
            XCTAssertTrue(error is SAMGovError)
        }
    }

    func testExclusionsIntegration() async throws {
        // Create test entity with exclusions
        let excludedEntity = SAMGovTestData.createEntityWithExclusions()

        // Mock API to return this entity
        let mockClient = MockSAMGovAPIClientWithExclusions(excludedEntity: excludedEntity)
        let repository = SAMGovRepository(context: context, apiClient: mockClient)

        // Get entity and check exclusions
        let entity = try await repository.getEntity(uei: excludedEntity.ueiSAM)
        XCTAssertNotNil(entity)
        XCTAssertEqual(entity?.exclusions.count, 1)
        XCTAssertEqual(entity?.exclusions.first?.classificationType, "Debarment")

        // Get exclusions directly
        let exclusions = try await repository.getExclusions(for: excludedEntity.ueiSAM)
        XCTAssertEqual(exclusions.count, 1)
    }

    func testConcurrentSearches() async throws {
        // Perform multiple searches concurrently
        await withTaskGroup(of: [SAMEntity].self) { group in
            for query in ["Lockheed", "Booz", "1F353", "17038"] {
                group.addTask {
                    try! await self.sutUnwrapped.searchEntities(query: query)
                }
            }

            var totalResults = 0
            for await results in group {
                totalResults += results.count
            }

            XCTAssertEqual(totalResults, 4) // Each query should return 1 result
        }
    }

    func testCacheClearingIntegration() async throws {
        // Populate cache
        _ = try await sutUnwrapped.getEntity(uei: SAMGovTestData.lockheedUEI)
        _ = try await sutUnwrapped.getEntity(uei: SAMGovTestData.boozAllenUEI)

        // Verify cache has entries
        let request = NSFetchRequest<CachedEntity>(entityName: "CachedEntity")
        let beforeClear = try contextUnwrapped.fetch(request)
        XCTAssertEqual(beforeClear.count, 2)

        // Clear cache
        try await sutUnwrapped.clearCache()

        // Verify cache is empty
        let afterClear = try contextUnwrapped.fetch(request)
        XCTAssertEqual(afterClear.count, 0)
    }
}

// MARK: - Mock API Client with Exclusions

private class MockSAMGovAPIClientWithExclusions: SAMGovAPIClientProtocol {
    let excludedEntity: SAMEntity

    init(excludedEntity: SAMEntity) {
        self.excludedEntity = excludedEntity
    }

    func searchEntities(query: String) async throws -> [SAMEntity] {
        if query.contains(excludedEntity.ueiSAM) || query.contains(excludedEntity.cageCode ?? "") {
            return [excludedEntity]
        }
        return []
    }

    func getEntity(uei: String) async throws -> SAMEntity? {
        if uei == excludedEntity.ueiSAM || uei == excludedEntity.cageCode {
            return excludedEntity
        }
        return nil
    }
}
