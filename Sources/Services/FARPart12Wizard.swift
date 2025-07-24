import ComposableArchitecture
import Foundation

// MARK: - FAR Part 12 Determination Wizard

public struct FARPart12Wizard: @unchecked Sendable {
    public var startWizard: () async throws -> CommercialItemWizard
    public var answerQuestion: (String, WizardAnswer) async throws -> WizardStep
    public var generateDetermination: (CommercialItemWizard) async throws -> CommercialItemDetermination
    public var exportDeterminationMemo: (CommercialItemDetermination) async throws -> String

    public init(
        startWizard: @escaping () async throws -> CommercialItemWizard,
        answerQuestion: @escaping (String, WizardAnswer) async throws -> WizardStep,
        generateDetermination: @escaping (CommercialItemWizard) async throws -> CommercialItemDetermination,
        exportDeterminationMemo: @escaping (CommercialItemDetermination) async throws -> String
    ) {
        self.startWizard = startWizard
        self.answerQuestion = answerQuestion
        self.generateDetermination = generateDetermination
        self.exportDeterminationMemo = exportDeterminationMemo
    }
}

// MARK: - Wizard Models

public struct CommercialItemWizard {
    public var id: UUID
    public var currentStep: WizardStep
    public var answers: [String: WizardAnswer]
    public var determination: CommercialItemDetermination?
    public var completionPercentage: Double

    public init(
        id: UUID = UUID(),
        currentStep: WizardStep,
        answers: [String: WizardAnswer] = [:],
        determination: CommercialItemDetermination? = nil,
        completionPercentage: Double = 0
    ) {
        self.id = id
        self.currentStep = currentStep
        self.answers = answers
        self.determination = determination
        self.completionPercentage = completionPercentage
    }
}

public struct WizardStep: @unchecked Sendable {
    public let id: String
    public let question: String
    public let helpText: String
    public let answerType: AnswerType
    public let options: [String]?
    public let nextStepLogic: (WizardAnswer) -> String?

    public init(
        id: String,
        question: String,
        helpText: String,
        answerType: AnswerType,
        options: [String]? = nil,
        nextStepLogic: @escaping (WizardAnswer) -> String?
    ) {
        self.id = id
        self.question = question
        self.helpText = helpText
        self.answerType = answerType
        self.options = options
        self.nextStepLogic = nextStepLogic
    }
}

public enum AnswerType {
    case yesNo
    case multipleChoice
    case text
    case number
}

public enum WizardAnswer: Equatable {
    case yes
    case no
    case choice(String)
    case text(String)
    case number(Double)
}

public struct CommercialItemDetermination {
    public let isCommercialItem: Bool
    public let determinationType: DeterminationType
    public let justification: String
    public let marketResearchSummary: String
    public let applicableClauses: [String]
    public let recommendations: [String]
    public let risks: [String]

    public init(
        isCommercialItem: Bool,
        determinationType: DeterminationType,
        justification: String,
        marketResearchSummary: String,
        applicableClauses: [String],
        recommendations: [String],
        risks: [String]
    ) {
        self.isCommercialItem = isCommercialItem
        self.determinationType = determinationType
        self.justification = justification
        self.marketResearchSummary = marketResearchSummary
        self.applicableClauses = applicableClauses
        self.recommendations = recommendations
        self.risks = risks
    }
}

public enum DeterminationType: String {
    case commercialItem = "Commercial Item (FAR 2.101(a))"
    case commerciallyAvailable = "Commercially Available Off-The-Shelf (COTS)"
    case commercialService = "Commercial Service"
    case modifiedCommercial = "Modified Commercial Item"
    case notCommercial = "Not a Commercial Item"
    case hybrid = "Hybrid (Mixed Commercial/Non-Commercial)"
}

// MARK: - Wizard Steps Definition

private let wizardSteps: [String: WizardStep] = [
    "start": WizardStep(
        id: "start",
        question: "Is this acquisition for a supply or service?",
        helpText: "Supplies are tangible items (products, equipment, materials). Services are intangible (maintenance, consulting, support).",
        answerType: .multipleChoice,
        options: ["Supply", "Service", "Both"],
        nextStepLogic: { answer in
            switch answer {
            case .choice("Supply"): "supply_type"
            case .choice("Service"): "service_type"
            case .choice("Both"): "hybrid_type"
            default: nil
            }
        }
    ),

    "supply_type": WizardStep(
        id: "supply_type",
        question: "Is this item sold in substantial quantities in the commercial marketplace?",
        helpText: "Consider if the item is regularly sold to the general public or non-governmental entities.",
        answerType: .yesNo,
        options: nil,
        nextStepLogic: { answer in
            switch answer {
            case .yes: "catalog_pricing"
            case .no: "evolved_commercial"
            default: nil
            }
        }
    ),

    "service_type": WizardStep(
        id: "service_type",
        question: "Are these services of a type offered and sold competitively in the commercial marketplace?",
        helpText: "Examples: IT support, facilities maintenance, logistics, professional services.",
        answerType: .yesNo,
        options: nil,
        nextStepLogic: { answer in
            switch answer {
            case .yes: "service_pricing"
            case .no: "specialized_service"
            default: nil
            }
        }
    ),

    "catalog_pricing": WizardStep(
        id: "catalog_pricing",
        question: "Does the item have established catalog or market pricing?",
        helpText: "Look for published price lists, GSA schedules, or standard commercial pricing.",
        answerType: .yesNo,
        options: nil,
        nextStepLogic: { answer in
            switch answer {
            case .yes: "modifications_needed"
            case .no: "custom_pricing"
            default: nil
            }
        }
    ),

    "modifications_needed": WizardStep(
        id: "modifications_needed",
        question: "Will the item require modifications to meet government needs?",
        helpText: "Minor modifications that don't alter the item's commercial nature are acceptable.",
        answerType: .multipleChoice,
        options: ["No modifications", "Minor modifications", "Major modifications"],
        nextStepLogic: { answer in
            switch answer {
            case .choice("No modifications"): "cots_criteria"
            case .choice("Minor modifications"): "modification_type"
            case .choice("Major modifications"): "not_commercial"
            default: nil
            }
        }
    ),

    "cots_criteria": WizardStep(
        id: "cots_criteria",
        question: "Is this item sold 'as-is' without customization to multiple customers?",
        helpText: "COTS items are sold in exactly the same form to all customers.",
        answerType: .yesNo,
        options: nil,
        nextStepLogic: { answer in
            switch answer {
            case .yes: "market_research"
            case .no: "market_research"
            default: nil
            }
        }
    ),

    "market_research": WizardStep(
        id: "market_research",
        question: "What market research have you conducted?",
        helpText: "Select all methods used to research the commercial marketplace.",
        answerType: .text,
        options: nil,
        nextStepLogic: { _ in "determination_complete" }
    ),

    "evolved_commercial": WizardStep(
        id: "evolved_commercial",
        question: "Has this item evolved from a commercial item?",
        helpText: "Items developed from commercial technology may still qualify.",
        answerType: .yesNo,
        options: nil,
        nextStepLogic: { answer in
            switch answer {
            case .yes: "evolution_details"
            case .no: "offered_for_sale"
            default: nil
            }
        }
    ),

    "service_pricing": WizardStep(
        id: "service_pricing",
        question: "How is the service typically priced in the commercial market?",
        helpText: "Consider standard commercial pricing models.",
        answerType: .multipleChoice,
        options: ["Fixed price", "Time and materials", "Per unit/transaction", "Subscription"],
        nextStepLogic: { _ in "service_customization" }
    ),

    "service_customization": WizardStep(
        id: "service_customization",
        question: "Will the service require government-unique features?",
        helpText: "Minor tailoring to government needs is acceptable for commercial services.",
        answerType: .multipleChoice,
        options: ["No customization", "Minor tailoring", "Significant customization"],
        nextStepLogic: { answer in
            switch answer {
            case .choice("Significant customization"): "not_commercial"
            default: "market_research"
            }
        }
    ),

    "modification_type": WizardStep(
        id: "modification_type",
        question: "What type of modifications are needed?",
        helpText: "Minor modifications preserve commercial item status.",
        answerType: .text,
        options: nil,
        nextStepLogic: { _ in "market_research" }
    ),

    "not_commercial": WizardStep(
        id: "not_commercial",
        question: "Based on your answers, this does not appear to be a commercial item. Would you like to explore hybrid options?",
        helpText: "Some acquisitions can include both commercial and non-commercial elements.",
        answerType: .yesNo,
        options: nil,
        nextStepLogic: { answer in
            switch answer {
            case .yes: "hybrid_approach"
            case .no: "determination_complete"
            default: nil
            }
        }
    ),

    "determination_complete": WizardStep(
        id: "determination_complete",
        question: "Determination complete. Would you like to generate a formal determination memorandum?",
        helpText: "The memo will document your commercial item determination for the contract file.",
        answerType: .yesNo,
        options: nil,
        nextStepLogic: { _ in nil }
    ),
]

// MARK: - Live Value

extension FARPart12Wizard: DependencyKey {
    public static var liveValue: FARPart12Wizard {
        FARPart12Wizard(
            startWizard: {
                guard let startStep = wizardSteps["start"] else {
                    throw FARPart12WizardError.invalidStep
                }

                return CommercialItemWizard(
                    currentStep: startStep,
                    completionPercentage: 0
                )
            },

            answerQuestion: { wizardId, answer in
                // In a real implementation, this would track state
                // For now, we'll use the step logic to determine next step
                guard let currentStep = wizardSteps.values.first(where: { $0.id == wizardId }) else {
                    throw FARPart12WizardError.invalidStep
                }

                guard let nextStepId = currentStep.nextStepLogic(answer),
                      let nextStep = wizardSteps[nextStepId]
                else {
                    // Return completion step or throw error if not found
                    guard let completionStep = wizardSteps["determination_complete"] else {
                        throw FARPart12WizardError.stepNotFound("determination_complete")
                    }
                    return completionStep
                }

                return nextStep
            },

            generateDetermination: { wizard in
                // Analyze answers to generate determination
                let isCommercial = !wizard.answers.values.contains { answer in
                    if case .choice("Major modifications") = answer { return true }
                    if case .choice("Significant customization") = answer { return true }
                    return false
                }

                let determinationType: DeterminationType = if wizard.answers.values.contains(where: {
                    if case .choice("No modifications") = $0 { return true }
                    return false
                }) {
                    .commerciallyAvailable
                } else if wizard.answers.values.contains(where: {
                    if case .choice("Minor modifications") = $0 { return true }
                    return false
                }) {
                    .modifiedCommercial
                } else if wizard.answers.values.contains(where: {
                    if case .choice("Service") = $0 { return true }
                    return false
                }) {
                    .commercialService
                } else {
                    isCommercial ? .commercialItem : .notCommercial
                }

                let justification = generateJustification(from: wizard.answers, isCommercial: isCommercial)
                let clauses = getApplicableClauses(for: determinationType)
                let recommendations = generateRecommendations(for: determinationType)
                let risks = identifyRisks(for: determinationType, answers: wizard.answers)

                return CommercialItemDetermination(
                    isCommercialItem: isCommercial,
                    determinationType: determinationType,
                    justification: justification,
                    marketResearchSummary: extractMarketResearch(from: wizard.answers),
                    applicableClauses: clauses,
                    recommendations: recommendations,
                    risks: risks
                )
            },

            exportDeterminationMemo: { determination in
                generateDeterminationMemo(determination)
            }
        )
    }

    private static func generateJustification(from _: [String: WizardAnswer], isCommercial: Bool) -> String {
        if isCommercial {
            """
            Based on market research and analysis, this acquisition meets the definition of a commercial item under FAR 2.101.
            The item/service is of a type customarily used by the general public or non-governmental entities for purposes
            other than governmental purposes, and has been sold, leased, or licensed to the general public.
            """
        } else {
            """
            After thorough market research and analysis, this acquisition does not meet the criteria for commercial item
            determination under FAR 2.101. The item/service requires significant customization or modifications that
            fundamentally alter its commercial nature, or is not offered in the commercial marketplace.
            """
        }
    }

    private static func extractMarketResearch(from _: [String: WizardAnswer]) -> String {
        // Extract market research information from answers
        "Market research conducted included review of commercial catalogs, industry publications, and vendor capabilities."
    }

    private static func getApplicableClauses(for type: DeterminationType) -> [String] {
        switch type {
        case .commercialItem, .commerciallyAvailable, .commercialService, .modifiedCommercial:
            [
                "52.212-1 Instructions to Offerors—Commercial Items",
                "52.212-2 Evaluation—Commercial Items",
                "52.212-3 Offeror Representations and Certifications—Commercial Items",
                "52.212-4 Contract Terms and Conditions—Commercial Items",
                "52.212-5 Contract Terms and Conditions Required to Implement Statutes or Executive Orders—Commercial Items",
            ]
        case .notCommercial:
            ["Standard FAR Part 15 clauses apply"]
        case .hybrid:
            ["Mixed commercial and non-commercial clauses as appropriate"]
        }
    }

    private static func generateRecommendations(for type: DeterminationType) -> [String] {
        switch type {
        case .commercialItem, .commerciallyAvailable:
            [
                "Use FAR Part 12 procedures",
                "Apply streamlined solicitation process",
                "Minimize government-unique requirements",
                "Consider firm-fixed-price contract type",
            ]
        case .commercialService:
            [
                "Use commercial service acquisition procedures",
                "Consider performance-based approach",
                "Apply commercial quality standards",
            ]
        case .modifiedCommercial:
            [
                "Document modifications clearly",
                "Ensure modifications are minor",
                "Maintain commercial pricing structure",
            ]
        case .notCommercial:
            [
                "Use FAR Part 15 procedures",
                "Conduct detailed cost analysis",
                "Apply full competition requirements",
            ]
        case .hybrid:
            [
                "Segregate commercial and non-commercial elements",
                "Apply appropriate procedures to each element",
                "Document determination for each component",
            ]
        }
    }

    private static func identifyRisks(for type: DeterminationType, answers: [String: WizardAnswer]) -> [String] {
        var risks: [String] = []

        if case .modifiedCommercial = type {
            risks.append("Modifications may impact commercial item status if too extensive")
        }

        if answers.values.contains(where: {
            if case let .text(value) = $0, value.isEmpty { return true }
            return false
        }) {
            risks.append("Incomplete market research may challenge determination")
        }

        if case .hybrid = type {
            risks.append("Complex administration of mixed commercial/non-commercial elements")
        }

        return risks.isEmpty ? ["No significant risks identified"] : risks
    }

    private static func generateDeterminationMemo(_ determination: CommercialItemDetermination) -> String {
        """
        MEMORANDUM FOR RECORD

        SUBJECT: Commercial Item Determination - [Contract/Requisition Number]

        1. PURPOSE: This memorandum documents the commercial item determination for the subject acquisition.

        2. DETERMINATION: \(determination.isCommercialItem ? "This IS" : "This IS NOT") a commercial item acquisition.
           Type: \(determination.determinationType.rawValue)

        3. JUSTIFICATION:
        \(determination.justification)

        4. MARKET RESEARCH:
        \(determination.marketResearchSummary)

        5. APPLICABLE CLAUSES:
        \(determination.applicableClauses.map { "   - \($0)" }.joined(separator: "\n"))

        6. RECOMMENDATIONS:
        \(determination.recommendations.map { "   - \($0)" }.joined(separator: "\n"))

        7. RISKS:
        \(determination.risks.map { "   - \($0)" }.joined(separator: "\n"))

        8. CONTRACTING OFFICER DETERMINATION:
        Based on the above analysis, I have determined that this acquisition \(determination.isCommercialItem ? "qualifies" : "does not qualify")
        as a commercial item under FAR 2.101. \(determination.isCommercialItem ? "FAR Part 12 procedures shall be used." : "FAR Part 15 procedures shall be used.")


        _______________________________
        [Contracting Officer Name]
        Contracting Officer
        [Date]
        """
    }
}

// MARK: - Error Types

public enum FARPart12WizardError: Error {
    case invalidStep
    case missingAnswer
    case invalidAnswerType
    case stepNotFound(String)
}

// MARK: - Test Value

public extension FARPart12Wizard {
    static var testValue: FARPart12Wizard {
        FARPart12Wizard(
            startWizard: {
                CommercialItemWizard(
                    currentStep: WizardStep(
                        id: "test",
                        question: "Test question",
                        helpText: "Test help",
                        answerType: .yesNo,
                        nextStepLogic: { _ in nil }
                    ),
                    completionPercentage: 0
                )
            },
            answerQuestion: { _, _ in
                WizardStep(
                    id: "test",
                    question: "Test question",
                    helpText: "Test help",
                    answerType: .yesNo,
                    nextStepLogic: { _ in nil }
                )
            },
            generateDetermination: { _ in
                CommercialItemDetermination(
                    isCommercialItem: true,
                    determinationType: .commercialItem,
                    justification: "Test justification",
                    marketResearchSummary: "Test market research",
                    applicableClauses: ["52.212-1", "52.212-2"],
                    recommendations: ["Use FAR Part 12"],
                    risks: ["None identified"]
                )
            },
            exportDeterminationMemo: { _ in
                "Test determination memo"
            }
        )
    }
}

// MARK: - Dependency Registration

public extension DependencyValues {
    var farPart12Wizard: FARPart12Wizard {
        get { self[FARPart12Wizard.self] }
        set { self[FARPart12Wizard.self] = newValue }
    }
}
