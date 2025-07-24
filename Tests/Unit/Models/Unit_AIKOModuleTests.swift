@testable import AppCore
import ComposableArchitecture
import XCTest

final class AIKOTests: XCTestCase {
    func testDocumentTypeProperties() throws {
        let sow = DocumentType.sow
        XCTAssertEqual(sow.shortName, "SOW")
        XCTAssertEqual(sow.isProFeature, false)

        let qasp = DocumentType.qasp
        XCTAssertEqual(qasp.shortName, "QASP")
        XCTAssertEqual(qasp.isProFeature, true)
    }

    // Subscription feature removed - test no longer needed

    @MainActor
    func testDocumentGenerationFeature() async throws {
        let store = TestStore(initialState: DocumentGenerationFeature.State()) {
            DocumentGenerationFeature()
        } withDependencies: {
            $0.aiDocumentGenerator = .testValue
        }

        // Test requirements change
        await store.send(.requirementsChanged("Test requirements")) {
            $0.requirements = "Test requirements"
        }

        // Test document type toggle
        await store.send(.documentTypeToggled(.sow)) {
            $0.selectedDocumentTypes.insert(.sow)
        }

        // Test document generation
        await store.send(.generateDocuments) {
            $0.isGenerating = true
            $0.error = nil
        }

        await store.receive(.documentsGenerated([
            GeneratedDocument(
                title: "Test SOW",
                documentType: .sow,
                content: "Test document content for Statement of Work\n\nRequirements: Test requirements"
            ),
        ])) {
            $0.isGenerating = false
            $0.generatedDocuments = [
                GeneratedDocument(
                    title: "Test SOW",
                    documentType: .sow,
                    content: "Test document content for Statement of Work\n\nRequirements: Test requirements"
                ),
            ]
        }
    }

    // Subscription feature test removed - feature no longer exists
}
