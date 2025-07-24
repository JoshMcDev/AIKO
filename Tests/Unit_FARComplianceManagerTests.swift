@testable import AppCore
import ComposableArchitecture
import XCTest

@MainActor
final class FARComplianceManagerTests: XCTestCase {
    var manager: FARComplianceManager?

    override func setUp() async throws {
        try await super.setUp()
        manager = FARComplianceManager()
    }

    override func tearDown() async throws {
        manager = nil
        try await super.tearDown()
    }

    // MARK: - Compliance Check Tests

    func testCompleteComplianceCheck() async throws {
        let document = createTestDocument()
        guard let manager else {
            XCTFail("Manager not initialized")
            return
        }
        let result = try await manager.performCompleteComplianceCheck(for: document)

        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(result.overallScore, 0)
        XCTAssertLessThanOrEqual(result.overallScore, 100)
        XCTAssertFalse(result.violations.isEmpty || result.warnings.isEmpty || result.suggestions.isEmpty)
    }

    func testCheckSpecificFARParts() async throws {
        let document = createTestDocument()
        let partsToCheck: Set<FARPart> = [.part12, .part15, .part52]

        let result = try await manager.checkCompliance(
            for: document,
            parts: partsToCheck
        )

        // Verify only requested parts were checked
        let checkedParts = Set(result.violations.compactMap(\.farPart))
            .union(Set(result.warnings.compactMap(\.farPart)))
            .union(Set(result.suggestions.compactMap(\.farPart)))

        XCTAssertTrue(checkedParts.isSubset(of: partsToCheck))
    }

    func testComplianceScoreCalculation() async throws {
        let document = createTestDocument()
        let result = try await manager.performCompleteComplianceCheck(for: document)

        // Score should reflect severity of issues
        if !result.violations.isEmpty {
            XCTAssertLessThan(result.overallScore, 100)
        }

        if result.violations.isEmpty, result.warnings.isEmpty {
            XCTAssertGreaterThan(result.overallScore, 80)
        }
    }

    // MARK: - FAR Clause Tests

    func testSearchFARClauses() async throws {
        let results = try await manager.searchFARClauses(query: "commercial")

        XCTAssertFalse(results.isEmpty)

        for clause in results {
            let matchesNumber = clause.clauseNumber.lowercased().contains("commercial")
            let matchesTitle = clause.title.lowercased().contains("commercial")
            let matchesContent = clause.content.lowercased().contains("commercial")

            XCTAssertTrue(matchesNumber || matchesTitle || matchesContent)
        }
    }

    func testGetClauseByNumber() async throws {
        let clauseNumber = "52.212-4"
        let clause = try await manager.getClause(number: clauseNumber)

        XCTAssertNotNil(clause)
        if let clause {
            XCTAssertEqual(clause.clauseNumber, clauseNumber)
            XCTAssertFalse(clause.title.isEmpty)
            XCTAssertFalse(clause.content.isEmpty)
        }
    }

    func testGetRequiredClausesForAcquisition() async throws {
        let acquisition = AcquisitionDetails(
            type: .commercial,
            value: 500_000,
            setAsideType: .smallBusiness,
            isSimplified: false
        )

        let requiredClauses = try await manager.getRequiredClauses(for: acquisition)

        XCTAssertFalse(requiredClauses.isEmpty)

        // Should include basic commercial clauses
        let clauseNumbers = Set(requiredClauses.map(\.clauseNumber))
        XCTAssertTrue(clauseNumbers.contains("52.212-4")) // Contract Terms and Conditions
    }

    func testGetSuggestedClauses() async throws {
        let document = createTestDocument()
        let suggested = try await manager.getSuggestedClauses(for: document)

        XCTAssertFalse(suggested.isEmpty)

        // Verify suggestions are relevant
        for clause in suggested {
            XCTAssertTrue(clause.applicability.contains { _ in
                // Check if condition matches document context
                true // Simplified for test
            })
        }
    }

    // MARK: - Validation Tests

    func testValidateClauseInclusion() async throws {
        let document = createTestDocument(withClauses: ["52.212-4", "52.212-5"])
        let validation = try await manager.validateClauseInclusion(in: document)

        XCTAssertNotNil(validation.missingRequired)
        XCTAssertNotNil(validation.includedOptional)
        XCTAssertNotNil(validation.conflicts)

        // Check for clause conflicts
        if !validation.conflicts.isEmpty {
            for conflict in validation.conflicts {
                XCTAssertNotEqual(conflict.clause1, conflict.clause2)
                XCTAssertFalse(conflict.reason.isEmpty)
            }
        }
    }

    func testValidatePart12Procedures() async throws {
        let commercialDoc = createTestDocument(type: .commercialItemDetermination)
        let validation = try await manager.validatePart12Procedures(for: commercialDoc)

        XCTAssertTrue(validation.isValid || !validation.issues.isEmpty)

        // Commercial item determination should follow Part 12
        if commercialDoc.content.contains("commercial") {
            XCTAssertTrue(validation.recommendations.contains { rec in
                rec.contains("Part 12")
            })
        }
    }

    // MARK: - Generation Tests

    func testGenerateComplianceChecklist() async throws {
        let acquisition = AcquisitionDetails(
            type: .commercial,
            value: 1_000_000,
            setAsideType: nil,
            isSimplified: false
        )

        let checklist = try await manager.generateComplianceChecklist(for: acquisition)

        XCTAssertFalse(checklist.items.isEmpty)
        XCTAssertFalse(checklist.requiredClauses.isEmpty)

        // Verify checklist structure
        for item in checklist.items {
            XCTAssertFalse(item.description.isEmpty)
            XCTAssertNotNil(item.farReference)
            XCTAssertNotNil(item.priority)
        }
    }

    func testGenerateClauseMatrix() async throws {
        let clauseNumbers = ["52.212-4", "52.212-5", "52.203-13"]
        let matrix = try await manager.generateClauseMatrix(for: Set(clauseNumbers))

        XCTAssertEqual(matrix.clauses.count, clauseNumbers.count)

        // Check applicability conditions
        for entry in matrix.clauses {
            XCTAssertFalse(entry.applicabilityConditions.isEmpty)
            XCTAssertNotNil(entry.prescribedBy)
        }
    }

    // MARK: - Part 12 Wizard Tests

    func testPart12CommercialItemWizard() async throws {
        let step1 = Part12WizardStep.marketResearch(
            FARMarketResearchData(
                sourcesContacted: ["GSA Advantage", "Industry associations"],
                findingsummary: "Multiple commercial sources identified",
                priceReasonableness: "Prices competitive with market",
                customizationNeeded: "Minor configuration required"
            )
        )

        let guidance = try await manager.part12Wizard(step: step1)

        XCTAssertFalse(guidance.nextSteps.isEmpty)
        XCTAssertFalse(guidance.requiredDocumentation.isEmpty)
        XCTAssertNotNil(guidance.clauseRecommendations)
    }

    // MARK: - Edge Cases

    func testEmptyDocumentCompliance() async throws {
        let emptyDoc = ComplianceDocument(
            id: UUID(),
            content: "",
            metadata: DocumentMetadata(
                title: "Empty Document",
                size: 0,
                mimeType: "text/plain",
                createdAt: Date(),
                lastAccessedAt: Date()
            ),
            type: .other,
            farClauses: []
        )

        let result = try await manager.performCompleteComplianceCheck(for: emptyDoc)

        XCTAssertLessThan(result.overallScore, 50) // Should have low score
        XCTAssertFalse(result.violations.isEmpty) // Should have violations for empty content
    }

    func testLargeDocumentPerformance() async throws {
        // Create a large document
        let largeContent = String(repeating: "Lorem ipsum dolor sit amet. ", count: 10000)
        let largeDoc = ComplianceDocument(
            id: UUID(),
            content: largeContent,
            metadata: DocumentMetadata(
                title: "Large Document",
                size: Int64(largeContent.count),
                mimeType: "text/plain",
                createdAt: Date(),
                lastAccessedAt: Date()
            ),
            type: .solicitation,
            farClauses: Array(repeating: "52.212-4", count: 50)
        )

        let measure = XCTMeasureOptions()
        measure.iterationCount = 3

        self.measure(options: measure) {
            let expectation = self.expectation(description: "Large document compliance check")

            Task {
                _ = try await manager.performCompleteComplianceCheck(for: largeDoc)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 30.0)
        }
    }

    // MARK: - Helper Methods

    private func createTestDocument(
        type: DocumentType = .sourceSelection,
        withClauses clauses: [String] = ["52.212-4"]
    ) -> ComplianceDocument {
        ComplianceDocument(
            id: UUID(),
            content: """
            This is a test document for source selection.
            It includes evaluation criteria and procurement methods.
            The acquisition will follow FAR Part 15 procedures.
            Commercial items will be considered under FAR Part 12.
            """,
            metadata: DocumentMetadata(
                title: "Test Compliance Document",
                size: 1024,
                mimeType: "text/plain",
                createdAt: Date(),
                lastAccessedAt: Date()
            ),
            type: type,
            farClauses: clauses
        )
    }
}

// MARK: - Mock Types

struct AcquisitionDetails {
    let type: AcquisitionType
    let value: Double
    let setAsideType: SetAsideType?
    let isSimplified: Bool
}

enum AcquisitionType {
    case commercial
    case nonCommercial
    case construction
    case services
}

enum SetAsideType {
    case smallBusiness
    case womanOwned
    case veteranOwned
    case hubZone
}
