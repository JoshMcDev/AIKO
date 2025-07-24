@testable import AppCore
import XCTest

/// Comprehensive regression test suite for AIKO-IOS
final class RegressionTestSuite: XCTestCase {
    // MARK: - Document Generation Tests

    func testAllDocumentTypesGenerate() async throws {
        // Test that all document types can be generated
        for documentType in DocumentType.allCases {
            let generator = AIDocumentGenerator.testValue
            let requirements = "Test requirements for \(documentType.rawValue)"

            let documents = try await generator.generateDocuments(
                requirements,
                [documentType],
                .free
            )

            XCTAssertEqual(documents.count, 1)
            XCTAssertFalse(documents[0].content.isEmpty)
            XCTAssertEqual(documents[0].documentType, documentType)
        }
    }

    func testPWSIncludesSLASection() async throws {
        // Verify PWS template includes SLA section
        let generator = AIDocumentGenerator.testValue
        let requirements = "Telecommunications service with 99.5% uptime requirement"

        let documents = try await generator.generateDocuments(
            requirements,
            [.pws],
            .pro
        )

        XCTAssertEqual(documents.count, 1)
        let content = documents[0].content.lowercased()
        XCTAssertTrue(content.contains("sla") || content.contains("service level"))
    }

    func testOTAgreementGeneration() async throws {
        // Test new OT agreement type
        let generator = AIDocumentGenerator.testValue
        let requirements = "Prototype project for AI-powered drone navigation"

        let documents = try await generator.generateDocuments(
            requirements,
            [.otherTransactionAgreement],
            .enterprise
        )

        XCTAssertEqual(documents.count, 1)
        XCTAssertNotNil(documents[0].documentType)
        XCTAssertEqual(documents[0].documentType, .otherTransactionAgreement)
    }

    // MARK: - Compliance Tests

    func testFARComplianceAllDocumentTypes() async throws {
        // Test FAR compliance for all document types
        let service = FARComplianceService.liveValue

        for documentType in DocumentType.allCases {
            let mockContent = "Mock content for \(documentType.rawValue)"
            let result = try await service.validateDocument(documentType, mockContent)

            XCTAssertNotNil(result)
            XCTAssertGreaterThanOrEqual(result.complianceScore, 0.0)
            XCTAssertLessThanOrEqual(result.complianceScore, 1.0)
        }
    }

    func testCMMCComplianceTracking() async throws {
        // Test CMMC compliance tracker
        let tracker = CMMCComplianceTracker.liveValue

        // Test all CMMC levels
        for level in CMMCLevel.allCases {
            let requirements = try await tracker.loadRequirements(level)
            XCTAssertFalse(requirements.isEmpty)

            let score = try await tracker.calculateComplianceScore(level)
            XCTAssertGreaterThanOrEqual(score, 0.0)
            XCTAssertLessThanOrEqual(score, 1.0)
        }
    }

    func testFARPart12CommercialItems() async throws {
        // Test FAR Part 12 compliance
        let service = FARPart12ComplianceService.liveValue

        let commercialContent = "Commercial off-the-shelf software with catalog pricing"
        let validation = try await service.validateCommercialItem(commercialContent, .sow)

        XCTAssertTrue(validation.isCommercialItem)
        XCTAssertFalse(validation.requiredClauses.isEmpty)
    }

    // MARK: - Workflow Tests

    func testWorkflowStateTransitions() async throws {
        // Test workflow state transitions
        let engine = WorkflowEngine.liveValue
        let acquisitionId = UUID()

        let context = try await engine.startWorkflow(acquisitionId)
        XCTAssertEqual(context.currentState, .initial)

        // Test state progression
        let states: [WorkflowState] = [
            .gatheringRequirements,
            .analyzingRequirements,
            .suggestingDocuments,
            .collectingData,
            .generatingDocuments,
        ]

        for state in states {
            let updatedContext = try await engine.updateWorkflowState(acquisitionId, state)
            XCTAssertEqual(updatedContext.currentState, state)
        }
    }

    // MARK: - Service Integration Tests

    func testDocumentDependencyService() async throws {
        // Test document dependency resolution
        let service = DocumentDependencyService.liveValue

        // Test that QASP depends on PWS
        let qaspDeps = service.getDependencies(.qasp)
        XCTAssertTrue(qaspDeps.contains { $0.sourceDocumentType == .pws })

        // Test suggestion logic
        let suggestions = service.suggestNextDocuments([.marketResearch], CollectedData())
        XCTAssertFalse(suggestions.isEmpty)
    }

    func testUserPatternTracking() async throws {
        // Test user pattern tracking
        let tracker = UserPatternTracker.liveValue

        let action = TrackedAction(
            actionType: .documentGenerated,
            context: TrackedAction.ActionContext(
                documentType: "PWS",
                workflowState: "generating",
                timeOfDay: 14,
                dayOfWeek: 2,
                previousAction: nil,
                timeSpent: 120
            )
        )

        await tracker.trackAction(action)
        let patterns = await tracker.getPatterns()
        XCTAssertNotNil(patterns)
    }

    // MARK: - Performance Tests

    func testDocumentGenerationPerformance() {
        // Measure document generation performance
        measure {
            let expectation = self.expectation(description: "Generate document")

            Task {
                let generator = AIDocumentGenerator.testValue
                _ = try await generator.generateDocuments(
                    "Test requirements",
                    [.sow],
                    .free
                )
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)
        }
    }

    // MARK: - Data Persistence Tests

    func testAcquisitionCRUD() async throws {
        // Test Core Data operations
        let service = AcquisitionService.liveValue

        // Create
        let acquisition = try await service.createAcquisition(
            title: "Test Acquisition",
            requirements: "Test requirements"
        )
        XCTAssertNotNil(acquisition)

        // Read
        let fetched = try await service.fetchAcquisition(acquisition.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.title, "Test Acquisition")

        // Update
        if let toUpdate = fetched {
            try await service.updateAcquisition(
                toUpdate,
                title: "Updated Title",
                requirements: "Updated requirements"
            )

            let updated = try await service.fetchAcquisition(acquisition.id)
            XCTAssertEqual(updated?.title, "Updated Title")
        }

        // List
        let all = try await service.fetchAllAcquisitions()
        XCTAssertTrue(all.contains { $0.id == acquisition.id })
    }

    // MARK: - Error Handling Tests

    func testErrorHandling() async throws {
        // Test that services handle errors gracefully
        let generator = AIDocumentGenerator.liveValue

        do {
            // Try to generate with empty requirements
            _ = try await generator.generateDocuments("", [], .free)
            XCTFail("Should throw error for empty requirements")
        } catch {
            // Expected error
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Export Functionality Tests

    func testDocumentExport() async throws {
        // Test document export capabilities
        let service = DocumentDeliveryService.liveValue

        let testDoc = GeneratedDocument(
            title: "Test Document",
            documentType: .sow,
            content: "Test content for export"
        )

        // Test PDF export
        let pdfData = try await service.generatePDF([testDoc])
        XCTAssertFalse(pdfData.isEmpty)

        // Test DOCX export
        let docxData = try await service.generateDOCX([testDoc])
        XCTAssertFalse(docxData.isEmpty)
    }
}

// MARK: - Test Runner

extension RegressionTestSuite {
    static func runAllTests() async throws -> TestResults {
        let suite = RegressionTestSuite()
        var results = TestResults()

        // Document Generation Tests
        await results.record(test: "All Document Types",
                             result: suite.runTest(testAllDocumentTypesGenerate))
        await results.record(test: "PWS SLA Section",
                             result: suite.runTest(testPWSIncludesSLASection))
        await results.record(test: "OT Agreement",
                             result: suite.runTest(testOTAgreementGeneration))

        // Compliance Tests
        await results.record(test: "FAR Compliance",
                             result: suite.runTest(testFARComplianceAllDocumentTypes))
        await results.record(test: "CMMC Tracking",
                             result: suite.runTest(testCMMCComplianceTracking))
        await results.record(test: "FAR Part 12",
                             result: suite.runTest(testFARPart12CommercialItems))

        // Workflow Tests
        await results.record(test: "Workflow States",
                             result: suite.runTest(testWorkflowStateTransitions))

        // Service Tests
        await results.record(test: "Dependencies",
                             result: suite.runTest(testDocumentDependencyService))
        await results.record(test: "Pattern Tracking",
                             result: suite.runTest(testUserPatternTracking))

        // Data Tests
        await results.record(test: "Acquisition CRUD",
                             result: suite.runTest(testAcquisitionCRUD))

        // Export Tests
        await results.record(test: "Document Export",
                             result: suite.runTest(testDocumentExport))

        return results
    }

    private func runTest(_ test: () async throws -> Void) async -> Bool {
        do {
            try await test()
            return true
        } catch {
            print("Test failed: \(error)")
            return false
        }
    }
}

// MARK: - Test Results

struct TestResults {
    var tests: [(name: String, passed: Bool)] = []

    mutating func record(test: String, result: Bool) {
        tests.append((name: test, passed: result))
    }

    var summary: String {
        let passed = tests.filter(\.passed).count
        let total = tests.count
        let percentage = total > 0 ? (Double(passed) / Double(total)) * 100 : 0

        return """
        Regression Test Results:
        - Total Tests: \(total)
        - Passed: \(passed)
        - Failed: \(total - passed)
        - Success Rate: \(String(format: "%.1f", percentage))%

        Details:
        \(tests.map { "\($0.name): \($0.passed ? " PASS" : "❌ FAIL")" }.joined(separator: "\n"))
        """
    }
}
