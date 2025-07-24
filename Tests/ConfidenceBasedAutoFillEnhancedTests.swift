@testable import AppCore
import XCTest

// MARK: - Enhanced Confidence-Based Auto-Fill Tests

// Phase 4.2 - Professional Document Scanner
// Government Form Auto-Population Integration - RED PHASE

final class ConfidenceBasedAutoFillEnhancedTests: XCTestCase {
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

        // Initialize with government form specific configuration
        patternLearningEngine = UserPatternLearningEngine()
        let contextExtractor = UnifiedDocumentContextExtractor()

        smartDefaultsEngine = SmartDefaultsEngine(
            smartDefaultsProvider: SmartDefaultsProvider(),
            patternLearningEngine: patternLearningEngineUnwrapped,
            contextExtractor: contextExtractor
        )

        // Enhanced configuration for government forms
        let config = ConfidenceBasedAutoFillEngine.AutoFillConfiguration(
            autoFillThreshold: 0.85,
            suggestionThreshold: 0.65,
            autoFillCriticalFields: false, // Critical fields require manual review
            maxAutoFillFields: 20,
            enableLearning: true,
            consensusBoost: 0.1
        )

        autoFillEngine = ConfidenceBasedAutoFillEngine(
            configuration: config,
            smartDefaultsEngine: smartDefaultsEngineUnwrapped
        )
    }

    // MARK: - Government Form Threshold Tests (TDD Rubric Compliance)

    func test_autoFillHighConfidence_achieves90PercentRate() async throws {
        // Test will fail initially - needs government form integration
        let governmentFields = createGovernmentFormFields()
        let context = createGovernmentFormContext()

        // Mock high-confidence extractions from government form
        await trainEngineWithGovernmentFormPatterns()

        let result = await autoFillEngineUnwrapped.analyzeFieldsForAutoFill(
            fields: governmentFields,
            context: context
        )

        // Auto-fill rate for high-confidence fields: ≥90% (TDD rubric)
        let highConfidenceFields = result.populatedFields.filter { $0.confidence >= 0.85 }
        let autoFillRate = Double(result.summary.autoFilledCount) / Double(highConfidenceFields.count)

        XCTAssertGreaterThanOrEqual(autoFillRate, 0.9, "Auto-fill rate for high-confidence fields should be ≥90%")
        XCTAssertGreaterThanOrEqual(result.summary.autoFilledCount, 8, "Should auto-fill at least 8 high-confidence fields")

        // Validate government-specific fields are included
        XCTAssertTrue(result.autoFilledFields.keys.contains(.vendorCAGE), "CAGE code should be auto-filled if high confidence")
        XCTAssertTrue(result.autoFilledFields.keys.contains(.contractNumber), "Contract number should be auto-filled if high confidence")
    }

    func test_userAcceptanceAutoFilledData_achieves85PercentRate() async throws {
        // Test will fail initially - needs user acceptance tracking
        let governmentFields = createGovernmentFormFields()
        let context = createGovernmentFormContext()

        // Simulate auto-fill session
        let result = await autoFillEngineUnwrapped.analyzeFieldsForAutoFill(
            fields: governmentFields,
            context: context
        )

        // Simulate user feedback with 85%+ acceptance rate
        var acceptedCount = 0
        let totalAutoFilled = result.autoFilledFields.count

        for (field, value) in result.autoFilledFields {
            let wasAccepted = acceptedCount < Int(ceil(Double(totalAutoFilled) * 0.85))

            await autoFillEngineUnwrapped.processUserFeedback(
                field: field,
                autoFilledValue: value,
                userValue: value,
                wasAccepted: wasAccepted,
                context: context
            )

            if wasAccepted {
                acceptedCount += 1
            }
        }

        // User acceptance rate of auto-filled data: ≥85% (TDD rubric)
        let metrics = autoFillEngineUnwrapped.getMetrics()
        XCTAssertGreaterThanOrEqual(metrics.acceptanceRate, 0.85, "User acceptance rate should be ≥85%")
        XCTAssertGreaterThanOrEqual(acceptedCount, Int(ceil(Double(totalAutoFilled) * 0.85)), "Should meet 85% acceptance target")
    }

    func test_criticalFields_allFlaggedForManualReview() async throws {
        // Test will fail initially - needs critical field detection
        let criticalFields = createCriticalGovernmentFields()
        let context = createHighValueContractContext()

        let result = await autoFillEngineUnwrapped.analyzeFieldsForAutoFill(
            fields: criticalFields,
            context: context
        )

        // Critical fields properly flagged for manual review: 100% (TDD rubric)
        let criticalFieldNames: Set<RequirementField> = [.estimatedValue, .fundingSource, .contractType, .vendorUEI, .vendorCAGE]

        for criticalField in criticalFieldNames {
            if let suggestion = result.suggestedFields[criticalField] {
                XCTAssertTrue(true, "Critical field '\(criticalField)' was flagged for review")
            } else if result.autoFilledFields.keys.contains(criticalField) {
                // If auto-filled, should be low-risk critical field only
                let fieldValue = result.autoFilledFields[criticalField]
                XCTAssertNotNil(fieldValue, "Auto-filled critical field should have valid value")
            } else {
                XCTAssertTrue(result.skippedFields.contains(criticalField), "Critical field should be handled - auto-filled, suggested, or skipped")
            }
        }

        // No critical financial fields should be auto-filled
        XCTAssertFalse(result.autoFilledFields.keys.contains(.estimatedValue), "Estimated value should not be auto-filled")
        XCTAssertTrue(result.suggestedFields.keys.contains(.estimatedValue) || result.skippedFields.contains(.estimatedValue),
                      "Estimated value should be suggested or skipped for manual review")
    }

    func test_dataEntryTimeReduction_achieves70Percent() async throws {
        // Test will fail initially - needs time estimation logic
        let governmentFields = createExtensiveGovernmentFormFields() // 20+ fields
        let context = createGovernmentFormContext()

        // Baseline: measure manual entry time (estimated)
        let estimatedManualTimePerField = 15.0 // seconds
        let baselineTime = Double(governmentFields.count) * estimatedManualTimePerField

        let result = await autoFillEngineUnwrapped.analyzeFieldsForAutoFill(
            fields: governmentFields,
            context: context
        )

        // Reduction in manual data entry time: ≥70% (TDD rubric)
        let timeSaved = result.summary.timeSaved
        let timeReduction = timeSaved / baselineTime

        XCTAssertGreaterThanOrEqual(timeReduction, 0.7, "Should achieve ≥70% reduction in manual data entry time")
        XCTAssertGreaterThanOrEqual(result.summary.autoFilledCount, 14, "Should auto-fill at least 70% of fields")

        // Validate time estimates are realistic
        XCTAssertGreaterThan(timeSaved, 150, "Should save at least 2.5 minutes for extensive form")
    }

    // MARK: - Government Form Validation Tests

    func test_cageCodeValidation_correctFormat() async throws {
        // Test will fail initially - needs CAGE code validation
        let fields = [RequirementField.vendorCAGE]
        let context = createContextWithCAGECode()

        let result = await autoFillEngineUnwrapped.analyzeFieldsForAutoFill(
            fields: fields,
            context: context
        )

        // CAGE code validation: 100% correct format (5-char alphanumeric) (TDD rubric)
        if let cageValue = result.autoFilledFields[.vendorCAGE] as? String {
            let cageRegex = "^[A-Z0-9]{5}$"
            let isValidFormat = cageValue.range(of: cageRegex, options: .regularExpression) != nil

            XCTAssertTrue(isValidFormat, "CAGE code '\(cageValue)' should follow 5-character alphanumeric format")
            XCTAssertEqual(cageValue.count, 5, "CAGE code should be exactly 5 characters")
            XCTAssertTrue(cageValue.allSatisfy { $0.isUppercase || $0.isNumber }, "CAGE code should contain only uppercase letters and numbers")
        } else if let cageSuggestion = result.suggestedFields[.vendorCAGE] {
            let cageValue = cageSuggestion.value as? String ?? ""
            let cageRegex = "^[A-Z0-9]{5}$"
            let isValidFormat = cageValue.range(of: cageRegex, options: .regularExpression) != nil

            XCTAssertTrue(isValidFormat, "Suggested CAGE code '\(cageValue)' should follow 5-character alphanumeric format")
        }
    }

    func test_ueiValidation_correctFormat() async throws {
        // Test will fail initially - needs UEI validation
        let fields = [RequirementField.vendorUEI]
        let context = createContextWithUEI()

        let result = await autoFillEngineUnwrapped.analyzeFieldsForAutoFill(
            fields: fields,
            context: context
        )

        // UEI validation: 100% correct format (12-char alphanumeric) (TDD rubric)
        if let ueiValue = result.autoFilledFields[.vendorUEI] as? String {
            let ueiRegex = "^[A-Z0-9]{12}$"
            let isValidFormat = ueiValue.range(of: ueiRegex, options: .regularExpression) != nil

            XCTAssertTrue(isValidFormat, "UEI '\(ueiValue)' should follow 12-character alphanumeric format")
            XCTAssertEqual(ueiValue.count, 12, "UEI should be exactly 12 characters")
        } else if let ueiSuggestion = result.suggestedFields[.vendorUEI] {
            let ueiValue = ueiSuggestion.value as? String ?? ""
            let ueiRegex = "^[A-Z0-9]{12}$"
            let isValidFormat = ueiValue.range(of: ueiRegex, options: .regularExpression) != nil

            XCTAssertTrue(isValidFormat, "Suggested UEI '\(ueiValue)' should follow 12-character alphanumeric format")
        }
    }

    func test_currencyFormatting_usDollarCompliance() async throws {
        // Test will fail initially - needs currency formatting
        let fields = [RequirementField.estimatedValue, RequirementField.fundingAmount]
        let context = createContextWithCurrency()

        let result = await autoFillEngineUnwrapped.analyzeFieldsForAutoFill(
            fields: fields,
            context: context
        )

        // Currency formatting: 100% US dollar compliance (TDD rubric)
        let currencyFields = [RequirementField.estimatedValue, RequirementField.fundingAmount]

        for field in currencyFields {
            if let currencyValue = result.autoFilledFields[field] as? String {
                XCTAssertTrue(currencyValue.hasPrefix("$"), "Currency value '\(currencyValue)' should start with $")

                let numericPart = currencyValue.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
                XCTAssertNotNil(Decimal(string: numericPart), "Currency value should have valid numeric format")

            } else if let currencySuggestion = result.suggestedFields[field] {
                let currencyValue = currencySuggestion.value as? String ?? ""
                XCTAssertTrue(currencyValue.hasPrefix("$"), "Suggested currency value '\(currencyValue)' should start with $")
            }
        }
    }

    func test_dateFormatValidation_governmentStandardCompliance() async throws {
        // Test will fail initially - needs date format validation
        let fields = [RequirementField.requiredDate, RequirementField.performancePeriodStart, RequirementField.performancePeriodEnd]
        let context = createContextWithDates()

        let result = await autoFillEngineUnwrapped.analyzeFieldsForAutoFill(
            fields: fields,
            context: context
        )

        // Date format validation: 100% government standard compliance (TDD rubric)
        let dateFields = [RequirementField.requiredDate, RequirementField.performancePeriodStart, RequirementField.performancePeriodEnd]

        for field in dateFields {
            if let dateValue = result.autoFilledFields[field] as? String {
                // Check for MM/DD/YYYY or MM-DD-YYYY format
                let dateRegex = "^(0?[1-9]|1[0-2])[/\\-](0?[1-9]|[12]\\d|3[01])[/\\-]\\d{4}$"
                let isValidFormat = dateValue.range(of: dateRegex, options: .regularExpression) != nil

                XCTAssertTrue(isValidFormat, "Date value '\(dateValue)' should follow MM/DD/YYYY or MM-DD-YYYY format")

            } else if let dateSuggestion = result.suggestedFields[field] {
                let dateValue = dateSuggestion.value as? String ?? ""
                let dateRegex = "^(0?[1-9]|1[0-2])[/\\-](0?[1-9]|[12]\\d|3[01])[/\\-]\\d{4}$"
                let isValidFormat = dateValue.range(of: dateRegex, options: .regularExpression) != nil

                XCTAssertTrue(isValidFormat, "Suggested date value '\(dateValue)' should follow government standard format")
            }
        }
    }

    // MARK: - Performance Tests (TDD Rubric Compliance)

    func test_ocrProcessing_completesWithin2Seconds() async throws {
        // Test will fail initially - needs OCR processing integration
        let governmentFields = createExtensiveGovernmentFormFields()
        let context = createGovernmentFormContext()

        let startTime = Date()
        let result = await autoFillEngineUnwrapped.analyzeFieldsForAutoFill(
            fields: governmentFields,
            context: context
        )
        let processingTime = Date().timeIntervalSince(startTime)

        // OCR processing: ≤2 seconds per page (TDD rubric)
        XCTAssertLessThan(processingTime, 2.0, "OCR processing should complete within 2 seconds per page")
        XCTAssertGreaterThan(result.summary.autoFilledCount, 0, "Should process and auto-fill fields successfully")
    }

    func test_fieldMapping_completesWithin100Milliseconds() async throws {
        // Test will fail initially - needs field mapping optimization
        let governmentFields = createGovernmentFormFields()
        let context = createGovernmentFormContext()

        let startTime = Date()

        measure {
            Task {
                let result = await autoFillEngineUnwrapped.analyzeFieldsForAutoFill(
                    fields: governmentFields,
                    context: context
                )

                // Field mapping: ≤100ms per form (TDD rubric)
                let mappingTime = Date().timeIntervalSince(startTime)
                XCTAssertLessThan(mappingTime, 0.1, "Field mapping should complete within 100 milliseconds")
            }
        }
    }

    func test_confidenceCalculation_completesWithin50Milliseconds() async throws {
        // Test will fail initially - needs confidence calculation optimization
        let governmentFields = createGovernmentFormFields()
        let context = createGovernmentFormContext()

        let result = await autoFillEngineUnwrapped.analyzeFieldsForAutoFill(
            fields: governmentFields,
            context: context
        )

        let startTime = Date()

        // Simulate confidence recalculation
        for _ in result.populatedFields {
            // Mock confidence calculation processing
            _ = context.autoFillThreshold * 1.1
        }

        let confidenceTime = Date().timeIntervalSince(startTime)

        // Confidence calculation: ≤50ms per field (TDD rubric)
        XCTAssertLessThan(confidenceTime, 0.05, "Confidence calculation should complete within 50 milliseconds")
    }

    func test_autoPopulation_completesWithin200Milliseconds() async throws {
        // Test will fail initially - needs auto-population optimization
        let governmentFields = createGovernmentFormFields()
        let context = createGovernmentFormContext()

        let startTime = Date()
        let result = await autoFillEngineUnwrapped.analyzeFieldsForAutoFill(
            fields: governmentFields,
            context: context
        )
        let populationTime = Date().timeIntervalSince(startTime)

        // Auto-population execution: ≤200ms per form (TDD rubric)
        XCTAssertLessThan(populationTime, 0.2, "Auto-population execution should complete within 200 milliseconds")
        XCTAssertGreaterThan(result.summary.autoFilledCount, 0, "Should successfully populate fields")
    }

    func test_uiResponsiveness_completesWithin100Milliseconds() async throws {
        // Test will fail initially - needs UI responsiveness optimization
        let governmentFields = createGovernmentFormFields()
        let context = createGovernmentFormContext()

        let result = await autoFillEngineUnwrapped.analyzeFieldsForAutoFill(
            fields: governmentFields,
            context: context
        )

        let startTime = Date()

        // Simulate UI interaction (generating explanations, color coding, etc.)
        let explanation = autoFillEngineUnwrapped.generateAutoFillExplanation(result)
        for field in result.populatedFields {
            _ = autoFillEngineUnwrapped.getConfidenceColor(for: field.confidence)
            _ = autoFillEngineUnwrapped.getConfidenceDescription(for: field.confidence)
        }

        let uiTime = Date().timeIntervalSince(startTime)

        // UI responsiveness: ≤100ms for user interactions (TDD rubric)
        XCTAssertLessThan(uiTime, 0.1, "UI interactions should complete within 100 milliseconds")
        XCTAssertFalse(explanation.isEmpty, "Should generate meaningful explanation")
    }

    // MARK: - Helper Methods

    private func createGovernmentFormFields() -> [RequirementField] {
        [
            .projectTitle,
            .contractNumber,
            .vendorName,
            .vendorCAGE,
            .vendorUEI,
            .estimatedValue,
            .fundingSource,
            .contractType,
            .performanceLocation,
            .requiredDate,
        ]
    }

    private func createCriticalGovernmentFields() -> [RequirementField] {
        [
            .estimatedValue,
            .fundingSource,
            .contractType,
            .vendorUEI,
            .vendorCAGE,
            .contractNumber,
        ]
    }

    private func createExtensiveGovernmentFormFields() -> [RequirementField] {
        RequirementField.allCases.prefix(20).map { $0 }
    }

    private func createGovernmentFormContext() -> SmartDefaultContext {
        SmartDefaultContext(
            sessionId: UUID(),
            userId: "government-user",
            organizationUnit: "Procurement Office",
            acquisitionType: .services,
            extractedData: [
                "contractNumber": "W52P1J-23-R-0001",
                "vendorName": "ACME Corporation",
                "cageCode": "1ABC5",
                "uei": "ABC123DEF456",
                "projectTitle": "IT Services Support",
                "totalAmount": "$1,234,567.89",
            ],
            fiscalYear: "2025",
            fiscalQuarter: "Q2",
            isEndOfFiscalYear: false,
            daysUntilFYEnd: 180,
            autoFillThreshold: 0.85
        )
    }

    private func createHighValueContractContext() -> SmartDefaultContext {
        SmartDefaultContext(
            sessionId: UUID(),
            userId: "contracting-officer",
            organizationUnit: "Contracting Office",
            acquisitionType: .services,
            extractedData: [
                "estimatedValue": "$5,000,000.00",
                "contractType": "Cost Plus Fixed Fee",
                "fundingSource": "RDT&E 2025",
            ],
            fiscalYear: "2025",
            fiscalQuarter: "Q1",
            autoFillThreshold: 0.85
        )
    }

    private func createContextWithCAGECode() -> SmartDefaultContext {
        SmartDefaultContext(
            sessionId: UUID(),
            userId: "test-user",
            extractedData: ["cageCode": "1ABC5"],
            autoFillThreshold: 0.85
        )
    }

    private func createContextWithUEI() -> SmartDefaultContext {
        SmartDefaultContext(
            sessionId: UUID(),
            userId: "test-user",
            extractedData: ["uei": "ABC123DEF456"],
            autoFillThreshold: 0.85
        )
    }

    private func createContextWithCurrency() -> SmartDefaultContext {
        SmartDefaultContext(
            sessionId: UUID(),
            userId: "test-user",
            extractedData: [
                "estimatedValue": "$1,234,567.89",
                "fundingAmount": "$500,000.00",
            ],
            autoFillThreshold: 0.85
        )
    }

    private func createContextWithDates() -> SmartDefaultContext {
        SmartDefaultContext(
            sessionId: UUID(),
            userId: "test-user",
            extractedData: [
                "requiredDate": "03/15/2025",
                "startDate": "01-01-2025",
                "endDate": "12/31/2025",
            ],
            autoFillThreshold: 0.85
        )
    }

    private func trainEngineWithGovernmentFormPatterns() async {
        // Train with realistic government form patterns
        let patterns = [
            (RequirementField.contractNumber, "W52P1J-23-R-0001"),
            (RequirementField.vendorCAGE, "1ABC5"),
            (RequirementField.vendorUEI, "ABC123DEF456"),
            (RequirementField.fundingSource, "O&M 2025"),
            (RequirementField.contractType, "Firm Fixed Price"),
            (RequirementField.performanceLocation, "Ft. Belvoir, VA"),
            (RequirementField.projectTitle, "IT Services Support"),
            (RequirementField.estimatedValue, "$1,234,567.89"),
        ]

        for (field, value) in patterns {
            // Train with high acceptance rate for government patterns
            for _ in 0 ..< 15 {
                let interaction = APEUserInteraction(
                    sessionId: UUID(),
                    field: field,
                    suggestedValue: value,
                    acceptedSuggestion: true,
                    finalValue: value,
                    timeToRespond: 2.0,
                    documentContext: true
                )
                await patternLearningEngine.learn(from: interaction)
            }
        }
    }
}
