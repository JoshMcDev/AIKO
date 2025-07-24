import AppCore
import Foundation
import SwiftUI

// MARK: - Smart Defaults Engine

/// Unified engine that combines SmartDefaultsProvider and UserPatternLearningEngine
/// to provide intelligent defaults with high confidence
public final class SmartDefaultsEngine: @unchecked Sendable {
    // MARK: - Properties

    private let smartDefaultsProvider: SmartDefaultsProvider
    private let patternLearningEngine: UserPatternLearningEngine
    private let contextExtractor: UnifiedDocumentContextExtractor
    private let contextualDefaultsProvider: SmartDefaultsProvider
    private let queue = DispatchQueue(label: "com.aiko.smartdefaults", attributes: .concurrent)

    // Cache for computed defaults
    private var _defaultsCache: [RequirementField: CachedDefault] = [:]
    private var defaultsCache: [RequirementField: CachedDefault] {
        get { queue.sync { _defaultsCache } }
        set { queue.async(flags: .barrier) { self._defaultsCache = newValue } }
    }

    // Configuration
    private let cacheExpirationMinutes: TimeInterval = 5
    private let minConfidenceThreshold: Float = 0.65

    // MARK: - Helper Functions

    /// Convert various value types to ResponseValue for FieldDefault
    private func convertToResponseValue(_ value: Any) -> UserResponse.ResponseValue {
        switch value {
        case let string as String:
            convertStringToResponseValue(string)
        case let bool as Bool:
            .boolean(bool)
        case let int as Int:
            .numeric(Decimal(int))
        case let double as Double:
            .numeric(Decimal(double))
        case let decimal as Decimal:
            .numeric(decimal)
        case let date as Date:
            .date(date)
        case let uuid as UUID:
            .document(uuid)
        default:
            // For any other type, convert to string representation
            .text(String(describing: value))
        }
    }

    /// Convert string value to ResponseValue for FieldDefault
    private func convertStringToResponseValue(_ value: String) -> UserResponse.ResponseValue {
        // Try to infer the type from the string content
        if value.isEmpty {
            return .text("")
        }

        // Check for boolean values
        if value.lowercased() == "true" || value.lowercased() == "false" {
            return .boolean(Bool(value.lowercased()) ?? false)
        }

        // Check for numeric values
        if let decimal = Decimal(string: value) {
            return .numeric(decimal)
        }

        // Check for date values (basic ISO format)
        if value.contains("-"), value.count >= 10 {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: value) {
                return .date(date)
            }
        }

        // Check for UUID values
        if value.count == 36, value.contains("-") {
            if let uuid = UUID(uuidString: value) {
                return .document(uuid)
            }
        }

        // Default to text
        return .text(value)
    }

    // MARK: - Initialization

    public init(
        smartDefaultsProvider: SmartDefaultsProvider,
        patternLearningEngine: UserPatternLearningEngine,
        contextExtractor: UnifiedDocumentContextExtractor,
        contextualDefaultsProvider: SmartDefaultsProvider? = nil
    ) {
        self.smartDefaultsProvider = smartDefaultsProvider
        self.patternLearningEngine = patternLearningEngine
        self.contextExtractor = contextExtractor
        self.contextualDefaultsProvider = contextualDefaultsProvider ?? SmartDefaultsProvider()
    }

    // Factory method for creating from MainActor context
    @MainActor
    public static func create(patternLearningEngine: UserPatternLearningEngine) -> SmartDefaultsEngine {
        SmartDefaultsEngine(
            smartDefaultsProvider: SmartDefaultsProvider(),
            patternLearningEngine: patternLearningEngine,
            contextExtractor: UnifiedDocumentContextExtractor(),
            contextualDefaultsProvider: SmartDefaultsProvider()
        )
    }

    // Non-MainActor factory method for dependency injection
    public static func createForDependency() -> SmartDefaultsEngine {
        let patternEngine = UserPatternLearningEngine()
        return SmartDefaultsEngine(
            smartDefaultsProvider: SmartDefaultsProvider.shared,
            patternLearningEngine: patternEngine,
            contextExtractor: UnifiedDocumentContextExtractor.sharedNonMainActor,
            contextualDefaultsProvider: SmartDefaultsProvider()
        )
    }

    // MARK: - Public Methods

    /// Get intelligent default for a specific field with unified confidence scoring
    public func getSmartDefault(
        for field: RequirementField,
        context: SmartDefaultContext
    ) async -> FieldDefault? {
        // Check cache first
        if let cached = getCachedDefault(for: field) {
            return cached
        }

        // Gather defaults from multiple sources
        var candidates: [DefaultCandidate] = []

        // 1. Get from pattern learning engine with enhanced predictions
        // Try sequence-aware prediction first
        if let sequenceDefault = await getSequenceAwarePrediction(for: field, context: context) {
            candidates.append(DefaultCandidate(
                default: sequenceDefault,
                source: .patternLearning,
                priority: 0 // Highest priority for sequence-based predictions
            ))
        }

        // Try time-aware prediction
        if let timeDefault = await patternLearningEngine.getTimeAwarePrediction(for: field) {
            candidates.append(DefaultCandidate(
                default: timeDefault,
                source: .patternLearning,
                priority: 1
            ))
        }

        // Standard pattern prediction
        if let patternDefault = await patternLearningEngine.getDefault(for: field) {
            candidates.append(DefaultCandidate(
                default: patternDefault,
                source: .patternLearning,
                priority: 2
            ))
        }

        // 2. Get from contextual defaults provider
        if let contextualDefault = await getFromContextualProvider(field: field, context: context) {
            candidates.append(DefaultCandidate(
                default: contextualDefault,
                source: .contextual,
                priority: 1 // High priority for context-aware defaults
            ))
        }

        // 3. Get from smart defaults provider
        if let providerDefault = await getFromProvider(field: field, context: context) {
            candidates.append(DefaultCandidate(
                default: providerDefault,
                source: .rulesAndContext,
                priority: 3
            ))
        }

        // 4. Get from document context if available
        if let documentDefault = getFromDocumentContext(field: field, context: context) {
            candidates.append(DefaultCandidate(
                default: documentDefault,
                source: .document,
                priority: 0 // Highest priority
            ))
        }

        // Select best default using ensemble approach
        let bestDefault = selectBestDefault(from: candidates, context: context)

        // Cache the result
        if let result = bestDefault {
            cacheDefault(result, for: field)
        }

        return bestDefault
    }

    /// Get defaults for multiple fields efficiently
    public func getSmartDefaults(
        for fields: [RequirementField],
        context: SmartDefaultContext
    ) async -> [RequirementField: FieldDefault] {
        var defaults: [RequirementField: FieldDefault] = [:]

        // Process fields in priority order
        let prioritizedFields = prioritizeFields(fields, context: context)

        await withTaskGroup(of: (RequirementField, FieldDefault?).self) { group in
            for field in prioritizedFields {
                group.addTask {
                    let defaultValue = await self.getSmartDefault(for: field, context: context)
                    return (field, defaultValue)
                }
            }

            for await (field, defaultValue) in group {
                if let value = defaultValue {
                    defaults[field] = value
                }
            }
        }

        return defaults
    }

    /// Predict fields that should be auto-filled based on confidence
    public func getAutoFillCandidates(
        fields: [RequirementField],
        context: SmartDefaultContext
    ) async -> [RequirementField] {
        let defaults = await getSmartDefaults(for: fields, context: context)

        return defaults.compactMap { field, defaultValue in
            defaultValue.confidence >= context.autoFillThreshold ? field : nil
        }
    }

    /// Learn from user accepting or rejecting a default
    public func learn(
        field: RequirementField,
        suggestedValue: Any,
        acceptedValue: Any,
        wasAccepted: Bool,
        context: SmartDefaultContext
    ) async {
        // Create interaction for pattern learning
        let interaction = APEUserInteraction(
            sessionId: context.sessionId,
            field: field,
            suggestedValue: convertToResponseValue(suggestedValue),
            acceptedSuggestion: wasAccepted,
            finalValue: convertToResponseValue(acceptedValue) ?? .text(String(describing: acceptedValue)),
            timeToRespond: context.responseTime ?? 0,
            documentContext: !context.extractedData.isEmpty
        )

        // Learn from the interaction
        await patternLearningEngine.learn(from: interaction)

        // Invalidate cache for this field
        invalidateCache(for: field)
    }

    /// Clear all cached defaults
    public func clearCache() {
        defaultsCache.removeAll()
    }

    // MARK: - Private Methods

    private func getSequenceAwarePrediction(
        for field: RequirementField,
        context: SmartDefaultContext
    ) async -> FieldDefault? {
        // Build previous fields from session history if available
        var previousFields: [RequirementField: Any] = [:]

        // Use extracted data as proxy for previously filled fields
        for (key, value) in context.extractedData {
            if let field = RequirementField.allCases.first(where: {
                getFieldVariations($0).contains(key)
            }) {
                previousFields[field] = value
            }
        }

        // Get sequence-aware prediction
        return await patternLearningEngine.getSequenceAwarePrediction(
            for: field,
            previousFields: previousFields
        )
    }

    private func getFromContextualProvider(
        field: RequirementField,
        context: SmartDefaultContext
    ) async -> FieldDefault? {
        // Build comprehensive contextual factors
        let factors = ContextualFactors(
            currentDate: Date(),
            fiscalYear: context.fiscalYear,
            fiscalQuarter: context.fiscalQuarter,
            isEndOfFiscalYear: context.isEndOfFiscalYear,
            daysUntilFYEnd: context.daysUntilFYEnd,
            timeOfDay: getCurrentTimeOfDay(),
            dayOfWeek: getCurrentDayOfWeek(),
            organizationalPriorities: [],
            recentSimilarAcquisitions: 0,
            contractorCapacity: 1.0,
            urgentRequests: 0,
            pendingApprovals: 0,
            teamCapacity: 1.0,
            requiredClauses: [],
            setAsideGoals: SetAsideGoals(
                smallBusiness: 0.23,
                womanOwned: 0.05,
                veteranOwned: 0.03,
                hubZone: 0.03,
                eightA: 0.03
            )
        )

        // For now, provide a simple contextual default based on fiscal year urgency
        if factors.isEndOfFiscalYear && factors.daysUntilFYEnd < 60 {
            // Provide urgent defaults for end of fiscal year
            switch field {
            case .requiredDate:
                let urgentDate = Calendar.current.date(byAdding: .day, value: 15, to: Date()) ?? Date()
                return FieldDefault(
                    value: .date(urgentDate),
                    confidence: 0.8,
                    source: .contextual
                )
            default:
                break
            }
        }
        
        return nil
    }

    private func getFromProvider(
        field: RequirementField,
        context: SmartDefaultContext
    ) async -> FieldDefault? {
        // Convert RequirementField to string for provider
        let fieldName = field.rawValue

        // Build provider context
        let providerContext = SmartDefaultsProvider.DefaultsContext(
            userId: context.userId,
            organizationUnit: context.organizationUnit,
            acquisitionType: context.acquisitionType,
            documentType: context.documentType,
            extractedData: context.extractedData,
            userPatterns: [], // Provider will use its own patterns
            organizationalRules: context.organizationalRules,
            timeContext: SmartDefaultsProvider.TimeContext(
                currentDate: Date(),
                fiscalYear: context.fiscalYear,
                quarter: context.fiscalQuarter,
                isEndOfFiscalYear: context.isEndOfFiscalYear,
                daysUntilFYEnd: context.daysUntilFYEnd
            )
        )

        // Get default from provider
        guard let smartDefault = await smartDefaultsProvider.getDefault(
            for: fieldName,
            context: providerContext
        ) else {
            return nil
        }

        // Convert to FieldDefault
        return FieldDefault(
            value: convertStringToResponseValue(smartDefault.value),
            confidence: Float(smartDefault.confidence),
            source: mapProviderSource(smartDefault.source)
        )
    }

    private func getFromDocumentContext(
        field: RequirementField,
        context: SmartDefaultContext
    ) -> FieldDefault? {
        // Check extracted data for field value
        let variations = getFieldVariations(field)

        for key in variations {
            if let value = context.extractedData[key], !value.isEmpty {
                return FieldDefault(
                    value: convertStringToResponseValue(value),
                    confidence: 0.9, // High confidence for extracted data
                    source: .documentContext
                )
            }
        }

        return nil
    }

    private func selectBestDefault(
        from candidates: [DefaultCandidate],
        context _: SmartDefaultContext
    ) -> FieldDefault? {
        guard !candidates.isEmpty else { return nil }

        // Sort by priority (lower is better) and confidence
        let sorted = candidates.sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.default.confidence > rhs.default.confidence
            }
            return lhs.priority < rhs.priority
        }

        // Get best candidate
        guard let best = sorted.first else { return nil }

        // Apply confidence threshold
        guard best.default.confidence >= minConfidenceThreshold else { return nil }

        // If multiple high-confidence sources agree, boost confidence
        let agreeingCandidates = candidates.filter { candidate in
            String(describing: candidate.default.value) == String(describing: best.default.value)
        }

        if agreeingCandidates.count > 1 {
            let boostedConfidence = min(best.default.confidence * 1.1, 1.0)
            return FieldDefault(
                value: best.default.value,
                confidence: boostedConfidence,
                source: best.default.source
            )
        }

        return best.default
    }

    private func prioritizeFields(
        _ fields: [RequirementField],
        context _: SmartDefaultContext
    ) -> [RequirementField] {
        // Priority order based on field criticality and dependencies
        let criticalFields: Set<RequirementField> = [
            .projectTitle,
            .estimatedValue,
            .requiredDate,
            .vendorName,
        ]

        let highPriorityFields: Set<RequirementField> = [
            .fundingSource,
            .contractType,
            .performanceLocation,
        ]

        return fields.sorted { lhs, rhs in
            let lhsCritical = criticalFields.contains(lhs)
            let rhsCritical = criticalFields.contains(rhs)

            if lhsCritical != rhsCritical {
                return lhsCritical
            }

            let lhsHigh = highPriorityFields.contains(lhs)
            let rhsHigh = highPriorityFields.contains(rhs)

            if lhsHigh != rhsHigh {
                return lhsHigh
            }

            return lhs.rawValue < rhs.rawValue
        }
    }

    private func getFieldVariations(_ field: RequirementField) -> [String] {
        switch field {
        case .vendorName:
            ["vendorName", "vendor_name", "vendor", "supplier", "company"]
        case .requiredDate:
            ["requiredDate", "required_date", "deliveryDate", "delivery_date", "needBy", "need_by"]
        case .estimatedValue:
            ["estimatedValue", "estimated_value", "totalValue", "total_value", "amount"]
        case .performanceLocation:
            ["performanceLocation", "location", "deliveryLocation", "delivery_location"]
        case .fundingSource:
            ["fundingSource", "funding_source", "fund", "appropriation"]
        default:
            [field.rawValue]
        }
    }

    private func mapProviderSource(
        _ source: SmartDefaultsProvider.SmartDefault.DefaultSource
    ) -> FieldDefault.DefaultSource {
        switch source {
        case .documentExtraction:
            .documentContext
        case .userPattern:
            .userPattern
        case .historicalData:
            .historical
        case .organizationalRule, .contextInference:
            .systemDefault
        }
    }

    // MARK: - Helper Methods for Contextual Defaults

    private func isEndOfQuarter() -> Bool {
        let month = Calendar.current.component(.month, from: Date())
        return month % 3 == 0 // March, June, September, December
    }

    private func daysUntilQuarterEnd() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)

        let quarterEndMonth = ((month - 1) / 3 + 1) * 3
        var components = DateComponents()
        components.year = year
        components.month = quarterEndMonth
        components.day = calendar.range(of: .day, in: .month, for: now)?.count

        if let quarterEnd = calendar.date(from: components) {
            return calendar.dateComponents([.day], from: now, to: quarterEnd).day ?? 0
        }

        return 0
    }

    private func getCurrentTimeOfDay() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 6 ..< 9: return .earlyMorning
        case 9 ..< 12: return .morning
        case 12 ..< 17: return .afternoon
        case 17 ..< 20: return .evening
        default: return .night
        }
    }

    private func getCurrentDayOfWeek() -> DayOfWeek {
        let weekday = Calendar.current.component(.weekday, from: Date())

        switch weekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return .monday
        }
    }

    // MARK: - Cache Management

    private func getCachedDefault(for field: RequirementField) -> FieldDefault? {
        guard let cached = defaultsCache[field] else { return nil }

        // Check if cache is still valid
        if Date().timeIntervalSince(cached.timestamp) > cacheExpirationMinutes * 60 {
            invalidateCache(for: field)
            return nil
        }

        return cached.value
    }

    private func cacheDefault(_ default: FieldDefault, for field: RequirementField) {
        let cached = CachedDefault(value: `default`, timestamp: Date())
        defaultsCache[field] = cached
    }

    private func invalidateCache(for field: RequirementField) {
        defaultsCache.removeValue(forKey: field)
    }
}

// MARK: - Supporting Types

public struct SmartDefaultContext: Sendable, Equatable {
    public let sessionId: UUID
    public let userId: String
    public let organizationUnit: String
    public let acquisitionType: AcquisitionType?
    public let documentType: DocumentType?
    public let extractedData: [String: String]
    public let organizationalRules: [SmartDefaultsProvider.OrganizationalRule]
    public let fiscalYear: String
    public let fiscalQuarter: String
    public let isEndOfFiscalYear: Bool
    public let daysUntilFYEnd: Int
    public let autoFillThreshold: Float
    public let responseTime: TimeInterval?

    public init(
        sessionId: UUID = UUID(),
        userId: String = "",
        organizationUnit: String = "",
        acquisitionType: AcquisitionType? = nil,
        documentType: DocumentType? = nil,
        extractedData: [String: String] = [:],
        organizationalRules: [SmartDefaultsProvider.OrganizationalRule] = [],
        fiscalYear: String = "",
        fiscalQuarter: String = "",
        isEndOfFiscalYear: Bool = false,
        daysUntilFYEnd: Int = 0,
        autoFillThreshold: Float = 0.8,
        responseTime: TimeInterval? = nil
    ) {
        self.sessionId = sessionId
        self.userId = userId
        self.organizationUnit = organizationUnit
        self.acquisitionType = acquisitionType
        self.documentType = documentType
        self.extractedData = extractedData
        self.organizationalRules = organizationalRules
        self.fiscalYear = fiscalYear
        self.fiscalQuarter = fiscalQuarter
        self.isEndOfFiscalYear = isEndOfFiscalYear
        self.daysUntilFYEnd = daysUntilFYEnd
        self.autoFillThreshold = autoFillThreshold
        self.responseTime = responseTime
    }
}

private struct DefaultCandidate {
    let `default`: FieldDefault
    let source: DefaultSource
    let priority: Int

    enum DefaultSource {
        case document
        case patternLearning
        case contextual
        case rulesAndContext
    }
}

private struct CachedDefault {
    let value: FieldDefault
    let timestamp: Date
}

// MARK: - Extensions for Integration

public extension SmartDefaultsEngine {
    /// Get defaults optimized for minimal questioning
    func getMinimalQuestioningDefaults(
        for fields: [RequirementField],
        context: SmartDefaultContext
    ) async -> MinimalQuestioningResult {
        let defaults = await getSmartDefaults(for: fields, context: context)

        // Categorize fields by confidence
        var autoFill: [RequirementField: FieldDefault] = [:]
        var suggested: [RequirementField: FieldDefault] = [:]
        var mustAsk: [RequirementField] = []

        for field in fields {
            if let defaultValue = defaults[field] {
                if defaultValue.confidence >= context.autoFillThreshold {
                    autoFill[field] = defaultValue
                } else if defaultValue.confidence >= minConfidenceThreshold {
                    suggested[field] = defaultValue
                } else {
                    mustAsk.append(field)
                }
            } else {
                mustAsk.append(field)
            }
        }

        // Order must-ask fields by priority
        // Convert AcquisitionType to APEAcquisitionType
        let apeAcquisitionType: APEAcquisitionType = {
            guard let acqType = context.acquisitionType else { return .supplies }
            switch acqType {
            case .commercialItem, .simplifiedAcquisition:
                return .supplies
            case .nonCommercialService, .majorSystem:
                return .services
            case .constructionProject:
                return .construction
            case .researchDevelopment, .otherTransaction:
                return .researchAndDevelopment
            }
        }()

        let orderedMustAsk = patternLearningEngine.predictNextQuestion(
            answered: Set(autoFill.keys),
            remaining: Set(mustAsk),
            context: ConversationContext(
                acquisitionType: apeAcquisitionType,
                uploadedDocuments: [],
                userProfile: nil,
                historicalData: []
            )
        ).map { [$0] } ?? mustAsk

        return MinimalQuestioningResult(
            autoFillFields: autoFill,
            suggestedFields: suggested,
            mustAskFields: orderedMustAsk
        )
    }

    /// Helper function to convert Any value to UserResponse.ResponseValue
    private func convertToResponseValue(_ value: Any) -> UserResponse.ResponseValue? {
        switch value {
        case let stringValue as String:
            .text(stringValue)
        case let boolValue as Bool:
            .boolean(boolValue)
        case let dateValue as Date:
            .date(dateValue)
        case let decimalValue as Decimal:
            .numeric(decimalValue)
        case let doubleValue as Double:
            .numeric(Decimal(doubleValue))
        case let intValue as Int:
            .numeric(Decimal(intValue))
        case let uuidValue as UUID:
            .document(uuidValue)
        default:
            nil
        }
    }
}

public struct MinimalQuestioningResult {
    public let autoFillFields: [RequirementField: FieldDefault]
    public let suggestedFields: [RequirementField: FieldDefault]
    public let mustAskFields: [RequirementField]
}

// MARK: - Supporting Types for Contextual Defaults

public struct ContextualFactors {
    let currentDate: Date
    let fiscalYear: String
    let fiscalQuarter: String
    let isEndOfFiscalYear: Bool
    let daysUntilFYEnd: Int
    let timeOfDay: TimeOfDay
    let dayOfWeek: DayOfWeek
    let organizationalPriorities: [String]
    let recentSimilarAcquisitions: Int
    let contractorCapacity: Double
    let urgentRequests: Int
    let pendingApprovals: Int
    let teamCapacity: Double
    let requiredClauses: [String]
    let setAsideGoals: SetAsideGoals
}

public struct SetAsideGoals {
    let smallBusiness: Double
    let womanOwned: Double
    let veteranOwned: Double
    let hubZone: Double
    let eightA: Double
}

public enum TimeOfDay {
    case earlyMorning
    case morning
    case afternoon
    case evening
    case night
}

public enum DayOfWeek {
    case sunday
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
}
