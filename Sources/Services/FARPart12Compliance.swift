import AppCore
import ComposableArchitecture
import Foundation

// MARK: - FAR Part 12 Compliance Service

/// Service for ensuring compliance with FAR Part 12 Commercial Item acquisitions
public struct FARPart12ComplianceService: Sendable {
    public var validateCommercialItem: @Sendable (String, DocumentType) async throws -> CommercialItemValidation
    public var getRequiredClauses: @Sendable (ContractValue, DocumentType) async throws -> [CommercialItemClause]
    public var checkMarketResearch: @Sendable (String) async throws -> MarketResearchCompliance
    public var validateSolicitationProvisions: @Sendable (String) async throws -> [ComplianceIssue]
    public var generateCommercialItemDetermination: @Sendable (MarketResearchData) async throws -> String

    public init(
        validateCommercialItem: @escaping @Sendable (String, DocumentType) async throws -> CommercialItemValidation,
        getRequiredClauses: @escaping @Sendable (ContractValue, DocumentType) async throws -> [CommercialItemClause],
        checkMarketResearch: @escaping @Sendable (String) async throws -> MarketResearchCompliance,
        validateSolicitationProvisions: @escaping @Sendable (String) async throws -> [ComplianceIssue],
        generateCommercialItemDetermination: @escaping @Sendable (MarketResearchData) async throws -> String
    ) {
        self.validateCommercialItem = validateCommercialItem
        self.getRequiredClauses = getRequiredClauses
        self.checkMarketResearch = checkMarketResearch
        self.validateSolicitationProvisions = validateSolicitationProvisions
        self.generateCommercialItemDetermination = generateCommercialItemDetermination
    }
}

// MARK: - Models

public struct CommercialItemValidation: Equatable {
    public let isCommercialItem: Bool
    public let determinationBasis: DeterminationBasis
    public let supportingEvidence: [String]
    public let requiredClauses: [CommercialItemClause]
    public let prohibitedTerms: [String]
    public let recommendations: [String]

    public enum DeterminationBasis: String, Equatable {
        case soldInCommercialMarket = "Sold in substantial quantities in commercial marketplace"
        case evolvedFromCommercial = "Evolved from commercial item"
        case modifiedCommercial = "Modified commercial item (minor modifications)"
        case commercialService = "Commercial service"
        case catalogPriced = "Offered at catalog or market prices"
        case competitivelyAwarded = "Competitively awarded commercial contracts"
        case notCommercial = "Does not meet commercial item criteria"
    }
}

public struct CommercialItemClause: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let prescribedIn: String
    public let applicability: ClauseApplicability
    public let fillIns: [String]
    public let isRequired: Bool
    public let alternates: [String]

    public enum ClauseApplicability: String, Equatable {
        case always = "Always required"
        case conditional = "Required when applicable"
        case optional = "Optional"
        case thresholdBased = "Based on dollar threshold"
    }

    public init(
        id: String,
        title: String,
        prescribedIn: String,
        applicability: ClauseApplicability,
        fillIns: [String] = [],
        isRequired: Bool = true,
        alternates: [String] = []
    ) {
        self.id = id
        self.title = title
        self.prescribedIn = prescribedIn
        self.applicability = applicability
        self.fillIns = fillIns
        self.isRequired = isRequired
        self.alternates = alternates
    }
}

public struct ContractValue: Equatable {
    public let amount: Double
    public let isIDIQ: Bool
    public let includesOptions: Bool

    public var exceedsSimplifiedAcquisitionThreshold: Bool {
        amount > 250_000
    }

    public var exceedsMicroPurchaseThreshold: Bool {
        amount > 10000
    }
}

public struct MarketResearchCompliance: Equatable {
    public let isCompliant: Bool
    public let researchMethods: [ResearchMethod]
    public let findings: [String]
    public let gaps: [String]
    public let commercialItemDetermination: Bool

    public enum ResearchMethod: String, CaseIterable {
        case internetSearch = "Internet/Online Research"
        case vendorCatalogs = "Review of Vendor Catalogs"
        case gsa = "GSA Advantage/eBuy"
        case industryDays = "Industry Days/Conferences"
        case rfi = "Request for Information"
        case sourcesSought = "Sources Sought Notice"
        case previousContracts = "Review of Previous Contracts"
        case technicalExperts = "Consultation with Technical Experts"
    }
}

public struct MarketResearchData: Equatable {
    public let productDescription: String
    public let researchMethods: [MarketResearchCompliance.ResearchMethod]
    public let commercialSources: [String]
    public let priceData: [PricePoint]
    public let technicalRequirements: [String]

    public struct PricePoint: Equatable {
        public let vendor: String
        public let price: Double
        public let quantity: Int
        public let date: Date
    }
}

// MARK: - Implementation

extension FARPart12ComplianceService: DependencyKey {
    public static var liveValue: FARPart12ComplianceService {
        FARPart12ComplianceService(
            validateCommercialItem: { content, _ in
                let lowercaseContent = content.lowercased()
                var evidence: [String] = []
                var recommendations: [String] = []

                // Check for commercial item indicators
                let commercialIndicators = [
                    "commercial", "cots", "catalog", "market price", "commercial service",
                    "standard commercial", "commercially available", "gsa schedule",
                ]

                let hasCommercialIndicators = commercialIndicators.contains { lowercaseContent.contains($0) }

                // Determine basis
                let basis: CommercialItemValidation.DeterminationBasis
                if lowercaseContent.contains("catalog") || lowercaseContent.contains("market price") {
                    basis = .catalogPriced
                    evidence.append("Item offered at catalog or market prices")
                } else if lowercaseContent.contains("commercial service") {
                    basis = .commercialService
                    evidence.append("Service of a type offered to general public")
                } else if lowercaseContent.contains("gsa") || lowercaseContent.contains("schedule") {
                    basis = .competitivelyAwarded
                    evidence.append("Available on GSA Schedule")
                } else if hasCommercialIndicators {
                    basis = .soldInCommercialMarket
                    evidence.append("Evidence of commercial marketplace sales")
                } else {
                    basis = .notCommercial
                    recommendations.append("Consider if requirement can be met with commercial items")
                }

                // Get required clauses based on determination
                let requiredClauses = basis != .notCommercial ? getCommercialItemClauses() : []

                // Identify prohibited terms for commercial items
                let prohibitedTerms = basis != .notCommercial ? [
                    "Cost Accounting Standards",
                    "Certified Cost or Pricing Data",
                    "Truth in Negotiations Act",
                    "Detailed Manufacturing Processes",
                    "Government Property Control",
                ] : []

                // Add recommendations
                if basis != .notCommercial {
                    recommendations.append("Use streamlined commercial item procedures")
                    recommendations.append("Consider firm-fixed-price contract type")
                    recommendations.append("Minimize government-unique requirements")
                }

                return CommercialItemValidation(
                    isCommercialItem: basis != .notCommercial,
                    determinationBasis: basis,
                    supportingEvidence: evidence,
                    requiredClauses: requiredClauses,
                    prohibitedTerms: prohibitedTerms,
                    recommendations: recommendations
                )
            },

            getRequiredClauses: { contractValue, _ in
                var clauses: [CommercialItemClause] = []

                // Basic commercial item clauses (always required)
                clauses.append(CommercialItemClause(
                    id: "52.212-1",
                    title: "Instructions to Offerors—Commercial Items",
                    prescribedIn: "FAR 12.301(b)(1)",
                    applicability: .always
                ))

                clauses.append(CommercialItemClause(
                    id: "52.212-2",
                    title: "Evaluation—Commercial Items",
                    prescribedIn: "FAR 12.301(b)(2)",
                    applicability: .always
                ))

                clauses.append(CommercialItemClause(
                    id: "52.212-3",
                    title: "Offeror Representations and Certifications—Commercial Items",
                    prescribedIn: "FAR 12.301(b)(3)",
                    applicability: .always
                ))

                clauses.append(CommercialItemClause(
                    id: "52.212-4",
                    title: "Contract Terms and Conditions—Commercial Items",
                    prescribedIn: "FAR 12.301(b)(4)",
                    applicability: .always,
                    alternates: ["Alt I (services)", "Alt II (personal services)"]
                ))

                clauses.append(CommercialItemClause(
                    id: "52.212-5",
                    title: "Contract Terms and Conditions Required to Implement Statutes or Executive Orders—Commercial Items",
                    prescribedIn: "FAR 12.301(b)(5)",
                    applicability: .always,
                    fillIns: ["Applicable clauses must be checked"]
                ))

                // Threshold-based clauses
                if contractValue.exceedsSimplifiedAcquisitionThreshold {
                    clauses.append(CommercialItemClause(
                        id: "52.204-7",
                        title: "System for Award Management",
                        prescribedIn: "FAR 4.1105(a)(1)",
                        applicability: .thresholdBased
                    ))

                    clauses.append(CommercialItemClause(
                        id: "52.204-13",
                        title: "System for Award Management Maintenance",
                        prescribedIn: "FAR 4.1105(a)(2)",
                        applicability: .thresholdBased
                    ))
                }

                // IDIQ specific
                if contractValue.isIDIQ {
                    clauses.append(CommercialItemClause(
                        id: "52.216-18",
                        title: "Ordering",
                        prescribedIn: "FAR 16.506(a)",
                        applicability: .conditional
                    ))

                    clauses.append(CommercialItemClause(
                        id: "52.216-19",
                        title: "Order Limitations",
                        prescribedIn: "FAR 16.506(b)",
                        applicability: .conditional
                    ))
                }

                return clauses
            },

            checkMarketResearch: { content in
                let lowercaseContent = content.lowercased()
                var usedMethods: [MarketResearchCompliance.ResearchMethod] = []
                var findings: [String] = []
                var gaps: [String] = []

                // Check which research methods were used
                for method in MarketResearchCompliance.ResearchMethod.allCases where lowercaseContent.contains(method.rawValue.lowercased()) {
                    usedMethods.append(method)
                }

                // Check for key findings
                if lowercaseContent.contains("commercial") {
                    findings.append("Commercial items identified")
                }
                if lowercaseContent.contains("price") {
                    findings.append("Pricing data collected")
                }
                if lowercaseContent.contains("vendor") || lowercaseContent.contains("supplier") {
                    findings.append("Potential vendors identified")
                }

                // Identify gaps
                if usedMethods.count < 3 {
                    gaps.append("Consider using additional research methods")
                }
                if !lowercaseContent.contains("price") {
                    gaps.append("Price analysis should be included")
                }
                if !lowercaseContent.contains("commercial item determination") {
                    gaps.append("Include explicit commercial item determination")
                }

                let isCompliant = !findings.isEmpty && usedMethods.count >= 2
                let commercialDetermination = lowercaseContent.contains("commercial item") ||
                    lowercaseContent.contains("commercially available")

                return MarketResearchCompliance(
                    isCompliant: isCompliant,
                    researchMethods: usedMethods,
                    findings: findings,
                    gaps: gaps,
                    commercialItemDetermination: commercialDetermination
                )
            },

            validateSolicitationProvisions: { content in
                var issues: [ComplianceIssue] = []
                let lowercaseContent = content.lowercased()

                // Check for required provisions
                if !lowercaseContent.contains("52.212-1") {
                    issues.append(ComplianceIssue(
                        severity: .critical,
                        description: "Missing FAR 52.212-1 Instructions to Offerors—Commercial Items",
                        farReference: "FAR 12.301(b)(1)",
                        suggestedFix: "Include FAR 52.212-1 in solicitation provisions"
                    ))
                }

                if !lowercaseContent.contains("52.212-2") {
                    issues.append(ComplianceIssue(
                        severity: .critical,
                        description: "Missing FAR 52.212-2 Evaluation—Commercial Items",
                        farReference: "FAR 12.301(b)(2)",
                        suggestedFix: "Include FAR 52.212-2 and specify evaluation factors"
                    ))
                }

                // Check for prohibited requirements
                if lowercaseContent.contains("cost breakdown") || lowercaseContent.contains("certified cost") {
                    issues.append(ComplianceIssue(
                        severity: .major,
                        description: "Commercial items should not require certified cost or pricing data",
                        farReference: "FAR 12.207",
                        suggestedFix: "Remove requirements for detailed cost breakdowns"
                    ))
                }

                if lowercaseContent.contains("government property") {
                    issues.append(ComplianceIssue(
                        severity: .minor,
                        description: "Minimize government property requirements for commercial items",
                        farReference: "FAR 12.302",
                        suggestedFix: "Consider if government property clauses are necessary"
                    ))
                }

                return issues
            },

            generateCommercialItemDetermination: { marketResearchData in
                """
                COMMERCIAL ITEM DETERMINATION

                1. ITEM DESCRIPTION:
                \(marketResearchData.productDescription)

                2. MARKET RESEARCH CONDUCTED:
                \(marketResearchData.researchMethods.map { "• \($0.rawValue)" }.joined(separator: "\n"))

                3. COMMERCIAL SOURCES IDENTIFIED:
                \(marketResearchData.commercialSources.map { "• \($0)" }.joined(separator: "\n"))

                4. PRICING ANALYSIS:
                \(marketResearchData.priceData.map { "• \($0.vendor): $\($0.price) for quantity \($0.quantity)" }.joined(separator: "\n"))

                5. DETERMINATION:
                Based on the market research conducted, this item/service IS DETERMINED TO BE A COMMERCIAL ITEM
                as defined in FAR 2.101 because it:

                ☑ Is of a type customarily used by the general public or by non-governmental entities
                ☑ Has been sold, leased, or licensed to the general public
                ☑ Is offered for sale at catalog or market prices

                6. RECOMMENDATION:
                Proceed with acquisition using FAR Part 12 commercial item procedures.
                Use standard commercial terms and conditions to maximum extent practicable.

                Contracting Officer: _____________________
                Date: _____________________
                """
            }
        )
    }
}

// MARK: - Helper Functions

private func getCommercialItemClauses() -> [CommercialItemClause] {
    [
        CommercialItemClause(
            id: "52.212-1",
            title: "Instructions to Offerors—Commercial Items",
            prescribedIn: "FAR 12.301(b)(1)",
            applicability: .always
        ),
        CommercialItemClause(
            id: "52.212-2",
            title: "Evaluation—Commercial Items",
            prescribedIn: "FAR 12.301(b)(2)",
            applicability: .always
        ),
        CommercialItemClause(
            id: "52.212-3",
            title: "Offeror Representations and Certifications—Commercial Items",
            prescribedIn: "FAR 12.301(b)(3)",
            applicability: .always
        ),
        CommercialItemClause(
            id: "52.212-4",
            title: "Contract Terms and Conditions—Commercial Items",
            prescribedIn: "FAR 12.301(b)(4)",
            applicability: .always
        ),
        CommercialItemClause(
            id: "52.212-5",
            title: "Contract Terms and Conditions Required to Implement Statutes or Executive Orders",
            prescribedIn: "FAR 12.301(b)(5)",
            applicability: .always
        ),
    ]
}

// MARK: - Dependency

public extension DependencyValues {
    var farPart12Compliance: FARPart12ComplianceService {
        get { self[FARPart12ComplianceService.self] }
        set { self[FARPart12ComplianceService.self] = newValue }
    }
}
