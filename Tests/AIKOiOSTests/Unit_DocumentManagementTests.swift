@testable import AppCore
@testable import AIKOiOS
import ComposableArchitecture
import XCTest

@MainActor
final class DocumentManagementTests: XCTestCase {
    // MARK: - Test Metrics

    struct TestMetrics {
        var mop: Double = 0.0 // Measure of Performance
        var moe: Double = 0.0 // Measure of Effectiveness

        var overallScore: Double { (mop + moe) / 2.0 }
        var passed: Bool { overallScore >= 0.8 }
    }

    // MARK: - Document Picker Tests

    func testDocumentPickerPresentation() async throws {
        var metrics = TestMetrics()

        let store = TestStore(
            initialState: AcquisitionChatFeature.State(
                acquisitionID: "test-123",
                messages: []
            ),
            reducer: { AcquisitionChatFeature() }
        )

        let startTime = Date()

        // Test showing document picker
        await store.send(.showDocumentPicker(true)) { state in
            XCTAssertTrue(state.showingDocumentPicker)
            metrics.moe = state.showingDocumentPicker ? 1.0 : 0.0
        }

        // Test hiding document picker
        await store.send(.showDocumentPicker(false)) { state in
            XCTAssertFalse(state.showingDocumentPicker)
            metrics.moe = metrics.moe * (state.showingDocumentPicker ? 0.5 : 1.0)
        }

        let endTime = Date()

        // MOP: UI responsiveness
        let timeTaken = endTime.timeIntervalSince(startTime)
        metrics.mop = timeTaken < 0.1 ? 1.0 : max(0, 1.0 - timeTaken * 10)

        XCTAssertTrue(metrics.passed, "Document picker presentation failed with score: \(metrics.overallScore)")
        print(" Document Picker - MOP: \(metrics.mop), MOE: \(metrics.moe), Score: \(metrics.overallScore)")
    }

    func testDocumentUpload() async throws {
        var metrics = TestMetrics()

        let store = TestStore(
            initialState: AcquisitionChatFeature.State(
                acquisitionID: "test-123",
                messages: []
            ),
            reducer: { AcquisitionChatFeature() }
        )

        // Create test document data
        let testFileName = "test_document.pdf"
        let testData = Data("Test PDF content".utf8)
        let startTime = Date()

        // Test document upload
        await store.send(.documentsSelected([(fileName: testFileName, data: testData)])) { state in
            // Verify document was added
            XCTAssertEqual(state.uploadedDocuments.count, 1)

            if let uploaded = state.uploadedDocuments.first {
                XCTAssertEqual(uploaded.fileName, testFileName)
                XCTAssertEqual(uploaded.data, testData)
                metrics.moe = 1.0
            } else {
                metrics.moe = 0.0
            }
        }

        let endTime = Date()

        // MOP: Upload processing speed
        let timeTaken = endTime.timeIntervalSince(startTime)
        metrics.mop = timeTaken < 0.2 ? 1.0 : max(0, 1.0 - (timeTaken - 0.2) * 5)

        XCTAssertTrue(metrics.passed, "Document upload failed with score: \(metrics.overallScore)")
        print(" Document Upload - MOP: \(metrics.mop), MOE: \(metrics.moe), Score: \(metrics.overallScore)")
    }

    func testMultipleDocumentUpload() async throws {
        var metrics = TestMetrics()

        let store = TestStore(
            initialState: AcquisitionChatFeature.State(
                acquisitionID: "test-123",
                messages: []
            ),
            reducer: { AcquisitionChatFeature() }
        )

        // Create multiple test documents
        let testDocuments = (1 ... 5).map { i in
            (fileName: "document_\(i).pdf", data: Data("Content for document \(i)".utf8))
        }

        let startTime = Date()

        // Upload multiple documents
        await store.send(.documentsSelected(testDocuments)) { state in
            XCTAssertEqual(state.uploadedDocuments.count, 5)

            // Verify all documents uploaded correctly
            let allFilesMatch = testDocuments.enumerated().allSatisfy { index, doc in
                state.uploadedDocuments[index].fileName == doc.fileName &&
                    state.uploadedDocuments[index].data == doc.data
            }

            metrics.moe = allFilesMatch ? 1.0 : 0.0
        }

        let endTime = Date()

        // MOP: Batch upload performance
        let timeTaken = endTime.timeIntervalSince(startTime)
        let timePerDoc = timeTaken / 5.0
        metrics.mop = timePerDoc < 0.1 ? 1.0 : max(0, 1.0 - (timePerDoc - 0.1) * 10)

        XCTAssertTrue(metrics.passed, "Multiple document upload failed with score: \(metrics.overallScore)")
        print(" Multiple Upload - MOP: \(metrics.mop), MOE: \(metrics.moe), Score: \(metrics.overallScore)")
    }

    // MARK: - Document Download Tests

    func testDocumentDownload() async throws {
        var metrics = TestMetrics()

        let testDocument = GeneratedDocument(
            id: UUID(),
            type: .statementOfWork,
            content: NSAttributedString(string: "Test SOW Content"),
            metadata: ["version": "1.0"],
            generatedDate: Date()
        )

        let store = TestStore(
            initialState: DocumentExecutionFeature.State(
                acquisitionID: "test-123",
                selectedDocument: testDocument
            ),
            reducer: { DocumentExecutionFeature() },
            withDependencies: {
                $0.documentGenerator = .testValue
            }
        )

        let startTime = Date()

        // Test download action
        await store.send(.downloadDocument)

        // Verify download initiated (platform-specific behavior)
        #if os(iOS)
            // On iOS, would show share sheet
            await store.receive(\.downloadDocumentResponse)
        #else
            // On macOS, would show save panel
            await store.receive(\.downloadDocumentResponse)
        #endif

        let endTime = Date()

        // MOP: Download initiation speed
        let timeTaken = endTime.timeIntervalSince(startTime)
        metrics.mop = timeTaken < 0.3 ? 1.0 : max(0, 1.0 - (timeTaken - 0.3) * 3)

        // MOE: Download functionality available
        metrics.moe = 1.0 // Successfully processed download request

        XCTAssertTrue(metrics.passed, "Document download failed with score: \(metrics.overallScore)")
        print(" Document Download - MOP: \(metrics.mop), MOE: \(metrics.moe), Score: \(metrics.overallScore)")
    }

    // MARK: - Email Tests

    func testDocumentEmail() async throws {
        var metrics = TestMetrics()

        let testDocument = GeneratedDocument(
            id: UUID(),
            type: .performanceWorkStatement,
            content: NSAttributedString(string: "Test PWS Content"),
            metadata: [:],
            generatedDate: Date()
        )

        let store = TestStore(
            initialState: DocumentExecutionFeature.State(
                acquisitionID: "test-123",
                selectedDocument: testDocument
            ),
            reducer: { DocumentExecutionFeature() }
        )

        let startTime = Date()

        // Test email action
        await store.send(.emailDocument)

        #if os(iOS)
            await store.receive(\.emailDocumentResponse) { _ in
                // On iOS, would show mail composer
                metrics.moe = 1.0
            }
        #else
            await store.receive(\.emailDocumentResponse) { _ in
                // On macOS, would use NSSharingService
                metrics.moe = 1.0
            }
        #endif

        let endTime = Date()

        // MOP: Email preparation speed
        let timeTaken = endTime.timeIntervalSince(startTime)
        metrics.mop = timeTaken < 0.2 ? 1.0 : max(0, 1.0 - (timeTaken - 0.2) * 5)

        XCTAssertTrue(metrics.passed, "Document email failed with score: \(metrics.overallScore)")
        print(" Document Email - MOP: \(metrics.mop), MOE: \(metrics.moe), Score: \(metrics.overallScore)")
    }

    // MARK: - Integration Tests

    func testCompleteDocumentWorkflow() async throws {
        var metrics = TestMetrics()
        var workflowSteps = 0
        let totalSteps = 4

        // Step 1: Upload document
        let chatStore = TestStore(
            initialState: AcquisitionChatFeature.State(
                acquisitionID: "workflow-test",
                messages: []
            ),
            reducer: { AcquisitionChatFeature() }
        )

        let startTime = Date()

        await chatStore.send(.documentsSelected([
            (fileName: "requirements.pdf", data: Data("Requirements".utf8)),
        ])) { state in
            if state.uploadedDocuments.count == 1 {
                workflowSteps += 1
            }
        }

        // Step 2: Process document (simulated)
        await chatStore.send(.processUploadedDocument(chatStore.state.uploadedDocuments[0])) { _ in
            workflowSteps += 1
        }

        // Step 3: Generate new document from uploaded content
        let executionStore = TestStore(
            initialState: DocumentExecutionFeature.State(
                acquisitionID: "workflow-test",
                selectedDocument: GeneratedDocument(
                    id: UUID(),
                    type: .requirementsDocument,
                    content: NSAttributedString(string: "Generated from upload"),
                    metadata: [:],
                    generatedDate: Date()
                )
            ),
            reducer: { DocumentExecutionFeature() }
        )

        // Step 4: Download generated document
        await executionStore.send(.downloadDocument)
        await executionStore.receive(\.downloadDocumentResponse) { _ in
            workflowSteps += 1
        }

        // Step 5: Email document
        await executionStore.send(.emailDocument)
        await executionStore.receive(\.emailDocumentResponse) { _ in
            workflowSteps += 1
        }

        let endTime = Date()

        // MOP: Complete workflow performance
        let totalTime = endTime.timeIntervalSince(startTime)
        metrics.mop = totalTime < 2.0 ? 1.0 : max(0, 1.0 - (totalTime - 2.0) / 3.0)

        // MOE: All workflow steps completed
        metrics.moe = Double(workflowSteps) / Double(totalSteps)

        XCTAssertTrue(metrics.passed, "Complete workflow failed with score: \(metrics.overallScore)")
        print(" Complete Workflow - MOP: \(metrics.mop), MOE: \(metrics.moe), Score: \(metrics.overallScore)")
    }

    // MARK: - Performance Tests

    func testLargeDocumentHandling() async throws {
        var metrics = TestMetrics()

        let store = TestStore(
            initialState: AcquisitionChatFeature.State(
                acquisitionID: "large-doc-test",
                messages: []
            ),
            reducer: { AcquisitionChatFeature() }
        )

        // Create large document (10MB)
        let largeData = Data(repeating: 0x41, count: 10 * 1024 * 1024) // 10MB of 'A's
        let startTime = Date()

        await store.send(.documentsSelected([
            (fileName: "large_document.pdf", data: largeData),
        ])) { state in
            metrics.moe = state.uploadedDocuments.first?.data.count == largeData.count ? 1.0 : 0.0
        }

        let endTime = Date()

        // MOP: Large file handling performance
        let timeTaken = endTime.timeIntervalSince(startTime)
        metrics.mop = timeTaken < 1.0 ? 1.0 : max(0, 1.0 - (timeTaken - 1.0) / 4.0)

        XCTAssertTrue(metrics.passed, "Large document handling failed with score: \(metrics.overallScore)")
        print(" Large Document - MOP: \(metrics.mop), MOE: \(metrics.moe), Score: \(metrics.overallScore)")
    }
}
