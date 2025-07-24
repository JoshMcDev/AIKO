import AppCore
import Combine
import CoreData
import Foundation

// MARK: - Adaptive Data Extraction System

/// Dynamic value object that can represent any extracted data
public struct DynamicValueObject: Codable, Hashable, Sendable {
    let id: UUID
    let fieldName: String
    let value: String
    let dataType: DataType
    let confidence: Double
    let extractionPattern: String?
    let documentContext: DocumentContext
    let timestamp: Date

    public enum DataType: String, Codable, Sendable {
        case text
        case number
        case currency
        case date
        case email
        case phone
        case percentage
        case boolean
        case array
        case object
    }

    public init(
        fieldName: String,
        value: String,
        dataType: DataType,
        confidence: Double = 1.0,
        extractionPattern: String? = nil,
        documentContext: DocumentContext
    ) {
        id = UUID()
        self.fieldName = fieldName
        self.value = value
        self.dataType = dataType
        self.confidence = confidence
        self.extractionPattern = extractionPattern
        self.documentContext = documentContext
        timestamp = Date()
    }
}

/// Context about where the value was found
public struct DocumentContext: Codable, Hashable, Sendable {
    let documentType: String
    let section: String?
    let lineNumber: Int?
    let surroundingText: String?
    let relatedFields: [String]
}

/// Pattern learned from repeated extractions
public struct LearnedPattern: Codable, Sendable {
    let id: UUID
    let patternName: String
    let fieldMappings: [FieldMapping]
    let documentTypeSignatures: [String]
    let occurrenceCount: Int
    let averageConfidence: Double
    let lastSeen: Date

    struct FieldMapping: Codable, Sendable {
        let standardFieldName: String
        let variations: [String]
        let extractionRegex: String?
        let expectedDataType: DynamicValueObject.DataType
        let isRequired: Bool
        let defaultValue: String?
    }
}

/// Adaptive data extractor that learns from patterns
public class AdaptiveDataExtractor: @unchecked Sendable {
    public static let shared = AdaptiveDataExtractor()

    private let patternLearner: PatternLearner
    private let fieldNormalizer: FieldNormalizer

    // Learned patterns cache
    private var learnedPatterns: [String: LearnedPattern] = [:]
    private let patternUpdateSubject = PassthroughSubject<LearnedPattern, Never>()

    public init() {
        patternLearner = PatternLearner()
        fieldNormalizer = FieldNormalizer()

        Task { @MainActor in
            loadLearnedPatterns()
        }
    }

    // MARK: - Main Extraction Method

    public func extractAdaptively(
        from document: ParsedDocument,
        withHints _: [String: Any]? = nil
    ) async throws -> AdaptiveExtractionResult {
        // 1. Identify document type signature
        let documentSignature = try await identifyDocumentSignature(document)

        // 2. Check for learned patterns
        let applicablePatterns = findApplicablePatterns(for: documentSignature)

        // 3. Extract using patterns + discovery
        var extractedObjects: [DynamicValueObject] = []

        // Apply learned patterns first (high confidence)
        if !applicablePatterns.isEmpty {
            extractedObjects += try await applyLearnedPatterns(
                applicablePatterns,
                to: document
            )
        }

        // Discover new fields
        let discoveredObjects = try await discoverNewFields(
            in: document,
            excluding: extractedObjects.map(\.fieldName)
        )
        extractedObjects += discoveredObjects

        // 4. Normalize field names
        extractedObjects = normalizeFieldNames(extractedObjects)

        // 5. Learn from this extraction
        await updatePatternLearning(
            from: extractedObjects,
            documentSignature: documentSignature
        )

        // 6. Map to database
        let databaseMappings = try await mapToDatabase(extractedObjects)

        return AdaptiveExtractionResult(
            valueObjects: extractedObjects,
            documentSignature: documentSignature,
            appliedPatterns: applicablePatterns.map(\.patternName),
            databaseMappings: databaseMappings,
            confidence: calculateOverallConfidence(extractedObjects)
        )
    }

    // MARK: - Document Signature Identification

    private func identifyDocumentSignature(_ document: ParsedDocument) async throws -> String {
        var signatureComponents: [String] = []

        // Analyze document structure
        let text = document.extractedText.lowercased()

        // Common quote indicators
        if text.contains("quote") || text.contains("quotation") || text.contains("estimate") {
            signatureComponents.append("quote")
        }

        // Government/Military indicators
        if text.contains("gfe") || text.contains("haipe") || text.contains("mil-") {
            signatureComponents.append("government")
        }

        // Vendor patterns
        if text.contains("vendor") || text.contains("company") || text.contains("llc") {
            signatureComponents.append("vendor")
        }

        // Technical equipment
        if text.contains("chassis") || text.contains("module") || text.contains("device") {
            signatureComponents.append("technical_equipment")
        }

        // Pricing indicators
        if text.contains("$") || text.contains("total") || text.contains("price") {
            signatureComponents.append("pricing")
        }

        return signatureComponents.joined(separator: "_")
    }

    // MARK: - Pattern Application

    private func applyLearnedPatterns(
        _ patterns: [LearnedPattern],
        to document: ParsedDocument
    ) async throws -> [DynamicValueObject] {
        var results: [DynamicValueObject] = []

        for pattern in patterns {
            for mapping in pattern.fieldMappings {
                if let value = try extractFieldUsingMapping(mapping, from: document) {
                    let context = DocumentContext(
                        documentType: document.sourceType.rawValue,
                        section: nil,
                        lineNumber: nil,
                        surroundingText: nil,
                        relatedFields: pattern.fieldMappings.map(\.standardFieldName)
                    )

                    results.append(DynamicValueObject(
                        fieldName: mapping.standardFieldName,
                        value: value,
                        dataType: mapping.expectedDataType,
                        confidence: pattern.averageConfidence,
                        extractionPattern: mapping.extractionRegex,
                        documentContext: context
                    ))
                }
            }
        }

        return results
    }

    // MARK: - Field Discovery

    private func discoverNewFields(
        in document: ParsedDocument,
        excluding existingFields: [String]
    ) async throws -> [DynamicValueObject] {
        var discovered: [DynamicValueObject] = []
        let lines = document.extractedText.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            // Look for key-value patterns
            let keyValuePatterns = [
                "([A-Za-z\\s]+):\\s*(.+)",
                "([A-Z][A-Za-z\\s]+)\\s+(.+)",
                "([A-Za-z\\s]+)\\s*=\\s*(.+)",
            ]

            for pattern in keyValuePatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(
                       in: line,
                       options: [],
                       range: NSRange(line.startIndex..., in: line)
                   ) {
                    if let keyRange = Range(match.range(at: 1), in: line),
                       let valueRange = Range(match.range(at: 2), in: line) {
                        let key = String(line[keyRange]).trimmingCharacters(in: .whitespaces)
                        let value = String(line[valueRange]).trimmingCharacters(in: .whitespaces)

                        // Skip if already extracted
                        let normalizedKey = fieldNormalizer.normalize(key)
                        if existingFields.contains(normalizedKey) { continue }

                        // Determine data type
                        let dataType = inferDataType(from: value)

                        let context = DocumentContext(
                            documentType: document.sourceType.rawValue,
                            section: determineSectionFromLine(index, in: lines),
                            lineNumber: index,
                            surroundingText: extractSurroundingContext(
                                at: index,
                                from: lines
                            ),
                            relatedFields: []
                        )

                        discovered.append(DynamicValueObject(
                            fieldName: normalizedKey,
                            value: value,
                            dataType: dataType,
                            confidence: 0.7, // Lower confidence for discovered fields
                            extractionPattern: pattern,
                            documentContext: context
                        ))
                    }
                }
            }
        }

        return discovered
    }

    // MARK: - Data Type Inference

    private func inferDataType(from value: String) -> DynamicValueObject.DataType {
        // Currency
        if value.contains("$") || value.contains("USD") {
            return .currency
        }

        // Date patterns
        let datePatterns = [
            "\\d{1,2}/\\d{1,2}/\\d{2,4}",
            "\\d{4}-\\d{2}-\\d{2}",
            "\\w+ \\d{1,2}, \\d{4}",
        ]
        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               regex.firstMatch(in: value, options: [], range: NSRange(value.startIndex..., in: value)) != nil {
                return .date
            }
        }

        // Email
        if value.contains("@"), value.contains(".") {
            return .email
        }

        // Phone
        let phoneRegex = try? NSRegularExpression(
            pattern: "\\(?\\d{3}\\)?[\\s.-]?\\d{3}[\\s.-]?\\d{4}",
            options: []
        )
        if let regex = phoneRegex,
           regex.firstMatch(in: value, options: [], range: NSRange(value.startIndex..., in: value)) != nil {
            return .phone
        }

        // Number
        if Double(value.replacingOccurrences(of: ",", with: "")) != nil {
            return .number
        }

        // Percentage
        if value.contains("%") {
            return .percentage
        }

        // Boolean
        let booleanValues = ["yes", "no", "true", "false", "y", "n"]
        if booleanValues.contains(value.lowercased()) {
            return .boolean
        }

        // Default to text
        return .text
    }

    // MARK: - Pattern Learning

    private func updatePatternLearning(
        from objects: [DynamicValueObject],
        documentSignature: String
    ) async {
        // Group objects by similar structure
        let objectGroups = groupSimilarObjects(objects)

        for group in objectGroups {
            // Check if this matches an existing pattern
            var matchedPattern: LearnedPattern?

            for (_, pattern) in learnedPatterns where patternMatches(group, pattern: pattern) {
                matchedPattern = pattern
                break
            }

            if var pattern = matchedPattern {
                // Update existing pattern
                pattern = updatePattern(pattern, with: group, signature: documentSignature)
                learnedPatterns[pattern.patternName] = pattern
            } else {
                // Create new pattern
                let newPattern = createPattern(from: group, signature: documentSignature)
                learnedPatterns[newPattern.patternName] = newPattern
            }
        }

        // Persist patterns
        await saveLearnedPatterns()
    }

    // MARK: - Database Mapping

    @MainActor
    private func mapToDatabase(_ objects: [DynamicValueObject]) async throws -> [DatabaseMapping] {
        var mappings: [DatabaseMapping] = []

        // Group related objects
        let documentData = DocumentData(context: CoreDataManager.shared.viewContext)
        documentData.id = UUID()
        documentData.timestamp = Date()

        // Create flexible JSON structure
        var jsonData: [String: Any] = [:]

        for object in objects {
            switch object.dataType {
            case .currency, .number:
                if let numericValue = Double(object.value.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) {
                    jsonData[object.fieldName] = numericValue
                }
            case .date:
                jsonData[object.fieldName] = object.value // Store as string, parse when needed
            case .boolean:
                jsonData[object.fieldName] = ["yes", "true", "y"].contains(object.value.lowercased())
            case .array:
                jsonData[object.fieldName] = object.value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            default:
                jsonData[object.fieldName] = object.value
            }
        }

        // Store as JSON
        documentData.extractedData = try JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted)

        // Create searchable attributes
        for object in objects {
            let attribute = DocumentAttribute(context: CoreDataManager.shared.viewContext)
            attribute.id = UUID()
            attribute.fieldName = object.fieldName
            attribute.fieldValue = object.value
            attribute.dataType = object.dataType.rawValue
            attribute.confidence = object.confidence
            attribute.document = documentData

            mappings.append(DatabaseMapping(
                fieldName: object.fieldName,
                tableName: "DocumentAttribute",
                columnName: "fieldValue",
                dataType: object.dataType
            ))
        }

        try CoreDataManager.shared.viewContext.save()

        return mappings
    }

    // MARK: - Helper Methods

    private func extractFieldUsingMapping(
        _ mapping: LearnedPattern.FieldMapping,
        from document: ParsedDocument
    ) throws -> String? {
        let text = document.extractedText

        // Try regex extraction first
        if let regexPattern = mapping.extractionRegex,
           let regex = try? NSRegularExpression(pattern: regexPattern, options: .caseInsensitive) {
            if let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
                if match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: text) {
                    return String(text[range])
                }
            }
        }

        // Try variations
        for variation in mapping.variations {
            let searchPattern = "\(variation):?\\s*([^\\n]+)"
            if let regex = try? NSRegularExpression(pattern: searchPattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
                if let range = Range(match.range(at: 1), in: text) {
                    return String(text[range]).trimmingCharacters(in: .whitespaces)
                }
            }
        }

        return mapping.defaultValue
    }

    private func normalizeFieldNames(_ objects: [DynamicValueObject]) -> [DynamicValueObject] {
        objects.map { object in
            var normalized = object
            normalized = DynamicValueObject(
                fieldName: fieldNormalizer.normalize(object.fieldName),
                value: object.value,
                dataType: object.dataType,
                confidence: object.confidence,
                extractionPattern: object.extractionPattern,
                documentContext: object.documentContext
            )
            return normalized
        }
    }

    private func calculateOverallConfidence(_ objects: [DynamicValueObject]) -> Double {
        guard !objects.isEmpty else { return 0.0 }
        let totalConfidence = objects.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Double(objects.count)
    }

    private func findApplicablePatterns(for signature: String) -> [LearnedPattern] {
        learnedPatterns.values.filter { pattern in
            pattern.documentTypeSignatures.contains(signature) ||
                pattern.documentTypeSignatures.contains { signature.contains($0) }
        }
    }

    private func determineSectionFromLine(_ lineIndex: Int, in lines: [String]) -> String? {
        // Look backwards for section headers
        for i in (0 ..< lineIndex).reversed() {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            // Common section indicators
            if line.allSatisfy({ $0.isUppercase || $0.isWhitespace }), line.count > 3 {
                return line
            }
            if line.hasSuffix(":"), line.count < 50 {
                return line.replacingOccurrences(of: ":", with: "")
            }
        }
        return nil
    }

    private func extractSurroundingContext(at index: Int, from lines: [String]) -> String {
        let contextRange = max(0, index - 2) ... min(lines.count - 1, index + 2)
        return lines[contextRange].joined(separator: " | ")
    }

    // MARK: - Persistence

    private func loadLearnedPatterns() {
        // Load from Core Data or JSON file
        if let data = UserDefaults.standard.data(forKey: "LearnedPatterns"),
           let patterns = try? JSONDecoder().decode([String: LearnedPattern].self, from: data) {
            learnedPatterns = patterns
        }
    }

    private func saveLearnedPatterns() async {
        if let data = try? JSONEncoder().encode(learnedPatterns) {
            UserDefaults.standard.set(data, forKey: "LearnedPatterns")
        }
    }

    // MARK: - Pattern Matching Helpers

    private func groupSimilarObjects(_ objects: [DynamicValueObject]) -> [[DynamicValueObject]] {
        // Group by similar field sets
        var groups: [[DynamicValueObject]] = []

        // Simple grouping by document context
        let groupedByContext = Dictionary(grouping: objects) { $0.documentContext.documentType }
        groups = Array(groupedByContext.values)

        return groups
    }

    private func patternMatches(_ objects: [DynamicValueObject], pattern: LearnedPattern) -> Bool {
        let objectFieldNames = Set(objects.map(\.fieldName))
        let patternFieldNames = Set(pattern.fieldMappings.map(\.standardFieldName))

        // Check if at least 70% of pattern fields are present
        let intersection = objectFieldNames.intersection(patternFieldNames)
        return Double(intersection.count) / Double(patternFieldNames.count) >= 0.7
    }

    private func updatePattern(
        _ pattern: LearnedPattern,
        with objects: [DynamicValueObject],
        signature: String
    ) -> LearnedPattern {
        var updated = pattern

        // Update occurrence count
        updated = LearnedPattern(
            id: pattern.id,
            patternName: pattern.patternName,
            fieldMappings: pattern.fieldMappings,
            documentTypeSignatures: Array(Set(pattern.documentTypeSignatures + [signature])),
            occurrenceCount: pattern.occurrenceCount + 1,
            averageConfidence: (pattern.averageConfidence * Double(pattern.occurrenceCount) + calculateOverallConfidence(objects)) / Double(pattern.occurrenceCount + 1),
            lastSeen: Date()
        )

        return updated
    }

    private func createPattern(
        from objects: [DynamicValueObject],
        signature: String
    ) -> LearnedPattern {
        let mappings = objects.map { object in
            LearnedPattern.FieldMapping(
                standardFieldName: object.fieldName,
                variations: [object.fieldName],
                extractionRegex: object.extractionPattern,
                expectedDataType: object.dataType,
                isRequired: object.confidence > 0.8,
                defaultValue: nil
            )
        }

        return LearnedPattern(
            id: UUID(),
            patternName: "Pattern_\(signature)_\(Date().timeIntervalSince1970)",
            fieldMappings: mappings,
            documentTypeSignatures: [signature],
            occurrenceCount: 1,
            averageConfidence: calculateOverallConfidence(objects),
            lastSeen: Date()
        )
    }
}

// MARK: - Supporting Types

public struct AdaptiveExtractionResult: Sendable {
    public let valueObjects: [DynamicValueObject]
    public let documentSignature: String
    public let appliedPatterns: [String]
    public let databaseMappings: [DatabaseMapping]
    public let confidence: Double
}

public struct DatabaseMapping: Sendable {
    public let fieldName: String
    public let tableName: String
    public let columnName: String
    public let dataType: DynamicValueObject.DataType
}

// MARK: - Field Normalizer

final class FieldNormalizer: @unchecked Sendable {
    private let synonymGroups: [[String]] = [
        ["vendor", "company", "supplier", "contractor", "seller"],
        ["quote", "quotation", "estimate", "proposal", "bid"],
        ["price", "cost", "amount", "total", "sum"],
        ["date", "dated", "issued", "created"],
        ["email", "e-mail", "electronic_mail", "contact_email"],
        ["phone", "telephone", "tel", "mobile", "cell"],
        ["address", "location", "street", "addr"],
        ["item", "product", "line_item", "sku", "part"],
        ["quantity", "qty", "count", "amount", "units"],
        ["delivery", "shipping", "freight", "transport"],
        ["payment", "terms", "payment_terms", "net"],
        ["valid", "expires", "valid_until", "expiration"],
    ]

    func normalize(_ fieldName: String) -> String {
        let cleaned = fieldName
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "#", with: "number")

        // Check synonym groups
        for group in synonymGroups where group.contains(where: { cleaned.contains($0) }) {
            return group[0] // Return the canonical form
        }

        return cleaned
    }
}

// MARK: - Pattern Learner

final class PatternLearner: @unchecked Sendable {
    func analyzePatterns(in _: [ParsedDocument]) -> [LearnedPattern] {
        // Implementation for batch pattern learning
        []
    }
}
