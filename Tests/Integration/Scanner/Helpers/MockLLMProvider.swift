@testable import AppCoreiOS
@testable import AppCore
import ComposableArchitecture
import Foundation

/// Mock LLM provider for testing form auto-population workflows
/// Provides standardized responses for different document types with error injection capabilities
public final class MockLLMProvider: Sendable {
    // MARK: - Response Configuration

    public struct Configuration: Sendable {
        public let responseDelay: TimeInterval
        public let successRate: Double
        public let confidenceRange: ClosedRange<Double>
        public let shouldInjectErrors: Bool
        public let maxRetries: Int

        public init(
            responseDelay: TimeInterval = 0.5,
            successRate: Double = 0.9,
            confidenceRange: ClosedRange<Double> = 0.7 ... 0.95,
            shouldInjectErrors: Bool = false,
            maxRetries: Int = 3
        ) {
            self.responseDelay = responseDelay
            self.successRate = successRate
            self.confidenceRange = confidenceRange
            self.shouldInjectErrors = shouldInjectErrors
            self.maxRetries = maxRetries
        }

        public static let `default` = Configuration()
        public static let highAccuracy = Configuration(
            successRate: 0.98,
            confidenceRange: 0.9 ... 0.99
        )
        public static let lowAccuracy = Configuration(
            successRate: 0.6,
            confidenceRange: 0.4 ... 0.7,
            shouldInjectErrors: true
        )
        public static let errorProne = Configuration(
            successRate: 0.3,
            confidenceRange: 0.2 ... 0.5,
            shouldInjectErrors: true
        )
    }

    // MARK: - Error Types

    public enum LLMError: Error, Sendable {
        case rateLimited
        case invalidResponse
        case networkTimeout
        case insufficientTokens
        case contentPolicyViolation
        case serviceUnavailable

        var localizedDescription: String {
            switch self {
            case .rateLimited:
                "Rate limit exceeded"
            case .invalidResponse:
                "Invalid response format"
            case .networkTimeout:
                "Network request timed out"
            case .insufficientTokens:
                "Insufficient tokens for request"
            case .contentPolicyViolation:
                "Content policy violation"
            case .serviceUnavailable:
                "Service temporarily unavailable"
            }
        }
    }

    // MARK: - Response Types

    public struct FormExtractionResponse: Sendable {
        public let extractedFields: [String: String]
        public let confidence: Double
        public let processingTime: TimeInterval
        public let suggestedMappings: [FieldMapping]
        public let warnings: [String]

        public init(
            extractedFields: [String: String],
            confidence: Double,
            processingTime: TimeInterval = 0.5,
            suggestedMappings: [FieldMapping] = [],
            warnings: [String] = []
        ) {
            self.extractedFields = extractedFields
            self.confidence = confidence
            self.processingTime = processingTime
            self.suggestedMappings = suggestedMappings
            self.warnings = warnings
        }
    }

    public struct FieldMapping: Sendable {
        public let sourceField: String
        public let targetField: String
        public let confidence: Double
        public let transformationType: String

        public init(sourceField: String, targetField: String, confidence: Double, transformationType: String = "direct") {
            self.sourceField = sourceField
            self.targetField = targetField
            self.confidence = confidence
            self.transformationType = transformationType
        }
    }

    // MARK: - Properties

    public let configuration: Configuration
    private let responsePatterns: [String: FormExtractionResponse]
    private var callCount: Int = 0
    private var errorInjectionCounter: Int = 0

    // MARK: - Initialization

    public init(configuration: Configuration = .default) {
        self.configuration = configuration
        responsePatterns = Self.buildResponsePatterns(configuration: configuration)
    }

    // MARK: - Public Interface

    /// Extract form fields from OCR text using mock LLM processing
    /// - Parameters:
    ///   - ocrText: Raw OCR text from document
    ///   - formType: Expected form type (SF-18, SF-26, DD-1155)
    ///   - targetSchema: Expected field schema
    /// - Returns: FormExtractionResponse with extracted fields
    public func extractFormFields(
        from ocrText: String,
        formType: String,
        targetSchema: [String]
    ) async throws -> FormExtractionResponse {
        callCount += 1

        // Simulate processing delay
        try await Task.sleep(for: .milliseconds(Int(configuration.responseDelay * 1000)))

        // Inject errors if configured
        if configuration.shouldInjectErrors {
            try injectRandomError()
        }

        // Check success rate
        if Double.random(in: 0 ... 1) > configuration.successRate {
            throw LLMError.invalidResponse
        }

        // Return appropriate response based on form type
        return getResponseForFormType(formType, ocrText: ocrText, targetSchema: targetSchema)
    }

    /// Validate extracted field mappings
    /// - Parameters:
    ///   - mappings: Field mappings to validate
    ///   - formType: Form type for validation context
    /// - Returns: Validation result with confidence score
    public func validateFieldMappings(
        _ mappings: [FieldMapping],
        formType _: String
    ) async throws -> ValidationResult {
        // Simulate validation delay
        try await Task.sleep(for: .milliseconds(Int(configuration.responseDelay * 500)))

        let validMappings = mappings.filter { $0.confidence > 0.5 }
        let overallConfidence = validMappings.isEmpty ? 0.0 :
            validMappings.map(\.confidence).reduce(0, +) / Double(validMappings.count)

        return ValidationResult(
            isValid: overallConfidence > 0.7,
            confidence: overallConfidence,
            validatedMappings: validMappings,
            issues: generateValidationIssues(for: mappings)
        )
    }

    /// Get confidence score for a specific field extraction
    /// - Parameters:
    ///   - fieldName: Name of the field
    ///   - extractedValue: Extracted value
    ///   - context: Additional context
    /// - Returns: Confidence score (0.0 to 1.0)
    public func getFieldConfidence(
        fieldName: String,
        extractedValue: String,
        context _: [String: Any] = [:]
    ) async -> Double {
        // Simulate confidence calculation based on field type and value
        let baseConfidence = Double.random(in: configuration.confidenceRange)

        // Adjust based on field characteristics
        var adjustedConfidence = baseConfidence

        // Date fields typically have higher confidence if formatted correctly
        if fieldName.lowercased().contains("date") {
            adjustedConfidence *= extractedValue.contains("/") ? 1.1 : 0.8
        }

        // ID fields have high confidence if alphanumeric
        if fieldName.lowercased().contains("id") {
            adjustedConfidence *= extractedValue.allSatisfy { $0.isLetter || $0.isNumber } ? 1.2 : 0.7
        }

        // Name fields have moderate confidence
        if fieldName.lowercased().contains("name") {
            adjustedConfidence *= extractedValue.contains(" ") ? 1.0 : 0.9
        }

        return min(adjustedConfidence, 1.0)
    }

    // MARK: - Test Utilities

    /// Reset call count and error injection state
    public func resetState() {
        callCount = 0
        errorInjectionCounter = 0
    }

    /// Get current call statistics
    public var statistics: CallStatistics {
        CallStatistics(
            totalCalls: callCount,
            errorInjections: errorInjectionCounter,
            successRate: configuration.successRate
        )
    }

    // MARK: - Private Implementation

    private func injectRandomError() throws {
        errorInjectionCounter += 1

        // Inject errors based on probability
        let errorProbability = 1.0 - configuration.successRate
        if Double.random(in: 0 ... 1) < errorProbability {
            let errors: [LLMError] = [.rateLimited, .networkTimeout, .serviceUnavailable, .invalidResponse]
            throw errors.randomElement() ?? .networkTimeout
        }
    }

    private func getResponseForFormType(
        _ formType: String,
        ocrText: String,
        targetSchema: [String]
    ) -> FormExtractionResponse {
        // Return pre-built response or generate one
        if let prebuiltResponse = responsePatterns[formType] {
            return prebuiltResponse
        }

        // Generate dynamic response based on OCR text analysis
        return generateResponseFromOCRText(ocrText, formType: formType, targetSchema: targetSchema)
    }

    private func generateResponseFromOCRText(
        _ ocrText: String,
        formType _: String,
        targetSchema: [String]
    ) -> FormExtractionResponse {
        var extractedFields: [String: String] = [:]
        var suggestedMappings: [FieldMapping] = []
        var warnings: [String] = []

        // Simple text analysis to extract field values
        let lines = ocrText.components(separatedBy: .newlines)

        for field in targetSchema {
            if let value = extractValueForField(field, from: lines) {
                extractedFields[field] = value
                suggestedMappings.append(
                    FieldMapping(
                        sourceField: field,
                        targetField: field,
                        confidence: Double.random(in: configuration.confidenceRange),
                        transformationType: "direct"
                    )
                )
            } else {
                warnings.append("Could not extract value for field: \(field)")
            }
        }

        let confidence = extractedFields.isEmpty ? 0.0 :
            Double.random(in: configuration.confidenceRange)

        return FormExtractionResponse(
            extractedFields: extractedFields,
            confidence: confidence,
            processingTime: configuration.responseDelay,
            suggestedMappings: suggestedMappings,
            warnings: warnings
        )
    }

    private func extractValueForField(_ fieldName: String, from lines: [String]) -> String? {
        let searchTerms = generateSearchTerms(for: fieldName)

        for line in lines {
            for term in searchTerms where line.lowercased().contains(term.lowercased()) {
                // Extract value after the field label
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    return components[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }

        return nil
    }

    private func generateSearchTerms(for fieldName: String) -> [String] {
        let baseTerm = fieldName.lowercased()
        var terms = [baseTerm]

        // Add variations
        terms.append(baseTerm.replacingOccurrences(of: " ", with: ""))
        terms.append(baseTerm.replacingOccurrences(of: "_", with: " "))

        // Add common abbreviations
        if baseTerm.contains("employee") {
            terms.append("emp")
        }
        if baseTerm.contains("identification") || baseTerm.contains("id") {
            terms.append("id")
        }
        if baseTerm.contains("department") {
            terms.append("dept")
        }

        return terms
    }

    private func generateValidationIssues(for mappings: [FieldMapping]) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        for mapping in mappings where mapping.confidence < 0.5 {
            issues.append(
                ValidationIssue(
                    fieldName: mapping.sourceField,
                    issueType: .lowConfidence,
                    description: "Low confidence score: \(mapping.confidence)",
                    severity: .warning
                )
            )
        }

        return issues
    }

    private static func buildResponsePatterns(configuration: Configuration) -> [String: FormExtractionResponse] {
        var patterns: [String: FormExtractionResponse] = [:]

        // SF-18 Pattern
        patterns["SF-18"] = FormExtractionResponse(
            extractedFields: [
                "Employee Name": "John A. Smith",
                "Employee ID": "EMP123456",
                "Department": "Information Technology",
                "Position Title": "Systems Analyst II",
                "Request Date": "03/15/2024",
                "Supervisor Name": "Jane M. Johnson",
                "Reason for Request": "Position reclassification review",
            ],
            confidence: Double.random(in: configuration.confidenceRange),
            suggestedMappings: [
                FieldMapping(sourceField: "Employee Name", targetField: "employeeName", confidence: 0.95),
                FieldMapping(sourceField: "Employee ID", targetField: "employeeId", confidence: 0.98),
                FieldMapping(sourceField: "Department", targetField: "department", confidence: 0.92),
            ]
        )

        // SF-26 Pattern
        patterns["SF-26"] = FormExtractionResponse(
            extractedFields: [
                "Requestor Name": "Michael R. Davis",
                "Organization": "Federal Aviation Administration",
                "Job Title": "Air Traffic Controller",
                "Analysis Type": "Classification Review",
                "Priority Level": "High",
                "Due Date": "04/30/2024",
            ],
            confidence: Double.random(in: configuration.confidenceRange)
        )

        // DD-1155 Pattern
        patterns["DD-1155"] = FormExtractionResponse(
            extractedFields: [
                "Service Member Name": "SSgt Robert K. Wilson",
                "Rank/Grade": "E-5",
                "Unit": "23rd Fighter Wing",
                "Request Date": "03/20/2024",
                "Items Requested": "MRE Meals, Type A Rations",
                "Quantity": "50 units",
                "Authorizing Officer": "Capt. Sarah L. Martinez",
            ],
            confidence: Double.random(in: configuration.confidenceRange)
        )

        return patterns
    }
}

// MARK: - Supporting Types

public struct ValidationResult: Sendable {
    public let isValid: Bool
    public let confidence: Double
    public let validatedMappings: [MockLLMProvider.FieldMapping]
    public let issues: [ValidationIssue]

    public init(isValid: Bool, confidence: Double, validatedMappings: [MockLLMProvider.FieldMapping], issues: [ValidationIssue]) {
        self.isValid = isValid
        self.confidence = confidence
        self.validatedMappings = validatedMappings
        self.issues = issues
    }
}

public struct ValidationIssue: Sendable {
    public let fieldName: String
    public let issueType: IssueType
    public let description: String
    public let severity: Severity

    public enum IssueType: String, Sendable {
        case lowConfidence = "low_confidence"
        case formatMismatch = "format_mismatch"
        case missingValue = "missing_value"
        case duplicateMapping = "duplicate_mapping"
    }

    public enum Severity: String, Sendable {
        case error
        case warning
        case info
    }

    public init(fieldName: String, issueType: IssueType, description: String, severity: Severity) {
        self.fieldName = fieldName
        self.issueType = issueType
        self.description = description
        self.severity = severity
    }
}

public struct CallStatistics: Sendable {
    public let totalCalls: Int
    public let errorInjections: Int
    public let successRate: Double

    public init(totalCalls: Int, errorInjections: Int, successRate: Double) {
        self.totalCalls = totalCalls
        self.errorInjections = errorInjections
        self.successRate = successRate
    }
}

// MARK: - Dependency Extensions

public extension MockLLMProvider {
    /// Create a dependency value for testing
    static var testValue: MockLLMProvider {
        MockLLMProvider(configuration: .default)
    }

    /// Create a high-accuracy dependency value for testing
    static var highAccuracyValue: MockLLMProvider {
        MockLLMProvider(configuration: .highAccuracy)
    }

    /// Create an error-prone dependency value for error testing
    static var errorProneValue: MockLLMProvider {
        MockLLMProvider(configuration: .errorProne)
    }
}
