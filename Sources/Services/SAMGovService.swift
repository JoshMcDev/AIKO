import ComposableArchitecture
import Foundation

// MARK: - SAM.gov Service Types

/// Service for interacting with SAM.gov API
public struct SAMGovService: Sendable {
    public var searchEntity: @Sendable (String) async throws -> EntitySearchResult
    public var getEntityByCAGE: @Sendable (String) async throws -> EntityDetail
    public var getEntityByUEI: @Sendable (String) async throws -> EntityDetail
    
    public init(
        searchEntity: @escaping @Sendable (String) async throws -> EntitySearchResult,
        getEntityByCAGE: @escaping @Sendable (String) async throws -> EntityDetail,
        getEntityByUEI: @escaping @Sendable (String) async throws -> EntityDetail
    ) {
        self.searchEntity = searchEntity
        self.getEntityByCAGE = getEntityByCAGE
        self.getEntityByUEI = getEntityByUEI
    }
}

// MARK: - Entity Types

/// Detailed entity information from SAM.gov
public struct EntityDetail: Codable, Sendable, Identifiable {
    public let id = UUID()
    public let ueiSAM: String
    public let entityName: String
    public let legalBusinessName: String
    public let cageCode: String?
    public let duns: String?
    public let ncage: String?
    public let registrationStatus: String
    public let registrationDate: Date?
    public let expirationDate: Date?
    public let lastUpdatedDate: Date?
    public let businessTypes: [String]
    public let primaryNAICS: String?
    public let address: EntityAddress?
    public let pointOfContact: PointOfContact?
    public let hasActiveExclusions: Bool
    public let naicsCodes: [NAICSCode]
    public let isSmallBusiness: Bool
    public let isVeteranOwned: Bool
    public let isServiceDisabledVeteranOwned: Bool
    public let isWomanOwned: Bool
    public let is8aProgram: Bool
    public let isHUBZone: Bool
    public let section889Certifications: Section889Certifications?
    public let foreignGovtEntities: [ForeignGovernmentEntity]
    public let responsibilityInformation: ResponsibilityInformation?
    public let architectEngineerQualifications: ArchitectEngineerQualifications?
    public let physicalAddress: PhysicalAddress?
    
    public init(
        ueiSAM: String,
        entityName: String,
        legalBusinessName: String? = nil,
        cageCode: String? = nil,
        duns: String? = nil,
        ncage: String? = nil,
        registrationStatus: String = "Active",
        registrationDate: Date? = nil,
        expirationDate: Date? = nil,
        lastUpdatedDate: Date? = nil,
        businessTypes: [String] = [],
        primaryNAICS: String? = nil,
        address: EntityAddress? = nil,
        pointOfContact: PointOfContact? = nil,
        hasActiveExclusions: Bool = false,
        naicsCodes: [NAICSCode] = [],
        isSmallBusiness: Bool = false,
        isVeteranOwned: Bool = false,
        isServiceDisabledVeteranOwned: Bool = false,
        isWomanOwned: Bool = false,
        is8aProgram: Bool = false,
        isHUBZone: Bool = false,
        section889Certifications: Section889Certifications? = nil,
        foreignGovtEntities: [ForeignGovernmentEntity] = [],
        responsibilityInformation: ResponsibilityInformation? = nil,
        architectEngineerQualifications: ArchitectEngineerQualifications? = nil,
        physicalAddress: PhysicalAddress? = nil
    ) {
        self.ueiSAM = ueiSAM
        self.entityName = entityName
        self.legalBusinessName = legalBusinessName ?? entityName
        self.cageCode = cageCode
        self.duns = duns
        self.ncage = ncage
        self.registrationStatus = registrationStatus
        self.registrationDate = registrationDate
        self.expirationDate = expirationDate
        self.lastUpdatedDate = lastUpdatedDate
        self.businessTypes = businessTypes
        self.primaryNAICS = primaryNAICS
        self.address = address
        self.pointOfContact = pointOfContact
        self.hasActiveExclusions = hasActiveExclusions
        self.naicsCodes = naicsCodes
        self.isSmallBusiness = isSmallBusiness
        self.isVeteranOwned = isVeteranOwned
        self.isServiceDisabledVeteranOwned = isServiceDisabledVeteranOwned
        self.isWomanOwned = isWomanOwned
        self.is8aProgram = is8aProgram
        self.isHUBZone = isHUBZone
        self.section889Certifications = section889Certifications
        self.foreignGovtEntities = foreignGovtEntities
        self.responsibilityInformation = responsibilityInformation
        self.architectEngineerQualifications = architectEngineerQualifications
        self.physicalAddress = physicalAddress
    }
}

/// Entity search result container
public struct EntitySearchResult: Codable, Sendable {
    public let entities: [EntitySummary]
    public let totalCount: Int
    
    public init(entities: [EntitySummary], totalCount: Int) {
        self.entities = entities
        self.totalCount = totalCount
    }
}

/// Summary information for search results
public struct EntitySummary: Codable, Sendable, Identifiable {
    public let id = UUID()
    public let ueiSAM: String
    public let entityName: String
    public let cageCode: String?
    public let registrationStatus: String
    
    public init(ueiSAM: String, entityName: String, cageCode: String? = nil, registrationStatus: String = "Active") {
        self.ueiSAM = ueiSAM
        self.entityName = entityName
        self.cageCode = cageCode
        self.registrationStatus = registrationStatus
    }
}

/// Entity address information
public struct EntityAddress: Codable, Sendable {
    public let line1: String
    public let line2: String?
    public let city: String
    public let state: String
    public let zipCode: String
    public let country: String
    
    public init(line1: String, line2: String? = nil, city: String, state: String, zipCode: String, country: String = "USA") {
        self.line1 = line1
        self.line2 = line2
        self.city = city
        self.state = state
        self.zipCode = zipCode
        self.country = country
    }
}

/// Point of contact information
public struct PointOfContact: Codable, Sendable {
    public let firstName: String
    public let lastName: String
    public let title: String?
    public let email: String?
    public let phone: String?
    
    public init(firstName: String, lastName: String, title: String? = nil, email: String? = nil, phone: String? = nil) {
        self.firstName = firstName
        self.lastName = lastName
        self.title = title
        self.email = email
        self.phone = phone
    }
}

/// NAICS code information
public struct NAICSCode: Codable, Sendable {
    public let code: String
    public let description: String
    public let isPrimary: Bool
    
    public init(code: String, description: String, isPrimary: Bool = false) {
        self.code = code
        self.description = description
        self.isPrimary = isPrimary
    }
}

/// Section 889 compliance certifications
public struct Section889Certifications: Codable, Sendable {
    public let doesNotProvideProhibitedTelecom: Bool?
    public let doesNotUseProhibitedTelecom: Bool?
    
    public init(doesNotProvideProhibitedTelecom: Bool? = nil, doesNotUseProhibitedTelecom: Bool? = nil) {
        self.doesNotProvideProhibitedTelecom = doesNotProvideProhibitedTelecom
        self.doesNotUseProhibitedTelecom = doesNotUseProhibitedTelecom
    }
}

/// Foreign government entity information
public struct ForeignGovernmentEntity: Codable, Sendable, Equatable {
    public let name: String
    public let country: String
    public let interestType: String?
    public let ownershipPercentage: String?
    public let controlDescription: String?
    
    public init(name: String, country: String, interestType: String? = nil, ownershipPercentage: String? = nil, controlDescription: String? = nil) {
        self.name = name
        self.country = country
        self.interestType = interestType
        self.ownershipPercentage = ownershipPercentage
        self.controlDescription = controlDescription
    }
}

/// Responsibility and qualification information
public struct ResponsibilityInformation: Codable, Sendable {
    public let hasDelinquentFederalDebt: Bool?
    public let hasUnpaidTaxLiability: Bool?
    public let integrityRecords: [IntegrityRecord]
    
    public init(hasDelinquentFederalDebt: Bool? = nil, hasUnpaidTaxLiability: Bool? = nil, integrityRecords: [IntegrityRecord] = []) {
        self.hasDelinquentFederalDebt = hasDelinquentFederalDebt
        self.hasUnpaidTaxLiability = hasUnpaidTaxLiability
        self.integrityRecords = integrityRecords
    }
}

/// Integrity record information
public struct IntegrityRecord: Codable, Sendable {
    public let proceedingType: String?
    public let proceedingDescription: String?
    public let agency: String?
    
    public init(proceedingType: String? = nil, proceedingDescription: String? = nil, agency: String? = nil) {
        self.proceedingType = proceedingType
        self.proceedingDescription = proceedingDescription
        self.agency = agency
    }
}

/// Architect-Engineer qualifications
public struct ArchitectEngineerQualifications: Codable, Sendable {
    public let hasArchitectEngineerResponses: Bool
    public let hasSF330Filed: Bool
    public let disciplines: [String]
    
    public init(hasArchitectEngineerResponses: Bool = false, hasSF330Filed: Bool = false, disciplines: [String] = []) {
        self.hasArchitectEngineerResponses = hasArchitectEngineerResponses
        self.hasSF330Filed = hasSF330Filed
        self.disciplines = disciplines
    }
}

/// Physical address information
public struct PhysicalAddress: Codable, Sendable {
    public let streetAddress: String?
    public let city: String?
    public let state: String?
    public let zipCode: String?
    public let country: String?
    
    public init(streetAddress: String? = nil, city: String? = nil, state: String? = nil, zipCode: String? = nil, country: String? = nil) {
        self.streetAddress = streetAddress
        self.city = city
        self.state = state
        self.zipCode = zipCode
        self.country = country
    }
}

// MARK: - Errors

/// SAM.gov service errors
public enum SAMGovError: Error, LocalizedError, Sendable {
    case invalidAPIKey
    case entityNotFound
    case networkError(String)
    case invalidResponse
    case rateLimitExceeded
    case apiKeyRequired
    
    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid or missing SAM.gov API key"
        case .entityNotFound:
            return "Entity not found in SAM.gov database"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from SAM.gov API"
        case .rateLimitExceeded:
            return "API rate limit exceeded"
        case .apiKeyRequired:
            return "SAM.gov API key is required"
        }
    }
}

// MARK: - Repository

/// Repository for SAM.gov data operations
public actor SAMGovRepository {
    private let apiKey: String
    private let baseURL = "https://api.sam.gov/entity-information/v3"
    
    public init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    public func searchEntities(_ query: String) async throws -> EntitySearchResult {
        // Mock implementation for now
        let mockEntity = EntitySummary(
            ueiSAM: "MOCK123456789",
            entityName: query,
            cageCode: "MOCK1",
            registrationStatus: "Active"
        )
        
        return EntitySearchResult(entities: [mockEntity], totalCount: 1)
    }
    
    public func getEntityByCAGE(_ cageCode: String) async throws -> EntityDetail {
        // Mock implementation
        return EntityDetail(
            ueiSAM: "MOCK123456789",
            entityName: "Mock Entity for CAGE \(cageCode)",
            legalBusinessName: "Mock Entity for CAGE \(cageCode)",
            cageCode: cageCode,
            registrationStatus: "Active",
            businessTypes: ["Small Business"],
            address: EntityAddress(
                line1: "123 Mock Street",
                city: "Mock City",
                state: "VA",
                zipCode: "12345"
            )
        )
    }
    
    public func getEntityByUEI(_ uei: String) async throws -> EntityDetail {
        // Mock implementation
        return EntityDetail(
            ueiSAM: uei,
            entityName: "Mock Entity for UEI \(uei)",
            legalBusinessName: "Mock Entity for UEI \(uei)",
            cageCode: "MOCK1",
            registrationStatus: "Active",
            businessTypes: ["Small Business"],
            address: EntityAddress(
                line1: "123 Mock Street",
                city: "Mock City",
                state: "VA",
                zipCode: "12345"
            )
        )
    }
}

// MARK: - Live Implementation

public extension SAMGovService {
    static let live: SAMGovService = SAMGovService(
        searchEntity: { query in
            // Mock implementation
            let mockEntity = EntitySummary(
                ueiSAM: "MOCK123456789",
                entityName: query,
                cageCode: "MOCK1",
                registrationStatus: "Active"
            )
            return EntitySearchResult(entities: [mockEntity], totalCount: 1)
        },
        getEntityByCAGE: { cageCode in
            EntityDetail(
                ueiSAM: "MOCK123456789",
                entityName: "Mock Entity for CAGE \(cageCode)",
                legalBusinessName: "Mock Entity for CAGE \(cageCode)",
                cageCode: cageCode,
                registrationStatus: "Active"
            )
        },
        getEntityByUEI: { uei in
            EntityDetail(
                ueiSAM: uei,
                entityName: "Mock Entity for UEI \(uei)",
                legalBusinessName: "Mock Entity for UEI \(uei)",
                cageCode: "MOCK1",
                registrationStatus: "Active"
            )
        }
    )
}

// MARK: - Dependency Registration

extension SAMGovService: DependencyKey {
    public static let liveValue = SAMGovService.live
}

public extension DependencyValues {
    var samGovService: SAMGovService {
        get { self[SAMGovService.self] }
        set { self[SAMGovService.self] = newValue }
    }
}