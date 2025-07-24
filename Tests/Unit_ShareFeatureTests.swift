@testable import AppCore
import ComposableArchitecture
import XCTest

@MainActor
final class ShareFeatureTests: XCTestCase {
    func testInitialState() {
        let state = ShareFeature.State()

        XCTAssertEqual(state.mode, .none)
        XCTAssertNil(state.targetAcquisitionId)
        XCTAssertTrue(state.selectedDocumentIds.isEmpty)
        XCTAssertTrue(state.shareItems.isEmpty)
        XCTAssertFalse(state.isShowingShareSheet)
        XCTAssertFalse(state.isPreparingShare)
        XCTAssertNil(state.shareError)
        XCTAssertFalse(state.hasSelection)
        XCTAssertEqual(state.selectionCount, 0)
    }

    func testSetShareMode() async {
        let store = TestStore(
            initialState: ShareFeature.State()
        ) {
            ShareFeature()
        }

        let acquisitionId = UUID()

        // Set acquisition share mode
        await store.send(.setShareMode(.acquisition(acquisitionId))) {
            $0.mode = .acquisition(acquisitionId)
            $0.targetAcquisitionId = acquisitionId
            $0.selectedDocumentIds = []
            $0.shareItems = []
            $0.shareError = nil
        }

        // Set single document mode
        await store.send(.setShareMode(.singleDocument)) {
            $0.mode = .singleDocument
            $0.targetAcquisitionId = nil
        }

        // Set multiple documents mode
        await store.send(.setShareMode(.multipleDocuments)) {
            $0.mode = .multipleDocuments
            $0.targetAcquisitionId = nil
        }

        // Set contract file mode
        let contractId = UUID()
        await store.send(.setShareMode(.contractFile(contractId))) {
            $0.mode = .contractFile(contractId)
            $0.targetAcquisitionId = contractId
        }
    }

    func testCancelShare() async {
        let store = TestStore(
            initialState: ShareFeature.State(
                mode: .singleDocument
            )
        ) {
            ShareFeature()
        }

        // Add some state
        store.state.targetAcquisitionId = UUID()
        store.state.selectedDocumentIds = [UUID(), UUID()]
        store.state.shareItems = ["item1", "item2"]
        store.state.isShowingShareSheet = true
        store.state.isPreparingShare = true
        store.state.shareError = "Error"

        await store.send(.cancelShare) {
            $0.mode = .none
            $0.targetAcquisitionId = nil
            $0.selectedDocumentIds = []
            $0.shareItems = []
            $0.isShowingShareSheet = false
            $0.isPreparingShare = false
            $0.shareError = nil
        }
    }

    func testDocumentSelection() async {
        let store = TestStore(
            initialState: ShareFeature.State()
        ) {
            ShareFeature()
        }

        let doc1 = UUID()
        let doc2 = UUID()
        let doc3 = UUID()

        // Select documents
        await store.send(.selectDocument(doc1)) {
            $0.selectedDocumentIds = [doc1]
        }

        await store.send(.selectDocument(doc2)) {
            $0.selectedDocumentIds = [doc1, doc2]
        }

        // Deselect document
        await store.send(.deselectDocument(doc1)) {
            $0.selectedDocumentIds = [doc2]
        }

        // Select all documents
        await store.send(.selectAllDocuments([doc1, doc2, doc3])) {
            $0.selectedDocumentIds = Set([doc1, doc2, doc3])
        }

        // Clear selection
        await store.send(.clearSelection) {
            $0.selectedDocumentIds = []
        }
    }

    func testPrepareShareSuccess() async {
        let clock = TestClock()
        let store = TestStore(
            initialState: ShareFeature.State()
        ) {
            ShareFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        // Select documents
        let docIds = [UUID(), UUID()]
        store.state.selectedDocumentIds = Set(docIds)
        store.state.mode = .multipleDocuments

        await store.send(.prepareShare) {
            $0.isPreparingShare = true
            $0.shareError = nil
        }

        // Advance clock
        await clock.advance(by: .milliseconds(500))

        await store.receive(.shareItemsPrepared(["Document 1", "Document 2"])) {
            $0.shareItems = ["Document 1", "Document 2"]
            $0.isPreparingShare = false
            $0.isShowingShareSheet = true
        }
    }

    func testPrepareShareWithNoDocuments() async {
        let store = TestStore(
            initialState: ShareFeature.State()
        ) {
            ShareFeature()
        }

        await store.send(.prepareShare)

        await store.receive(.shareFailed("No documents selected")) {
            $0.shareError = "No documents selected"
        }
    }

    func testShareCompleted() async {
        let store = TestStore(
            initialState: ShareFeature.State()
        ) {
            ShareFeature()
        }

        store.state.isShowingShareSheet = true
        store.state.shareItems = ["item1", "item2"]

        await store.send(.shareCompleted) {
            $0.isShowingShareSheet = false
            $0.shareItems = []
            // Selection is preserved for potential re-share
        }
    }

    func testShareFailed() async {
        let store = TestStore(
            initialState: ShareFeature.State()
        ) {
            ShareFeature()
        }

        store.state.isPreparingShare = true

        await store.send(.shareFailed("Network error")) {
            $0.isPreparingShare = false
            $0.shareError = "Network error"
        }
    }

    func testShowingShareSheet() async {
        let store = TestStore(
            initialState: ShareFeature.State()
        ) {
            ShareFeature()
        }

        store.state.shareItems = ["item1"]

        await store.send(.setShowingShareSheet(true)) {
            $0.isShowingShareSheet = true
        }

        await store.send(.setShowingShareSheet(false)) {
            $0.isShowingShareSheet = false
            $0.shareItems = []
        }
    }

    func testShareModeProperties() {
        XCTAssertEqual(ShareMode.none.title, "Share")
        XCTAssertEqual(ShareMode.singleDocument.title, "Share Document")
        XCTAssertEqual(ShareMode.multipleDocuments.title, "Share Documents")
        XCTAssertEqual(ShareMode.acquisition(UUID()).title, "Share Acquisition Documents")
        XCTAssertEqual(ShareMode.contractFile(UUID()).title, "Share Contract File")

        XCTAssertFalse(ShareMode.none.isActive)
        XCTAssertTrue(ShareMode.singleDocument.isActive)
        XCTAssertTrue(ShareMode.multipleDocuments.isActive)
        XCTAssertTrue(ShareMode.acquisition(UUID()).isActive)
        XCTAssertTrue(ShareMode.contractFile(UUID()).isActive)
    }

    func testStateHelpers() {
        var state = ShareFeature.State()

        // Test shareDescription
        XCTAssertEqual(state.shareDescription, "No active share")

        state.mode = .singleDocument
        state.selectedDocumentIds = [UUID()]
        XCTAssertEqual(state.shareDescription, "Sharing 1 document")

        state.mode = .multipleDocuments
        state.selectedDocumentIds = [UUID(), UUID(), UUID()]
        XCTAssertEqual(state.shareDescription, "Sharing 3 documents")

        state.mode = .acquisition(UUID())
        XCTAssertEqual(state.shareDescription, "Sharing acquisition documents (3 selected)")

        state.mode = .contractFile(UUID())
        XCTAssertEqual(state.shareDescription, "Sharing contract file")

        // Test canShare
        state = ShareFeature.State()
        XCTAssertFalse(state.canShare)

        state.selectedDocumentIds = [UUID()]
        XCTAssertTrue(state.canShare)

        state.isPreparingShare = true
        XCTAssertFalse(state.canShare)

        // Test reset
        state.reset()
        XCTAssertEqual(state.mode, .none)
        XCTAssertTrue(state.selectedDocumentIds.isEmpty)
        XCTAssertFalse(state.isPreparingShare)
    }
}

// MARK: - ShareMode Equatable Tests

final class ShareModeEquatableTests: XCTestCase {
    func testShareModeEquality() {
        let id1 = UUID()
        let id2 = UUID()

        XCTAssertEqual(ShareMode.none, ShareMode.none)
        XCTAssertEqual(ShareMode.singleDocument, ShareMode.singleDocument)
        XCTAssertEqual(ShareMode.multipleDocuments, ShareMode.multipleDocuments)
        XCTAssertEqual(ShareMode.acquisition(id1), ShareMode.acquisition(id1))
        XCTAssertEqual(ShareMode.contractFile(id1), ShareMode.contractFile(id1))

        XCTAssertNotEqual(ShareMode.none, ShareMode.singleDocument)
        XCTAssertNotEqual(ShareMode.acquisition(id1), ShareMode.acquisition(id2))
        XCTAssertNotEqual(ShareMode.contractFile(id1), ShareMode.contractFile(id2))
        XCTAssertNotEqual(ShareMode.acquisition(id1), ShareMode.contractFile(id1))
    }
}
