@testable import AppCore
import Foundation

// Mock SAM.gov API client for testing without API key
class MockSAMGovAPIClient: SAMGovAPIClientProtocol {
    func searchEntities(query: String) async throws -> [SAMEntity] {
        // Mock responses based on query
        if query.lowercased().contains("lockheed") || query.contains("1F353") {
            return [createLockheedEntity()]
        } else if query.lowercased().contains("booz") || query.contains("17038") {
            return [createBoozAllenEntity()]
        } else if query.lowercased().contains("error") {
            throw SAMGovError.apiError("Mock error for testing")
        } else {
            return [] // Empty array for no results
        }
    }

    func getEntity(uei: String) async throws -> SAMEntity? {
        // Search for entity by UEI or CAGE
        switch uei {
        case "G2Y7W1E3LJK5", "1F353":
            createLockheedEntity()
        case "R3Q8P8B7VNJ3", "17038":
            createBoozAllenEntity()
        default:
            nil
        }
    }

    // MARK: - Helper Methods

    private func createLockheedEntity() -> SAMEntity {
        guard let expirationDate = Calendar.current.date(byAdding: .day, value: 67, to: Date()) else {
            fatalError("Failed to create expiration date for Lockheed mock entity")
        }

        return SAMEntity(
            ueiSAM: "G2Y7W1E3LJK5",
            cageCode: "1F353",
            legalBusinessName: "LOCKHEED MARTIN CORPORATION",
            registrationStatus: "Active",
            registrationExpirationDate: ISO8601DateFormatter().string(from: expirationDate),
            purposeOfRegistrationCode: "Z2",
            purposeOfRegistrationDesc: "All Awards",
            entityStructureCode: "2L",
            entityStructureDesc: "Corporate Entity (Not Tax Exempt)",
            entityTypeCode: "F",
            entityTypeDesc: "Business or Organization",
            exclusions: [],
            isSmallBusiness: false
        )
    }

    private func createBoozAllenEntity() -> SAMEntity {
        guard let expirationDate = Calendar.current.date(byAdding: .day, value: 133, to: Date()) else {
            fatalError("Failed to create expiration date for Booz Allen mock entity")
        }

        return SAMEntity(
            ueiSAM: "R3Q8P8B7VNJ3",
            cageCode: "17038",
            legalBusinessName: "BOOZ ALLEN HAMILTON INC",
            registrationStatus: "Active",
            registrationExpirationDate: ISO8601DateFormatter().string(from: expirationDate),
            purposeOfRegistrationCode: "Z2",
            purposeOfRegistrationDesc: "All Awards",
            entityStructureCode: "2L",
            entityStructureDesc: "Corporate Entity (Not Tax Exempt)",
            entityTypeCode: "F",
            entityTypeDesc: "Business or Organization",
            exclusions: [],
            isSmallBusiness: false
        )
    }
}

// MARK: - Mock Factory

extension SAMGovRepository {
    /// Creates a SAMGovRepository with mock API client for testing
    static func createMock(context: NSManagedObjectContext) -> SAMGovRepository {
        SAMGovRepository(
            context: context,
            apiClient: MockSAMGovAPIClient()
        )
    }
}

// MARK: - Test Data Factory

enum SAMGovTestData {
    static let lockheedUEI = "G2Y7W1E3LJK5"
    static let lockheedCAGE = "1F353"
    static let lockheedName = "LOCKHEED MARTIN CORPORATION"

    static let boozAllenUEI = "R3Q8P8B7VNJ3"
    static let boozAllenCAGE = "17038"
    static let boozAllenName = "BOOZ ALLEN HAMILTON INC"

    static func createExclusion(type: String = "Debarment") -> SAMExclusion {
        SAMExclusion(
            classificationType: type,
            exclusionType: "Ineligible (Proceedings Completed)",
            exclusionProgram: "Reciprocal",
            excludingAgencyCode: "DOD",
            excludingAgencyName: "Department of Defense",
            activeDate: ISO8601DateFormatter().string(from: Date()),
            terminationDate: nil,
            recordStatus: "Active",
            crossReference: nil,
            samAdditionalComments: nil
        )
    }

    static func createEntityWithExclusions() -> SAMEntity {
        SAMEntity(
            ueiSAM: "EXCL123456",
            cageCode: "99999",
            legalBusinessName: "EXCLUDED COMPANY INC",
            registrationStatus: "Active",
            registrationExpirationDate: ISO8601DateFormatter().string(from: Date()),
            purposeOfRegistrationCode: "Z2",
            purposeOfRegistrationDesc: "All Awards",
            entityStructureCode: "2L",
            entityStructureDesc: "Corporate Entity (Not Tax Exempt)",
            entityTypeCode: "F",
            entityTypeDesc: "Business or Organization",
            exclusions: [createExclusion()],
            isSmallBusiness: false
        )
    }
}
