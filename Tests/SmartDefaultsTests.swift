@testable import AppCore
import ComposableArchitecture
import XCTest

// MARK: - Smart Defaults System Tests

@MainActor
final class SmartDefaultsTests: XCTestCase {
    func testSmartDefaultsProvider() async throws {
        // Setup
        let provider = SmartDefaultsProvider()
        let context = SmartDefaultsProvider.DefaultsContext(
            userId: "test.user",
            organizationUnit: "Test Division",
            acquisitionType: .supplies,
            documentType: .requestForQuote,
            extractedData: [
                "vendor": "Acme Corp",
                "totalValue": "50000",
            ],
            userPatterns: [],
            organizationalRules: [
                SmartDefaultsProvider.OrganizationalRule(
                    field: "approver",
                    condition: "value >= 5000 AND value < 25000",
                    value: "Department Head",
                    priority: 10
                ),
            ],
            timeContext: SmartDefaultsProvider.TimeContext(
                currentDate: Date(),
                fiscalYear: "FY2025",
                quarter: "Q2",
                isEndOfFiscalYear: false,
                daysUntilFYEnd: 180
            )
        )

        // Test
        let defaults = await provider.getSmartDefaults(for: .requestForQuote, context: context)

        // Verify
        XCTAssertFalse(defaults.isEmpty)

        // Check vendor extraction
        if let vendorDefault = defaults.first(where: { $0.field == "vendor" }) {
            XCTAssertEqual(vendorDefault.value, "Acme Corp")
            XCTAssertEqual(vendorDefault.source, .documentExtraction)
            XCTAssertGreaterThanOrEqual(vendorDefault.confidence, 0.9)
        }

        // Check organizational rule application
        if let approverDefault = defaults.first(where: { $0.field == "approver" }) {
            XCTAssertEqual(approverDefault.value, "Department Head")
            XCTAssertEqual(approverDefault.source, .organizationalRule)
        }
    }

    func testSmartDefaultsEngine() async throws {
        // Setup
        let patternEngine = UserPatternLearningEngine()
        let engine = SmartDefaultsEngine.create(patternLearningEngine: patternEngine)

        let context = SmartDefaultContext(
            sessionId: UUID(),
            userId: "test.user",
            organizationUnit: "Test Division",
            acquisitionType: .supplies,
            documentType: .requestForQuote,
            extractedData: ["vendorName": "Test Vendor"],
            fiscalYear: "FY2025",
            fiscalQuarter: "Q2",
            isEndOfFiscalYear: false,
            daysUntilFYEnd: 180,
            autoFillThreshold: 0.8
        )

        // Test single field
        let vendorDefault = await engine.getSmartDefault(for: .vendorName, context: context)
        XCTAssertNotNil(vendorDefault)
        XCTAssertEqual(vendorDefault?.value as? String, "Test Vendor")
        XCTAssertEqual(vendorDefault?.source, .documentContext)

        // Test multiple fields
        let fields: [RequirementField] = [.vendorName, .requiredDate, .fundingSource]
        let defaults = await engine.getSmartDefaults(for: fields, context: context)
        XCTAssertFalse(defaults.isEmpty)
    }

    func testConfidenceBasedAutoFill() async throws {
        // Setup
        let patternEngine = UserPatternLearningEngine()
        let engine = SmartDefaultsEngine.create(patternLearningEngine: patternEngine)

        let context = SmartDefaultContext(
            autoFillThreshold: 0.85
        )

        // Create sample fields with varying confidence
        let fields: [RequirementField] = [
            .vendorName,
            .requiredDate,
            .estimatedValue,
            .justification,
        ]

        // Test auto-fill candidates
        let candidates = await engine.getAutoFillCandidates(fields: fields, context: context)

        // High confidence fields should be auto-fill candidates
        // Low confidence fields should not
        XCTAssertTrue(candidates.count < fields.count)
    }

    func testLearningFromUserFeedback() async throws {
        // Setup
        let patternEngine = UserPatternLearningEngine()
        let engine = SmartDefaultsEngine.create(patternLearningEngine: patternEngine)

        let context = SmartDefaultContext(sessionId: UUID())

        // Test learning from acceptance
        await engine.learn(
            field: .vendorName,
            suggestedValue: "Suggested Vendor",
            acceptedValue: "Suggested Vendor",
            wasAccepted: true,
            context: context
        )

        // Test learning from rejection
        await engine.learn(
            field: .requiredDate,
            suggestedValue: "01/15/2025",
            acceptedValue: "02/01/2025",
            wasAccepted: false,
            context: context
        )

        // Verify cache invalidation
        engine.clearCache()
    }

    func testContextualDefaultsGeneration() async throws {
        // Setup
        let provider = EnhancedContextualDefaultsProvider()

        let factors = EnhancedContextualDefaultsProvider.ContextualFactors(
            currentDate: Date(),
            fiscalYear: "FY2025",
            fiscalQuarter: "Q2",
            isEndOfFiscalYear: true,
            daysUntilFYEnd: 30,
            isEndOfQuarter: false,
            daysUntilQuarterEnd: 60,
            timeOfDay: .afternoon,
            dayOfWeek: .wednesday,
            organizationUnit: "Test Unit",
            department: "Contracting",
            location: "Building 123",
            budgetRemaining: 100_000,
            typicalPurchaseAmount: 25000,
            approvalLevels: [],
            recentAcquisitions: [],
            vendorPreferences: [],
            seasonalPatterns: [],
            currentWorkload: .high,
            urgentRequests: 5,
            pendingApprovals: 10,
            teamCapacity: 0.8,
            requiredClauses: [],
            setAsideGoals: EnhancedContextualDefaultsProvider.SetAsideGoals(
                smallBusiness: 0.23,
                womanOwned: 0.05,
                veteranOwned: 0.03,
                hubZone: 0.03,
                currentProgress: ["smallBusiness": 0.15]
            ),
            socioeconomicTargets: []
        )

        // Test contextual defaults
        let fields: [RequirementField] = [.requiredDate, .priority, .fundingSource]
        let defaults = await provider.generateContextualDefaults(for: fields, factors: factors)

        // Verify end of fiscal year affects priority
        if let priorityDefault = defaults[.priority] {
            XCTAssertEqual(priorityDefault.value as? String, "Urgent")
            XCTAssertTrue(priorityDefault.reasoning.contains("fiscal year"))
        }
    }

    func testMinimalQuestioningResult() async throws {
        // Setup
        let patternEngine = UserPatternLearningEngine()
        let engine = SmartDefaultsEngine.create(patternLearningEngine: patternEngine)

        let context = SmartDefaultContext(
            extractedData: [
                "vendorName": "Known Vendor",
                "estimatedValue": "50000",
            ],
            autoFillThreshold: 0.85
        )

        let fields: [RequirementField] = [
            .vendorName,
            .estimatedValue,
            .justification,
            .requiredDate,
            .fundingSource,
        ]

        // Test minimal questioning
        let result = await engine.getMinimalQuestioningDefaults(for: fields, context: context)

        // Verify categorization
        XCTAssertFalse(result.autoFillFields.isEmpty)
        XCTAssertTrue(result.mustAskFields.contains(.justification))

        // Auto-filled should include extracted data
        XCTAssertNotNil(result.autoFillFields[.vendorName])
        XCTAssertNotNil(result.autoFillFields[.estimatedValue])
    }
}

// MARK: - Test Helpers

extension SmartDefaultsTests {
    func createTestContext(
        fiscalYearEnd: Bool = false,
        extractedData: [String: String] = [:]
    ) -> SmartDefaultContext {
        SmartDefaultContext(
            sessionId: UUID(),
            userId: "test.user",
            organizationUnit: "Test Unit",
            acquisitionType: .supplies,
            documentType: .requestForQuote,
            extractedData: extractedData,
            fiscalYear: "FY2025",
            fiscalQuarter: "Q2",
            isEndOfFiscalYear: fiscalYearEnd,
            daysUntilFYEnd: fiscalYearEnd ? 30 : 180,
            autoFillThreshold: 0.8
        )
    }
}
