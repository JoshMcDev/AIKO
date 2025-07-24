@testable import AppCore
import XCTest

final class ConfidenceBasedAutoFillTests: XCTestCase {
    var autoFillEngine: ConfidenceBasedAutoFillEngine?
    var smartDefaultsEngine: SmartDefaultsEngine?
    var patternLearningEngine: UserPatternLearningEngine?

    private var autoFillEngineUnwrapped: ConfidenceBasedAutoFillEngine {
        guard let autoFillEngine else { fatalError("autoFillEngine not initialized") }
        return autoFillEngine
    }

    private var smartDefaultsEngineUnwrapped: SmartDefaultsEngine {
        guard let smartDefaultsEngine else { fatalError("smartDefaultsEngine not initialized") }
        return smartDefaultsEngine
    }

    private var patternLearningEngineUnwrapped: UserPatternLearningEngine {
        guard let patternLearningEngine else { fatalError("patternLearningEngine not initialized") }
        return patternLearningEngine
    }

    override func setUp() async throws {
        try await super.setUp()

        // Initialize dependencies
        patternLearningEngine = UserPatternLearningEngine()
        let contextExtractor = UnifiedDocumentContextExtractor()

        smartDefaultsEngine = SmartDefaultsEngine(
            smartDefaultsProvider: SmartDefaultsProvider(),
            patternLearningEngine: patternLearningEngine,
            contextExtractor: contextExtractor
        )

        autoFillEngine = ConfidenceBasedAutoFillEngine(
            configuration: ConfidenceBasedAutoFillEngine.AutoFillConfiguration(
                autoFillThreshold: 0.85,
                suggestionThreshold: 0.65,
                autoFillCriticalFields: false,
                maxAutoFillFields: 10
            ),
            smartDefaultsEngine: smartDefaultsEngine
        )
    }

    func testAutoFillWithHighConfidence() async throws {
        // Prepare test data
        let fields: [RequirementField] = [
            .projectTitle,
            .requiredDate,
            .performanceLocation,
            .fundingSource,
        ]

        let context = SmartDefaultContext(
            sessionId: UUID(),
            userId: "test-user",
            organizationUnit: "Engineering",
            acquisitionType: .supplies,
            extractedData: [
                "projectTitle": "Office Supplies Q4",
                "location": "Building A",
            ],
            fiscalYear: "2024",
            fiscalQuarter: "Q4",
            isEndOfFiscalYear: false,
            daysUntilFYEnd: 90,
            autoFillThreshold: 0.85
        )

        // Train the pattern learning engine with high-confidence patterns
        for _ in 0 ..< 10 {
            let interaction = APEUserInteraction(
                sessionId: UUID(),
                field: .fundingSource,
                suggestedValue: "O&M 2024",
                acceptedSuggestion: true,
                finalValue: "O&M 2024",
                timeToRespond: 2.0,
                documentContext: false
            )
            await patternLearningEngineUnwrapped.learn(from: interaction)
        }

        // Test auto-fill
        let result = await autoFillEngineUnwrapped.analyzeFieldsForAutoFill(
            fields: fields,
            context: context
        )

        // Verify results
        XCTAssertGreaterThan(result.summary.autoFilledCount, 0)
        XCTAssertTrue(result.autoFilledFields.keys.contains(.projectTitle))
        XCTAssertEqual(result.autoFilledFields[.projectTitle] as? String, "Office Supplies Q4")

        // Check summary
        XCTAssertGreaterThan(result.summary.averageConfidence, 0.6)
        XCTAssertGreaterThan(result.summary.timeSaved, 0)
    }

    func testAutoFillWithMixedConfidence() async throws {
        // Prepare fields with varying confidence levels
        let fields: [RequirementField] = [
            .projectTitle, // High confidence from extracted data
            .estimatedValue, // Critical field - should suggest only
            .vendorName, // Low confidence - should skip
            .requiredDate, // Moderate confidence
            .contractType, // High confidence from context
        ]

        let context = SmartDefaultContext(
            sessionId: UUID(),
            userId: "test-user",
            organizationUnit: "Procurement",
            acquisitionType: .supplies,
            extractedData: [
                "projectTitle": "Annual IT Equipment Refresh",
            ],
            fiscalYear: "2024",
            fiscalQuarter: "Q3",
            isEndOfFiscalYear: false,
            daysUntilFYEnd: 120,
            autoFillThreshold: 0.85
        )

        let result = await autoFillEngineUnwrapped.analyzeFieldsForAutoFill(
            fields: fields,
            context: context
        )

        // Verify mixed results
        XCTAssertTrue(result.autoFilledFields.keys.contains(.projectTitle))
        XCTAssertFalse(result.autoFilledFields.keys.contains(.estimatedValue)) // Critical field
        XCTAssertTrue(result.skippedFields.contains(.vendorName)) // Low confidence

        // Check distribution
        let distribution = result.summary.confidenceDistribution
        XCTAssertGreaterThan(distribution.high + distribution.veryHigh, 0)
        XCTAssertGreaterThan(distribution.low + distribution.medium, 0)
    }

    func testAutoFillLimits() async throws {
        // Test with more fields than the limit
        let fields = RequirementField.allCases

        let context = SmartDefaultContext(
            sessionId: UUID(),
            userId: "test-user",
            organizationUnit: "Test Org",
            autoFillThreshold: 0.85
        )

        let result = await autoFillEngineUnwrapped.analyzeFieldsForAutoFill(
            fields: fields,
            context: context
        )

        // Verify limit is respected
        XCTAssertLessThanOrEqual(result.summary.autoFilledCount, 10) // Configuration limit
    }

    func testUserFeedbackProcessing() async throws {
        let field = RequirementField.fundingSource
        let suggestedValue = "O&M 2024"
        let userValue = "RDT&E 2024"

        let context = SmartDefaultContext(
            sessionId: UUID(),
            userId: "test-user",
            organizationUnit: "R&D",
            autoFillThreshold: 0.85
        )

        // Process rejection feedback
        await autoFillEngineUnwrapped.processUserFeedback(
            field: field,
            autoFilledValue: suggestedValue,
            userValue: userValue,
            wasAccepted: false,
            context: context
        )

        // Check metrics
        let metrics = autoFillEngineUnwrapped.getMetrics()
        XCTAssertEqual(metrics.rejectedCount, 1)
        XCTAssertTrue(metrics.rejectedFields.contains(field))

        // Process acceptance feedback
        await autoFillEngineUnwrapped.processUserFeedback(
            field: .contractType,
            autoFilledValue: "Purchase Order",
            userValue: "Purchase Order",
            wasAccepted: true,
            context: context
        )

        let updatedMetrics = autoFillEngineUnwrapped.getMetrics()
        XCTAssertEqual(updatedMetrics.acceptedCount, 1)
        XCTAssertEqual(updatedMetrics.totalFeedbackCount, 2)
        XCTAssertEqual(updatedMetrics.acceptanceRate, 0.5)
    }

    func testAutoFillExplanationGeneration() async throws {
        let summary = ConfidenceBasedAutoFillEngine.AutoFillSummary(
            totalFields: 10,
            autoFilledCount: 6,
            suggestedCount: 2,
            skippedCount: 2,
            averageConfidence: 0.82,
            timeSaved: 135, // 2 minutes 15 seconds
            confidenceDistribution: ConfidenceBasedAutoFillEngine.ConfidenceDistribution(
                veryHigh: 4,
                high: 2,
                medium: 2,
                low: 2
            )
        )

        let result = ConfidenceBasedAutoFillEngine.AutoFillResult(
            autoFilledFields: [:],
            suggestedFields: [:],
            skippedFields: [],
            totalConfidence: 8.2,
            summary: summary
        )

        let explanation = autoFillEngineUnwrapped.generateAutoFillExplanation(result)

        XCTAssertTrue(explanation.contains("6 fields"))
        XCTAssertTrue(explanation.contains("2 more"))
        XCTAssertTrue(explanation.contains("2 minute"))
        XCTAssertTrue(explanation.contains("strong patterns"))
    }

    func testConfidenceColorMapping() {
        XCTAssertEqual(autoFillEngineUnwrapped.getConfidenceColor(for: 0.95), .green)
        XCTAssertEqual(autoFillEngineUnwrapped.getConfidenceColor(for: 0.85), .blue)
        XCTAssertEqual(autoFillEngineUnwrapped.getConfidenceColor(for: 0.70), .orange)
        XCTAssertEqual(autoFillEngineUnwrapped.getConfidenceColor(for: 0.50), .gray)
    }

    func testConfidenceDescriptions() {
        XCTAssertEqual(autoFillEngineUnwrapped.getConfidenceDescription(for: 0.95), "Very High")
        XCTAssertEqual(autoFillEngineUnwrapped.getConfidenceDescription(for: 0.85), "High")
        XCTAssertEqual(autoFillEngineUnwrapped.getConfidenceDescription(for: 0.70), "Moderate")
        XCTAssertEqual(autoFillEngineUnwrapped.getConfidenceDescription(for: 0.55), "Low")
        XCTAssertEqual(autoFillEngineUnwrapped.getConfidenceDescription(for: 0.30), "Very Low")
    }
}
