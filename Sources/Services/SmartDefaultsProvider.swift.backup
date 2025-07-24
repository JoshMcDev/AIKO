import AppCore
import ComposableArchitecture
import Foundation

// MARK: - Smart Defaults Provider

/// Provides intelligent default values for forms based on context and learned patterns
public class SmartDefaultsProvider: @unchecked Sendable {
    /// Shared instance
    public static let shared = SmartDefaultsProvider()

    // MARK: - Types

    public struct SmartDefault: Equatable {
        public let field: String
        public let value: String
        public let confidence: Double
        public let source: DefaultSource
        public let reasoning: String
        public let alternatives: [Alternative]

        public struct Alternative: Equatable {
            public let value: String
            public let confidence: Double
        }

        public enum DefaultSource: String, Equatable {
            case documentExtraction = "document"
            case userPattern = "pattern"
            case organizationalRule = "rule"
            case historicalData = "history"
            case contextInference = "inference"
        }
    }

    public struct DefaultsContext {
        public let userId: String
        public let organizationUnit: String
        public let acquisitionType: AcquisitionType?
        public let documentType: DocumentType?
        public let extractedData: [String: String]
        public let userPatterns: [UserPatternLearner.UserPattern]
        public let organizationalRules: [OrganizationalRule]
        public let timeContext: TimeContext
    }

    public struct TimeContext {
        public let currentDate: Date
        public let fiscalYear: String
        public let quarter: String
        public let isEndOfFiscalYear: Bool
        public let daysUntilFYEnd: Int
    }

    public struct OrganizationalRule: Equatable, Sendable {
        public let field: String
        public let condition: String
        public let value: String
        public let priority: Int
    }

    // MARK: - Properties

    private let patternLearner: UserPatternLearner
    private let contextExtractor: DocumentContextExtractorEnhanced
    private let ruleEngine: OrganizationalRuleEngine

    // MARK: - Initialization

    public init() {
        patternLearner = UserPatternLearner()
        contextExtractor = DocumentContextExtractorEnhanced()
        ruleEngine = OrganizationalRuleEngine()
    }

    // MARK: - Public Methods

    /// Get smart defaults for a form
    public func getSmartDefaults(
        for formType: DocumentType,
        context: DefaultsContext
    ) async -> [SmartDefault] {
        var defaults: [SmartDefault] = []

        // Get form fields that need defaults
        let formFields = getFieldsForFormType(formType)

        // Process each field
        for field in formFields {
            if let smartDefault = await generateSmartDefault(
                for: field,
                formType: formType,
                context: context
            ) {
                defaults.append(smartDefault)
            }
        }

        // Sort by confidence
        return defaults.sorted { $0.confidence > $1.confidence }
    }

    /// Get a specific default value
    public func getDefault(
        for field: String,
        context: DefaultsContext
    ) async -> SmartDefault? {
        await generateSmartDefault(
            for: field,
            formType: context.documentType ?? .sow,
            context: context
        )
    }

    /// Validate and adjust defaults based on real-time constraints
    public func validateDefaults(
        _ defaults: [SmartDefault],
        against constraints: [FieldConstraint]
    ) async -> [SmartDefault] {
        var validatedDefaults: [SmartDefault] = []

        for defaultValue in defaults {
            if let constraint = constraints.first(where: { $0.field == defaultValue.field }) {
                if let validated = validateAndAdjust(defaultValue, constraint: constraint) {
                    validatedDefaults.append(validated)
                }
            } else {
                validatedDefaults.append(defaultValue)
            }
        }

        return validatedDefaults
    }

    // MARK: - Private Methods

    private func generateSmartDefault(
        for field: String,
        formType: DocumentType,
        context: DefaultsContext
    ) async -> SmartDefault? {
        // Priority order for default sources

        // 1. Check organizational rules
        if let ruleDefault = applyOrganizationalRules(
            field: field,
            context: context
        ) {
            return ruleDefault
        }

        // 2. Check extracted document data
        if let extractedDefault = checkExtractedData(
            field: field,
            extractedData: context.extractedData
        ) {
            return extractedDefault
        }

        // 3. Check user patterns
        if let patternDefault = await checkUserPatterns(
            field: field,
            patterns: context.userPatterns,
            context: context
        ) {
            return patternDefault
        }

        // 4. Apply context inference
        if let inferredDefault = inferFromContext(
            field: field,
            formType: formType,
            context: context
        ) {
            return inferredDefault
        }

        // 5. Use historical data
        if let historicalDefault = await getHistoricalDefault(
            field: field,
            context: context
        ) {
            return historicalDefault
        }

        return nil
    }

    private func applyOrganizationalRules(
        field: String,
        context: DefaultsContext
    ) -> SmartDefault? {
        let applicableRules = context.organizationalRules
            .filter { $0.field == field }
            .sorted { $0.priority > $1.priority }

        for rule in applicableRules where evaluateRuleCondition(rule.condition, context: context) {
            return SmartDefault(
                field: field,
                value: rule.value,
                confidence: 0.95,
                source: .organizationalRule,
                reasoning: "Organization policy requires: \(rule.condition)",
                alternatives: []
            )
        }

        return nil
    }

    private func checkExtractedData(
        field: String,
        extractedData: [String: String]
    ) -> SmartDefault? {
        // Map common field variations
        let fieldMappings = getFieldMappings(field)

        for mapping in fieldMappings {
            if let value = extractedData[mapping] {
                return SmartDefault(
                    field: field,
                    value: value,
                    confidence: 0.9,
                    source: .documentExtraction,
                    reasoning: "Extracted from uploaded document",
                    alternatives: []
                )
            }
        }

        return nil
    }

    private func checkUserPatterns(
        field: String,
        patterns: [UserPatternLearner.UserPattern],
        context _: DefaultsContext
    ) async -> SmartDefault? {
        let relevantPatterns = patterns
            .filter { $0.field == field }
            .sorted { $0.confidence > $1.confidence }

        guard let topPattern = relevantPatterns.first,
              topPattern.confidence >= 0.65
        else {
            return nil
        }

        let alternatives = Array(relevantPatterns.dropFirst().prefix(2)).map {
            SmartDefault.Alternative(
                value: $0.value,
                confidence: $0.confidence
            )
        }

        return SmartDefault(
            field: field,
            value: topPattern.value,
            confidence: topPattern.confidence,
            source: .userPattern,
            reasoning: "You usually select '\(topPattern.value)' (\(topPattern.occurrences) times)",
            alternatives: alternatives
        )
    }

    private func inferFromContext(
        field: String,
        formType: DocumentType,
        context: DefaultsContext
    ) -> SmartDefault? {
        switch field {
        case "deliveryDate", "requiredDate":
            inferDeliveryDate(context: context)

        case "fundingSource":
            inferFundingSource(context: context)

        case "priority":
            inferPriority(context: context)

        case "contractType":
            inferContractType(formType: formType, context: context)

        case "location":
            inferLocation(context: context)

        default:
            nil
        }
    }

    private func inferDeliveryDate(context: DefaultsContext) -> SmartDefault? {
        let calendar = Calendar.current
        var suggestedDate: Date
        var reasoning: String

        if context.timeContext.isEndOfFiscalYear {
            // Urgent delivery before FY end
            suggestedDate = calendar.date(
                byAdding: .day,
                value: min(30, context.timeContext.daysUntilFYEnd - 5),
                to: Date()
            ) ?? Date()
            reasoning = "End of fiscal year - expedited delivery recommended"
        } else {
            // Standard 30-day delivery
            suggestedDate = calendar.date(byAdding: .day, value: 30, to: Date()) ?? Date()
            reasoning = "Standard 30-day delivery window"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        return SmartDefault(
            field: "deliveryDate",
            value: formatter.string(from: suggestedDate),
            confidence: 0.75,
            source: .contextInference,
            reasoning: reasoning,
            alternatives: [
                SmartDefault.Alternative(
                    value: formatter.string(from: calendar.date(byAdding: .day, value: 45, to: Date()) ?? Date()),
                    confidence: 0.6
                ),
            ]
        )
    }

    private func inferFundingSource(context: DefaultsContext) -> SmartDefault? {
        var fundingSource: String
        var confidence: Double

        switch context.acquisitionType {
        case .commercialItem, .simplifiedAcquisition:
            fundingSource = "O&M \(context.timeContext.fiscalYear)"
            confidence = 0.8
        case .nonCommercialService, .majorSystem:
            fundingSource = "Services \(context.timeContext.fiscalYear)"
            confidence = 0.75
        case .constructionProject:
            fundingSource = "MILCON \(context.timeContext.fiscalYear)"
            confidence = 0.7
        default:
            fundingSource = "O&M \(context.timeContext.fiscalYear)"
            confidence = 0.6
        }

        return SmartDefault(
            field: "fundingSource",
            value: fundingSource,
            confidence: confidence,
            source: .contextInference,
            reasoning: "Based on acquisition type and current fiscal year",
            alternatives: []
        )
    }

    private func inferPriority(context: DefaultsContext) -> SmartDefault? {
        var priority: String
        var confidence: Double
        var reasoning: String

        if context.timeContext.isEndOfFiscalYear {
            priority = "Urgent"
            confidence = 0.85
            reasoning = "End of fiscal year - urgent processing recommended"
        } else if let value = context.extractedData["totalValue"],
                  let amount = parseAmount(value),
                  amount > 100_000 {
            priority = "High"
            confidence = 0.7
            reasoning = "High-value acquisition"
        } else {
            priority = "Routine"
            confidence = 0.75
            reasoning = "Standard processing timeline"
        }

        return SmartDefault(
            field: "priority",
            value: priority,
            confidence: confidence,
            source: .contextInference,
            reasoning: reasoning,
            alternatives: []
        )
    }

    private func inferContractType(
        formType: DocumentType,
        context: DefaultsContext
    ) -> SmartDefault? {
        switch formType {
        case .requestForQuote:
            return SmartDefault(
                field: "contractType",
                value: "Purchase Order",
                confidence: 0.8,
                source: .contextInference,
                reasoning: "Standard for purchase requests",
                alternatives: [
                    SmartDefault.Alternative(value: "BPA Call", confidence: 0.6),
                ]
            )

        case .contractScaffold:
            if let value = context.extractedData["estimatedValue"],
               let amount = parseAmount(value),
               amount > 250_000 {
                return SmartDefault(
                    field: "contractType",
                    value: "Fixed Price",
                    confidence: 0.75,
                    source: .contextInference,
                    reasoning: "Recommended for high-value acquisitions",
                    alternatives: [
                        SmartDefault.Alternative(value: "Cost Plus", confidence: 0.5),
                    ]
                )
            }

        default:
            break
        }

        return nil
    }

    private func inferLocation(context: DefaultsContext) -> SmartDefault? {
        if !context.organizationUnit.isEmpty {
            let unit = context.organizationUnit
            return SmartDefault(
                field: "location",
                value: unit,
                confidence: 0.9,
                source: .contextInference,
                reasoning: "Your organizational unit",
                alternatives: []
            )
        }

        return nil
    }

    private func getHistoricalDefault(
        field _: String,
        context _: DefaultsContext
    ) async -> SmartDefault? {
        // This would query historical data
        // For now, return nil
        nil
    }

    private func evaluateRuleCondition(
        _ condition: String,
        context: DefaultsContext
    ) -> Bool {
        // Simple rule evaluation
        // In production, this would be a proper rule engine

        if condition.contains("fiscal_year_end") {
            return context.timeContext.isEndOfFiscalYear
        }

        if condition.contains("high_value") {
            if let value = context.extractedData["totalValue"],
               let amount = parseAmount(value) {
                return amount > 100_000
            }
        }

        return false
    }

    private func validateAndAdjust(
        _ defaultValue: SmartDefault,
        constraint: FieldConstraint
    ) -> SmartDefault? {
        switch constraint.type {
        case let .dateRange(min, max):
            if let date = DateFormatter.mmddyyyy.date(from: defaultValue.value) {
                if date < min {
                    return SmartDefault(
                        field: defaultValue.field,
                        value: DateFormatter.mmddyyyy.string(from: min),
                        confidence: defaultValue.confidence * 0.9,
                        source: defaultValue.source,
                        reasoning: "Adjusted to meet minimum date requirement",
                        alternatives: defaultValue.alternatives
                    )
                } else if date > max {
                    return SmartDefault(
                        field: defaultValue.field,
                        value: DateFormatter.mmddyyyy.string(from: max),
                        confidence: defaultValue.confidence * 0.9,
                        source: defaultValue.source,
                        reasoning: "Adjusted to meet maximum date requirement",
                        alternatives: defaultValue.alternatives
                    )
                }
            }

        case let .valueRange(min, max):
            if let value = Double(defaultValue.value) {
                if value < min || value > max {
                    return nil // Cannot adjust numeric values automatically
                }
            }

        case let .allowedValues(values):
            if !values.contains(defaultValue.value) {
                // Try to find best match
                if let alternative = defaultValue.alternatives.first(where: {
                    values.contains($0.value)
                }) {
                    return SmartDefault(
                        field: defaultValue.field,
                        value: alternative.value,
                        confidence: alternative.confidence,
                        source: defaultValue.source,
                        reasoning: "Adjusted to allowed value",
                        alternatives: []
                    )
                }
                return nil
            }
        }

        return defaultValue
    }

    private func getFieldsForFormType(_ formType: DocumentType) -> [String] {
        switch formType {
        case .requestForQuote:
            [
                "vendor", "deliveryDate", "location", "fundingSource",
                "justification", "approver", "priority", "contractType",
            ]

        case .requestForProposal:
            [
                "requirements", "evaluationCriteria", "submissionDeadline",
                "pointOfContact", "setAsideType", "naics",
            ]

        case .contractScaffold:
            [
                "contractType", "performancePeriod", "deliverables",
                "paymentTerms", "clauses", "attachments",
            ]

        default:
            ["description", "requiredDate", "approver", "priority"]
        }
    }

    private func getFieldMappings(_ field: String) -> [String] {
        switch field {
        case "vendor":
            ["vendor", "vendorName", "vendor_name", "supplier", "company"]
        case "deliveryDate":
            ["deliveryDate", "delivery_date", "requiredDate", "need_by", "due_date"]
        case "location":
            ["location", "deliveryLocation", "delivery_location", "ship_to"]
        case "fundingSource":
            ["fundingSource", "funding_source", "fund", "appropriation"]
        default:
            [field]
        }
    }

    private func parseAmount(_ value: String) -> Double? {
        let cleanValue = value
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)

        return Double(cleanValue)
    }

// MARK: - Supporting Types

public struct FieldConstraint {
    public let field: String
    public let type: ConstraintType

    public enum ConstraintType {
        case dateRange(min: Date, max: Date)
        case valueRange(min: Double, max: Double)
        case allowedValues([String])
    }
}

// MARK: - Organizational Rule Engine (Simplified)

public class OrganizationalRuleEngine {
    public func getRules(for _: String) -> [SmartDefaultsProvider.OrganizationalRule] {
        // In production, this would load from a configuration
        [
            SmartDefaultsProvider.OrganizationalRule(
                field: "approver",
                condition: "value < 5000",
                value: "Direct Supervisor",
                priority: 10
            ),
            SmartDefaultsProvider.OrganizationalRule(
                field: "approver",
                condition: "value >= 5000 AND value < 25000",
                value: "Department Head",
                priority: 10
            ),
            SmartDefaultsProvider.OrganizationalRule(
                field: "priority",
                condition: "fiscal_year_end",
                value: "Urgent",
                priority: 9
            ),
        ]
    }
}
