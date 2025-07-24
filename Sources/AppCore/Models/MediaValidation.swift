import Foundation

// MARK: - Media Management Validation Types

/// Media validation result from MediaValidationClient operations
public struct MediaClientValidationResult: Sendable, Codable, Equatable {
    public let isValid: Bool
    public let issues: [String]?
    public let warnings: [String]?
    
    public init(
        isValid: Bool,
        issues: [String]? = nil,
        warnings: [String]? = nil
    ) {
        self.isValid = isValid
        self.issues = issues
        self.warnings = warnings
    }
}

/// Asset validation result for media management feature with additional context
public struct AssetValidationResult: Sendable, Codable, Equatable {
    public let isValid: Bool
    public let issues: [String]
    public let assetId: UUID
    public let validatedAt: Date
    
    public init(
        isValid: Bool,
        issues: [String] = [],
        assetId: UUID,
        validatedAt: Date = Date()
    ) {
        self.isValid = isValid
        self.issues = issues
        self.assetId = assetId
        self.validatedAt = validatedAt
    }
}