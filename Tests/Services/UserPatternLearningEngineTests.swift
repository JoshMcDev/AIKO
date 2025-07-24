@testable import AppCore
import XCTest

class UserPatternLearningEngineTests: XCTestCase {
    var sut: UserPatternLearningEngine?

    private var sutUnwrapped: UserPatternLearningEngine {
        guard let sut else { fatalError("sut not initialized") }
        return sut
    }

    override func setUp() {
        super.setUp()
        sut = UserPatternLearningEngine()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Sequence-Aware Prediction Tests

    func testSequenceAwarePrediction() async throws {
        // Create a pattern of field entries
        let field1 = RequirementField.vendorName
        let field2 = RequirementField.estimatedValue
        let field3 = RequirementField.requiredDate

        // Simulate user filling vendor name first, then value, then date
        let interaction1 = APEUserInteraction(
            sessionId: UUID(),
            field: field1,
            finalValue: "Acme Corp",
            timeToRespond: 5,
            documentContext: false
        )
        await sutUnwrapped.learn(from: interaction1)

        let interaction2 = APEUserInteraction(
            sessionId: interaction1.sessionId,
            field: field2,
            finalValue: "50000",
            timeToRespond: 3,
            documentContext: false
        )
        await sutUnwrapped.learn(from: interaction2)

        let interaction3 = APEUserInteraction(
            sessionId: interaction1.sessionId,
            field: field3,
            finalValue: Date().addingTimeInterval(30 * 24 * 60 * 60), // 30 days from now
            timeToRespond: 2,
            documentContext: false
        )
        await sutUnwrapped.learn(from: interaction3)

        // Test sequence-aware prediction
        let previousFields: [RequirementField: Any] = [
            field1: "TechSuppliers Inc",
            field2: "75000",
        ]

        let prediction = await sutUnwrapped.getSequenceAwarePrediction(
            for: field3,
            previousFields: previousFields
        )

        XCTAssertNotNil(prediction, "Should provide sequence-aware prediction")

        guard let unwrappedPrediction = prediction else {
            XCTFail("Failed to unwrap prediction for confidence check")
            return
        }
        XCTAssertTrue(unwrappedPrediction.confidence > 0.5, "Should have reasonable confidence")
    }

    // MARK: - Time-Aware Prediction Tests

    func testTimeAwarePrediction() async throws {
        // Create patterns at specific times
        let field = RequirementField.fundingSource

        // Simulate morning patterns (9 AM)
        var calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 9

        guard let morningDate = calendar.date(from: components) else {
            XCTFail("Failed to create morning date from calendar components")
            return
        }

        for _ in 0 ..< 5 {
            let interaction = APEUserInteraction(
                sessionId: UUID(),
                field: field,
                finalValue: "O&M FY2025",
                timeToRespond: 2,
                documentContext: false
            )
            await sutUnwrapped.learn(from: interaction)
        }

        // Get time-aware prediction
        let prediction = await sutUnwrapped.getTimeAwarePrediction(for: field)

        XCTAssertNotNil(prediction, "Should provide time-aware prediction")
    }

    // MARK: - Cohort-Based Prediction Tests

    func testCohortBasedPrediction() async throws {
        // Create patterns for similar users
        let field = RequirementField.contractType
        let userProfile = ConversationUserProfile(
            id: UUID(),
            name: "Test User",
            role: "Contracting Officer",
            department: "IT Services",
            clearanceLevel: "Public Trust",
            preferences: [:],
            historicalPatterns: [],
            sessionHistory: []
        )

        // Simulate multiple users with similar profiles
        for i in 0 ..< 10 {
            let interaction = APEUserInteraction(
                sessionId: UUID(),
                field: field,
                finalValue: "Fixed Price",
                timeToRespond: 3,
                documentContext: false
            )
            await sutUnwrapped.learn(from: interaction)
        }

        // Get cohort-based prediction
        let prediction = await sutUnwrapped.getCohortPrediction(
            for: field,
            userProfile: userProfile
        )

        XCTAssertNotNil(prediction, "Should provide cohort-based prediction")
        XCTAssertEqual(prediction?.value as? String, "Fixed Price", "Should predict most common value")
    }

    // MARK: - Batch Prediction Tests

    func testBatchPrediction() async throws {
        // Create correlated field patterns
        let vendorField = RequirementField.vendorName
        let valueField = RequirementField.estimatedValue
        let dateField = RequirementField.requiredDate

        // Create patterns where these fields are often filled together
        for i in 0 ..< 5 {
            let sessionId = UUID()

            let vendorInteraction = APEUserInteraction(
                sessionId: sessionId,
                field: vendorField,
                finalValue: "Vendor \(i)",
                timeToRespond: 2,
                documentContext: false
            )
            await sutUnwrapped.learn(from: vendorInteraction)

            let valueInteraction = APEUserInteraction(
                sessionId: sessionId,
                field: valueField,
                finalValue: 10000 * (i + 1),
                timeToRespond: 3,
                documentContext: false
            )
            await sutUnwrapped.learn(from: valueInteraction)

            let dateInteraction = APEUserInteraction(
                sessionId: sessionId,
                field: dateField,
                finalValue: Date().addingTimeInterval(Double(30 + i * 5) * 24 * 60 * 60),
                timeToRespond: 2,
                documentContext: false
            )
            await sutUnwrapped.learn(from: dateInteraction)
        }

        // Test batch prediction
        let context = ConversationContext(
            acquisitionType: .supplies,
            uploadedDocuments: []
        )

        let predictions = await sutUnwrapped.batchPredict(
            fields: [vendorField, valueField, dateField],
            context: context
        )

        XCTAssertFalse(predictions.isEmpty, "Should provide batch predictions")
        XCTAssertGreaterThanOrEqual(predictions.count, 1, "Should predict at least one field")
    }

    // MARK: - Pattern Confidence Tests

    func testPatternConfidenceIncreasesWithRepetition() async throws {
        let field = RequirementField.fundingSource
        let value = "O&M FY2025"

        var previousConfidence: Float = 0

        // Learn the same pattern multiple times
        for i in 1 ... 10 {
            let interaction = APEUserInteraction(
                sessionId: UUID(),
                field: field,
                finalValue: value,
                timeToRespond: 2,
                documentContext: false
            )
            await sutUnwrapped.learn(from: interaction)

            let prediction = await sutUnwrapped.getDefault(for: field)

            if let prediction {
                XCTAssertGreaterThanOrEqual(
                    prediction.confidence,
                    previousConfidence,
                    "Confidence should increase or stay same with repetition"
                )
                previousConfidence = prediction.confidence
            }
        }

        XCTAssertGreaterThan(previousConfidence, 0.7, "Should have high confidence after many repetitions")
    }

    // MARK: - Integration Tests

    func testSmartDefaultsEngineIntegration() async throws {
        // This would test the integration with SmartDefaultsEngine
        // For now, just verify the pattern learning engine can provide defaults

        let field = RequirementField.vendorName

        // Create some patterns
        for i in 0 ..< 3 {
            let interaction = APEUserInteraction(
                sessionId: UUID(),
                field: field,
                finalValue: "TestVendor\(i)",
                timeToRespond: 2,
                documentContext: false
            )
            await sutUnwrapped.learn(from: interaction)
        }

        // Verify we can get a default
        let defaultValue = await sutUnwrapped.getDefault(for: field)
        XCTAssertNotNil(defaultValue, "Should provide a default value")
    }
}
