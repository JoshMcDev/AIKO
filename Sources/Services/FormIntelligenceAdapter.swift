import ComposableArchitecture
import Foundation

/// Adaptive intelligence adapter for government forms
/// Integrates forms with the learning loop and requirement analysis system
public actor FormIntelligenceAdapter {
    // MARK: - Dependencies

    private let learningLoop: LearningLoop
    private let requirementAnalyzer: RequirementAnalyzer
    private let formService: GovernmentFormService
    private let patternTracker: UserPatternTracker
    private let coreDataActor: CoreDataActor

    // MARK: - Private closures for functionality

    private let recommendFormsImpl: (String, AcquisitionAggregate) async throws -> FormRecommendation
    private let autoFillFormImpl: (String, FormData, AcquisitionAggregate) async throws -> FormData
    private let provideFormGuidanceImpl: (String, FormSection) async throws -> FormGuidance
    private let learnFromSubmissionImpl: (GovernmentFormData, SubmissionOutcome) async throws -> Void
    private let generateFormInsightsImpl: () async throws -> [FormInsight]

    // MARK: - Initialization

    public init(
        learningLoop: LearningLoop,
        requirementAnalyzer: RequirementAnalyzer,
        formService: GovernmentFormService,
        patternTracker: UserPatternTracker,
        coreDataActor: CoreDataActor,
        recommendForms: @escaping (String, AcquisitionAggregate) async throws -> FormRecommendation,
        autoFillForm: @escaping (String, FormData, AcquisitionAggregate) async throws -> FormData,
        provideFormGuidance: @escaping (String, FormSection) async throws -> FormGuidance,
        learnFromSubmission: @escaping (GovernmentFormData, SubmissionOutcome) async throws -> Void,
        generateFormInsights: @escaping () async throws -> [FormInsight]
    ) {
        self.learningLoop = learningLoop
        self.requirementAnalyzer = requirementAnalyzer
        self.formService = formService
        self.patternTracker = patternTracker
        self.coreDataActor = coreDataActor
        recommendFormsImpl = recommendForms
        autoFillFormImpl = autoFillForm
        provideFormGuidanceImpl = provideFormGuidance
        learnFromSubmissionImpl = learnFromSubmission
        generateFormInsightsImpl = generateFormInsights
    }

    // MARK: - Public Actor Methods

    /// Analyze requirements and recommend appropriate forms
    public func recommendForms(_ requirements: String, _ acquisition: AcquisitionAggregate) async throws -> FormRecommendation {
        try await recommendFormsImpl(requirements, acquisition)
    }

    /// Auto-fill form based on learned patterns and historical data
    public func autoFillForm(_ formType: String, _ baseData: FormData, _ acquisition: AcquisitionAggregate) async throws -> FormData {
        try await autoFillFormImpl(formType, baseData, acquisition)
    }

    /// Provide intelligent guidance for form completion
    public func provideFormGuidance(_ formType: String, _ section: FormSection) async throws -> FormGuidance {
        try await provideFormGuidanceImpl(formType, section)
    }

    /// Learn from form submission patterns
    public func learnFromSubmission(_ formData: GovernmentFormData, _ outcome: SubmissionOutcome) async throws {
        nonisolated(unsafe) let data = formData
        try await learnFromSubmissionImpl(data, outcome)
    }

    /// Generate form insights based on usage patterns
    public func generateFormInsights() async throws -> [FormInsight] {
        try await generateFormInsightsImpl()
    }
}

// MARK: - Form Recommendation

public struct FormRecommendation: Equatable, Sendable {
    public let primaryForm: RecommendedForm
    public let supplementaryForms: [RecommendedForm]
    public let reasoning: String
    public let confidence: Double

    public struct RecommendedForm: Equatable, Sendable {
        public let formType: String
        public let formNumber: String
        public let title: String
        public let reason: String
        public let requiredFields: [String]
        public let estimatedCompletionTime: TimeInterval
    }
}

// MARK: - Form Guidance

public struct FormGuidance: Equatable, Sendable {
    public let sectionName: String
    public let fieldGuidance: [FieldGuidance]
    public let tips: [String]
    public let warnings: [ComplianceWarning]
    public let references: [FARReference]

    public struct FieldGuidance: Equatable, Sendable {
        public let fieldName: String
        public let description: String
        public let example: String?
        public let validation: String?
        public let autofillAvailable: Bool
    }

    public struct ComplianceWarning: Equatable, Sendable {
        public let severity: Severity
        public let message: String
        public let farReference: String?

        public enum Severity: String, Equatable, Sendable {
            case info
            case warning
            case error
        }
    }

    public struct FARReference: Equatable, Sendable {
        public let clause: String
        public let title: String
        public let relevance: String
    }
}

// MARK: - Form Section

public enum FormSection: String, Equatable, Sendable {
    case contractInformation = "Contract Information"
    case vendorInformation = "Vendor Information"
    case suppliesServices = "Supplies/Services"
    case deliveryInformation = "Delivery Information"
    case paymentTerms = "Payment Terms"
    case contractClauses = "Contract Clauses"
    case signatures = "Signatures"
    case attachments = "Attachments"
}

// MARK: - Submission Outcome

public struct SubmissionOutcome: Equatable, Sendable {
    public let success: Bool
    public let processingTime: TimeInterval
    public let validationErrors: [ValidationError]
    public let userCorrections: [FieldCorrection]
    public let finalValues: [String: String] // Changed from Any to String for Equatable conformance

    public struct ValidationError: Equatable, Sendable {
        public let fieldName: String
        public let errorType: String
        public let message: String
    }

    public struct FieldCorrection: Equatable, Sendable {
        public let fieldName: String
        public let originalValue: String
        public let correctedValue: String
        public let reason: String?
    }
}

// MARK: - Form Insights

public struct FormInsight: Equatable, Sendable {
    public let id: UUID
    public let formType: String
    public let insightType: InsightType
    public let title: String
    public let description: String
    public let impact: Impact
    public let recommendations: [String]
    public let dataPoints: [DataPoint]

    public enum InsightType: String, Equatable, Sendable {
        case usagePattern = "Usage Pattern"
        case completionRate = "Completion Rate"
        case commonErrors = "Common Errors"
        case timeToComplete = "Time to Complete"
        case fieldAccuracy = "Field Accuracy"
        case automationOpportunity = "Automation Opportunity"
    }

    public enum Impact: String, Equatable, Sendable {
        case high
        case medium
        case low
    }

    public struct DataPoint: Equatable, Sendable {
        public let label: String
        public let value: Double
        public let unit: String?
    }
}

// MARK: - Live Implementation

extension FormIntelligenceAdapter: DependencyKey {
    public nonisolated static var liveValue: FormIntelligenceAdapter {
        let learningLoop = LearningLoop.liveValue
        let requirementAnalyzer = RequirementAnalyzer.liveValue
        let coreDataActor = CoreDataStack.shared.actor
        let formService = GovernmentFormService(context: coreDataActor)
        let patternTracker = UserPatternTracker.liveValue

        return FormIntelligenceAdapter(
            learningLoop: learningLoop,
            requirementAnalyzer: requirementAnalyzer,
            formService: formService,
            patternTracker: patternTracker,
            coreDataActor: coreDataActor,
            recommendForms: { requirements, acquisition in
                // Analyze requirements to determine form needs
                let analysis = try await requirementAnalyzer.analyzeRequirements(requirements)

                // Map document recommendations to form types
                var recommendedForms: [FormRecommendation.RecommendedForm] = []

                // Check for commercial acquisition
                if analysis.response.contains("commercial") ||
                    analysis.response.contains("FAR Part 12") {
                    recommendedForms.append(.init(
                        formType: GovernmentFormData.FormType.sf1449,
                        formNumber: "SF 1449",
                        title: "Solicitation/Contract/Order for Commercial Products",
                        reason: "Recommended for commercial acquisitions under FAR Part 12",
                        requiredFields: ["contractNumber", "vendorInfo", "supplies", "price"],
                        estimatedCompletionTime: 1800 // 30 minutes
                    ))
                }

                // Check for simplified acquisition
                if analysis.response.contains("simplified acquisition") ||
                    analysis.response.contains("FAR Part 13") {
                    recommendedForms.append(.init(
                        formType: GovernmentFormData.FormType.sf18,
                        formNumber: "SF 18",
                        title: "Request for Quotations",
                        reason: "Suitable for simplified acquisitions under the threshold",
                        requiredFields: ["rfqNumber", "items", "deliveryDate"],
                        estimatedCompletionTime: 900 // 15 minutes
                    ))
                }

                // Check for contract modification needs
                if acquisition.status == .inProgress || acquisition.status == .underReview,
                   requirements.contains("modification") || requirements.contains("change") {
                    recommendedForms.append(.init(
                        formType: GovernmentFormData.FormType.sf30,
                        formNumber: "SF 30",
                        title: "Amendment of Solicitation/Modification of Contract",
                        reason: "Required for contract modifications",
                        requiredFields: ["modificationNumber", "changes", "authority"],
                        estimatedCompletionTime: 1200 // 20 minutes
                    ))
                }

                // Default to SF1449 if no specific form identified
                if recommendedForms.isEmpty {
                    recommendedForms.append(.init(
                        formType: GovernmentFormData.FormType.sf1449,
                        formNumber: "SF 1449",
                        title: "Solicitation/Contract/Order for Commercial Products",
                        reason: "Standard form for government acquisitions",
                        requiredFields: ["contractNumber", "vendorInfo", "supplies", "price"],
                        estimatedCompletionTime: 1800
                    ))
                }

                // Record the recommendation event
                await learningLoop.recordEvent(LearningEvent(
                    eventType: .documentSelected,
                    context: .init(
                        workflowState: "form_recommendation",
                        acquisitionId: acquisition.id,
                        documentType: recommendedForms.first?.formType,
                        userData: ["requirements": requirements],
                        systemData: ["form_count": String(recommendedForms.count)]
                    )
                ))

                guard let primaryForm = recommendedForms.first else {
                    throw FormMappingError.noFormsFound
                }

                return FormRecommendation(
                    primaryForm: primaryForm,
                    supplementaryForms: Array(recommendedForms.dropFirst()),
                    reasoning: "Based on the requirements analysis and acquisition type",
                    confidence: 0.85
                )
            },
            autoFillForm: { formType, baseData, acquisition in
                // Get user patterns
                let patterns = await patternTracker.getPatterns()

                var updatedFields = baseData.fields

                // Auto-fill from acquisition data
                if let projectNumber = acquisition.projectNumber {
                    updatedFields["projectNumber"] = projectNumber
                    updatedFields["requisitionNumber"] = "REQ-\(projectNumber)"
                }

                updatedFields["title"] = acquisition.title
                updatedFields["requirements"] = acquisition.requirements
                updatedFields["acquisitionId"] = acquisition.id.uuidString

                // Apply preferred values from patterns
                for (fieldName, commonValues) in patterns.preferredValues {
                    if updatedFields[fieldName] == nil, let preferredValue = commonValues.first {
                        updatedFields[fieldName] = preferredValue
                    }
                }

                // Get similar past forms
                let similarForms = try await formService.getForms(ofType: formType)
                    .prefix(5) // Last 5 forms

                // Apply common values from past forms
                for form in similarForms {
                    let decodedForm = form.fields
                    // Copy commonly reused fields
                    for field in ["contractingOfficer", "issuingOffice", "paymentTerms"] {
                        if let value = decodedForm[field], updatedFields[field] == nil {
                            updatedFields[field] = value
                        }
                    }
                }

                // Record auto-fill event
                await learningLoop.recordEvent(LearningEvent(
                    eventType: .dataExtracted,
                    context: .init(
                        workflowState: "form_autofill",
                        acquisitionId: acquisition.id,
                        documentType: formType,
                        userData: [:],
                        systemData: ["fields_filled": String(updatedFields.count)]
                    )
                ))

                return FormData(
                    formNumber: baseData.formNumber,
                    revision: baseData.revision,
                    fields: updatedFields,
                    metadata: baseData.metadata
                )
            },
            provideFormGuidance: { formType, section in
                // Build guidance based on form type and section
                var fieldGuidance: [FormGuidance.FieldGuidance] = []
                var tips: [String] = []
                var warnings: [FormGuidance.ComplianceWarning] = []
                var references: [FormGuidance.FARReference] = []

                // Form-specific guidance
                switch formType {
                case GovernmentFormData.FormType.sf1449:
                    switch section {
                    case .contractInformation:
                        fieldGuidance.append(.init(
                            fieldName: "contractNumber",
                            description: "Unique procurement instrument identifier (PIID)",
                            example: "FA8501-24-C-0001",
                            validation: "Must follow agency PIID format",
                            autofillAvailable: true
                        ))
                        tips.append("Contract numbers must be unique within your agency")
                        references.append(.init(
                            clause: "FAR 4.1601",
                            title: "Contract Numbering",
                            relevance: "Defines PIID requirements"
                        ))

                    case .vendorInformation:
                        fieldGuidance.append(.init(
                            fieldName: "cageCode",
                            description: "Commercial and Government Entity code",
                            example: "1ABC2",
                            validation: "5-character alphanumeric",
                            autofillAvailable: true
                        ))
                        warnings.append(.init(
                            severity: .warning,
                            message: "Verify vendor is active in SAM.gov",
                            farReference: "FAR 4.1102"
                        ))

                    default:
                        break
                    }

                case GovernmentFormData.FormType.sf30:
                    tips.append("Clearly describe all changes being made")
                    tips.append("Include justification for the modification")
                    warnings.append(.init(
                        severity: .error,
                        message: "Bilateral modifications require contractor signature",
                        farReference: "FAR 43.103"
                    ))

                default:
                    tips.append("Complete all required fields before submission")
                }

                return FormGuidance(
                    sectionName: section.rawValue,
                    fieldGuidance: fieldGuidance,
                    tips: tips,
                    warnings: warnings,
                    references: references
                )
            },
            learnFromSubmission: { formData, outcome in
                // Record submission outcome
                await learningLoop.recordEvent(LearningEvent(
                    eventType: outcome.success ? .successAchieved : .errorOccurred,
                    context: .init(
                        workflowState: "form_submission",
                        acquisitionId: formData.acquisition?.id,
                        documentType: formData.formType,
                        userData: [:],
                        systemData: [
                            "processing_time": String(outcome.processingTime),
                            "error_count": String(outcome.validationErrors.count),
                        ]
                    ),
                    outcome: outcome.success ? .success : .failure
                ))

                // Learn from corrections
                for _ in outcome.userCorrections {
                    await patternTracker.trackAction(TrackedAction(
                        actionType: .documentEdited,
                        context: .init(
                            documentType: formData.formType,
                            workflowState: "form_correction",
                            timeOfDay: Calendar.current.component(.hour, from: Date()),
                            dayOfWeek: Calendar.current.component(.weekday, from: Date()),
                            previousAction: "form_submission",
                            timeSpent: outcome.processingTime
                        )
                    ))
                }

                // Track form completion outcome
                await patternTracker.learnFromOutcome(ActionOutcome(
                    actionId: UUID(),
                    success: outcome.success,
                    timeToComplete: outcome.processingTime,
                    userSatisfaction: nil
                ))
            },
            generateFormInsights: {
                var insights: [FormInsight] = []

                // Analyze form usage patterns
                let formTypes = [
                    GovernmentFormData.FormType.sf1449,
                    GovernmentFormData.FormType.sf33,
                    GovernmentFormData.FormType.sf30,
                    GovernmentFormData.FormType.sf18,
                    GovernmentFormData.FormType.sf26,
                    GovernmentFormData.FormType.sf44,
                    GovernmentFormData.FormType.dd1155,
                ]

                // Get user patterns for analysis
                let userPatterns = await patternTracker.getPatterns()

                // Analyze form usage based on document sequences
                for formType in formTypes {
                    // Find sequences containing this form type
                    let formSequences = userPatterns.documentSequences.filter { seq in
                        seq.documents.contains(formType)
                    }

                    if !formSequences.isEmpty {
                        let totalFrequency = formSequences.reduce(0) { $0 + $1.frequency }
                        let avgSuccessRate = formSequences.reduce(0.0) { $0 + $1.successRate } / Double(formSequences.count)

                        insights.append(FormInsight(
                            id: UUID(),
                            formType: formType,
                            insightType: .usagePattern,
                            title: "\(formType) Usage Trend",
                            description: "This form appears in \(formSequences.count) workflow patterns",
                            impact: totalFrequency > 10 ? .high : .medium,
                            recommendations: [
                                "Consider creating templates for common scenarios",
                                "Review auto-fill accuracy for frequently used fields",
                            ],
                            dataPoints: [
                                .init(label: "Pattern Frequency", value: Double(totalFrequency), unit: "occurrences"),
                                .init(label: "Success Rate", value: avgSuccessRate * 100, unit: "%"),
                            ]
                        ))
                    }

                    // Add time-to-complete insights if available
                    if let avgTime = userPatterns.averageTimePerDocument[formType] {
                        insights.append(FormInsight(
                            id: UUID(),
                            formType: formType,
                            insightType: .timeToComplete,
                            title: "Average Completion Time",
                            description: "Users typically complete this form in \(Int(avgTime / 60)) minutes",
                            impact: avgTime > 1800 ? .high : .low,
                            recommendations: avgTime > 1800 ? [
                                "Consider breaking complex sections into steps",
                                "Provide more auto-fill options",
                            ] : [
                                "Current completion time is optimal",
                            ],
                            dataPoints: [
                                .init(label: "Average Time", value: avgTime / 60, unit: "minutes"),
                            ]
                        ))
                    }
                }

                // Process insights through learning loop
                let processingResult = try await learningLoop.processQueue()

                // Add any system-generated insights
                for learning in processingResult.learningsGenerated where learning.type == .automationOpportunity {
                    insights.append(FormInsight(
                        id: UUID(),
                        formType: "general",
                        insightType: .automationOpportunity,
                        title: "Automation Opportunity Detected",
                        description: learning.recommendation.action,
                        impact: learning.confidence > 0.8 ? .high : .medium,
                        recommendations: [learning.recommendation.action],
                        dataPoints: [
                            .init(label: "Confidence", value: learning.confidence * 100, unit: "%"),
                            .init(label: "Impact", value: learning.recommendation.impact == .high ? 100 : learning.recommendation.impact == .medium ? 50 : 25, unit: "score"),
                        ]
                    ))
                }

                return insights
            }
        )
    }
}

// MARK: - Dependency Values

public extension DependencyValues {
    var formIntelligenceAdapter: FormIntelligenceAdapter {
        get { self[FormIntelligenceAdapter.self] }
        set { self[FormIntelligenceAdapter.self] = newValue }
    }
}
