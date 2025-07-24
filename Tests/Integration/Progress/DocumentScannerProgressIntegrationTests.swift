@testable import AppCoreiOS
@testable import AppCore
import Combine
import ComposableArchitecture
import Foundation
import XCTest

@MainActor
final class DocumentScannerProgressIntegrationTests: XCTestCase {
    // MARK: - DocumentImageProcessor Integration Tests

    func testDocumentImageProcessorProgressCallbackIntegration() async {
        var receivedProgress: [DocumentImageProcessor.ProcessingProgress] = []
        let expectation = XCTestExpectation(description: "Progress callbacks received")
        expectation.expectedFulfillmentCount = 3 // Initial, middle, and final progress

        let progressCallback: (DocumentImageProcessor.ProcessingProgress) -> Void = { progress in
            receivedProgress.append(progress)
            expectation.fulfill()
        }

        let options = DocumentImageProcessor.ProcessingOptions(
            progressCallback: progressCallback,
            qualityTarget: .balanced
        )

        let processor = DocumentImageProcessor.testValue
        let testImageData = createTestImageData()

        do {
            _ = try await processor.processImage(testImageData, .enhanced, options)

            await fulfillment(of: [expectation], timeout: 5.0)

            XCTAssertFalse(receivedProgress.isEmpty)
            XCTAssertGreaterThanOrEqual(receivedProgress.count, 3)

            // Verify progress sequence
            guard let firstProgress = receivedProgress.first,
                  let lastProgress = receivedProgress.last
            else {
                XCTFail("Failed to get first or last progress")
                return
            }

            XCTAssertLessThanOrEqual(firstProgress.fractionCompleted, 0.1)
            XCTAssertEqual(lastProgress.fractionCompleted, 1.0, accuracy: 0.001)

            // Verify progress is monotonically increasing
            for i in 1 ..< receivedProgress.count {
                XCTAssertGreaterThanOrEqual(
                    receivedProgress[i].fractionCompleted,
                    receivedProgress[i - 1].fractionCompleted
                )
            }
        } catch {
            XCTFail("Processing failed with error: \(error)")
        }
    }

    func testDocumentImageProcessorProgressPhaseTransitions() async {
        var receivedPhases: [String] = []
        let expectation = XCTestExpectation(description: "Phase transitions received")
        expectation.expectedFulfillmentCount = 4 // Different processing phases

        let progressCallback: (DocumentImageProcessor.ProcessingProgress) -> Void = { progress in
            if !receivedPhases.contains(progress.currentOperation) {
                receivedPhases.append(progress.currentOperation)
                expectation.fulfill()
            }
        }

        let options = DocumentImageProcessor.ProcessingOptions(
            progressCallback: progressCallback,
            qualityTarget: .maximum
        )

        let processor = DocumentImageProcessor.liveValue
        let testImageData = createTestImageData()

        do {
            _ = try await processor.processImage(testImageData, .enhanced, options)

            await fulfillment(of: [expectation], timeout: 10.0)

            XCTAssertGreaterThanOrEqual(receivedPhases.count, 3)
            XCTAssertTrue(receivedPhases.contains("preprocessing"))
            XCTAssertTrue(receivedPhases.contains("enhancement"))
            XCTAssertTrue(receivedPhases.contains("optimization"))
        } catch {
            XCTFail("Processing failed with error: \(error)")
        }
    }

    func testDocumentImageProcessorProgressWithMetadata() async {
        var receivedMetadata: [[String: Any]] = []
        let expectation = XCTestExpectation(description: "Progress with metadata received")
        expectation.expectedFulfillmentCount = 2

        let progressCallback: (DocumentImageProcessor.ProcessingProgress) -> Void = { progress in
            receivedMetadata.append(progress.metadata)
            expectation.fulfill()
        }

        let options = DocumentImageProcessor.ProcessingOptions(
            progressCallback: progressCallback,
            qualityTarget: .balanced,
            optimizeForOCR: true
        )

        let processor = DocumentImageProcessor.testValue
        let testImageData = createTestImageData()

        do {
            _ = try await processor.processImage(testImageData, .enhanced, options)

            await fulfillment(of: [expectation], timeout: 5.0)

            XCTAssertFalse(receivedMetadata.isEmpty)

            // Verify metadata contains expected keys
            for metadata in receivedMetadata {
                XCTAssertNotNil(metadata["operation_type"])
                XCTAssertNotNil(metadata["image_size"])
            }
        } catch {
            XCTFail("Processing failed with error: \(error)")
        }
    }

    // MARK: - DocumentScannerFeature Integration Tests

    func testDocumentScannerFeatureProgressIntegration() async {
        let initialState = DocumentScannerFeature.State()

        let store = TestStore(initialState: initialState) {
            DocumentScannerFeature()
        } withDependencies: {
            $0.progressClient = .testValue
            $0.documentImageProcessor = .testValue
            $0.documentScanner = .testValue
        }

        let testPages = [createTestScannedPage()]

        await store.send(.scanDocument(testPages))

        // Verify progress session was started
        await store.receive(.progressFeedback(.startSession)) { state in
            XCTAssertTrue(state.progressFeedback.isActive)
            XCTAssertNotNil(state.progressFeedback.currentSession)
        }

        // Verify progress updates are sent
        await store.receive(.progressFeedback(.updateProgress)) { state in
            let currentProgress = state.progressFeedback.currentProgress
            XCTAssertNotNil(currentProgress)
            XCTAssertGreaterThan(currentProgress?.fractionCompleted ?? 0, 0)
        }

        // Verify session completion
        await store.receive(.progressFeedback(.completeSession)) { state in
            XCTAssertFalse(state.progressFeedback.isActive)
            XCTAssertNil(state.progressFeedback.currentSession)
        }
    }

    func testDocumentScannerFeatureMultiPageProgressIntegration() async {
        let initialState = DocumentScannerFeature.State()

        let store = TestStore(initialState: initialState) {
            DocumentScannerFeature()
        } withDependencies: {
            $0.progressClient = .liveValue
            $0.documentImageProcessor = .testValue
            $0.documentScanner = .testValue
        }

        let testPages = [
            createTestScannedPage(),
            createTestScannedPage(),
            createTestScannedPage(),
        ]

        await store.send(.scanDocument(testPages))

        // Should start with multi-page configuration
        await store.receive(.progressFeedback(.startSession)) { state in
            let session = state.progressFeedback.activeSessions.first
            XCTAssertEqual(session?.value.totalSteps, testPages.count)
        }

        // Should receive progress updates for each page
        for i in 0 ..< testPages.count {
            await store.receive(.progressFeedback(.updateProgress)) { state in
                let progress = state.progressFeedback.currentProgress
                XCTAssertNotNil(progress)
                XCTAssertTrue(progress?.currentStep.contains("page") ?? false)
                XCTAssertTrue(progress?.currentStep.contains("\(i + 1)") ?? false)
            }
        }

        await store.receive(.progressFeedback(.completeSession)) { state in
            XCTAssertFalse(state.progressFeedback.isActive)
        }
    }

    func testDocumentScannerFeatureProgressCancellation() async {
        let initialState = DocumentScannerFeature.State()

        let store = TestStore(initialState: initialState) {
            DocumentScannerFeature()
        } withDependencies: {
            $0.progressClient = .testValue
            $0.documentImageProcessor = .testValue
            $0.documentScanner = .testValue
        }

        let testPages = [createTestScannedPage()]

        // Start scanning
        await store.send(.scanDocument(testPages))
        await store.receive(.progressFeedback(.startSession))

        // Cancel scanning
        await store.send(.cancelScanning)

        // Should cancel progress session
        await store.receive(.progressFeedback(.cancelSession)) { state in
            XCTAssertFalse(state.progressFeedback.isActive)
            XCTAssertNil(state.progressFeedback.currentSession)
        }
    }

    // MARK: - MultiPageSession Integration Tests

    func testMultiPageSessionProgressTracking() async {
        let sessionConfig = ProgressSessionConfig(
            type: .multiPageScan,
            expectedPhases: [.preparing, .scanning, .processing, .analyzing, .completing],
            estimatedDuration: nil,
            shouldAnnounceProgress: true,
            minimumUpdateInterval: 0.1
        )

        let progressClient = ProgressClient.liveValue
        let session = await progressClient.createSession(sessionConfig)

        var multiPageSession = MultiPageSession(
            totalPages: 3,
            configuration: .default
        )
        multiPageSession.progressSessionId = session.id

        var receivedStates: [ProgressState] = []
        let expectation = XCTestExpectation(description: "Multi-page progress received")
        expectation.expectedFulfillmentCount = 4 // Initial + 3 updates

        let cancellable = session.progressPublisher
            .sink { state in
                receivedStates.append(state)
                expectation.fulfill()
            }

        // Simulate processing 3 pages
        for i in 0 ..< 3 {
            await multiPageSession.updateProgress(
                currentPageProgress: 1.0,
                using: progressClient
            )
            multiPageSession.processedPages.append(createTestScannedPage())
        }

        await fulfillment(of: [expectation], timeout: 5.0)

        XCTAssertGreaterThanOrEqual(receivedStates.count, 4)

        // Verify progress increases
        guard let finalProgress = receivedStates.last else {
            XCTFail("Failed to get final progress")
            return
        }
        XCTAssertEqual(finalProgress.fractionCompleted, 1.0, accuracy: 0.1)
        XCTAssertTrue(finalProgress.currentStep.contains("3 of 3"))

        cancellable.cancel()
        await progressClient.completeSession(session.id)
    }

    func testMultiPageSessionOverallProgressCalculation() {
        var multiPageSession = MultiPageSession(
            totalPages: 4,
            configuration: .default
        )

        // No pages processed yet
        XCTAssertEqual(multiPageSession.overallProgress, 0.0)

        // Process 1 page completely
        multiPageSession.processedPages.append(createTestScannedPage())
        multiPageSession.currentPageProgress = 0.0
        XCTAssertEqual(multiPageSession.overallProgress, 0.25, accuracy: 0.01)

        // Process 2 pages, working on 3rd at 50%
        multiPageSession.processedPages.append(createTestScannedPage())
        multiPageSession.currentPageProgress = 0.5
        XCTAssertEqual(multiPageSession.overallProgress, 0.625, accuracy: 0.01)

        // Complete all pages
        multiPageSession.processedPages.append(createTestScannedPage())
        multiPageSession.processedPages.append(createTestScannedPage())
        multiPageSession.currentPageProgress = 0.0
        XCTAssertEqual(multiPageSession.overallProgress, 1.0, accuracy: 0.01)
    }

    // MARK: - VisionKit Scanner Integration Tests

    func testVisionKitScannerProgressIntegration() async {
        let configuration = DocumentScannerConfiguration(
            scanMode: .multiPage,
            qualityTarget: .balanced
        )

        let scannerClient = DocumentScannerClient.testValue
        var receivedProgressUpdates: [ProgressUpdate] = []
        let expectation = XCTestExpectation(description: "Scanner progress received")
        expectation.expectedFulfillmentCount = 3

        // Mock the scanner to send progress updates
        let mockProgressCallback: (ProgressUpdate) -> Void = { update in
            receivedProgressUpdates.append(update)
            expectation.fulfill()
        }

        do {
            let scannedPages = try await scannerClient.scanDocument(
                configuration,
                progressCallback: mockProgressCallback
            )

            await fulfillment(of: [expectation], timeout: 10.0)

            XCTAssertFalse(scannedPages.isEmpty)
            XCTAssertFalse(receivedProgressUpdates.isEmpty)

            // Verify progress sequence
            let phases = receivedProgressUpdates.map(\.phase)
            XCTAssertTrue(phases.contains(.preparing))
            XCTAssertTrue(phases.contains(.scanning))
            XCTAssertTrue(phases.contains(.completing))

            // Verify final progress
            guard let finalUpdate = receivedProgressUpdates.last else {
                XCTFail("Failed to get final progress update")
                return
            }
            XCTAssertEqual(finalUpdate.fractionCompleted, 1.0, accuracy: 0.001)
            XCTAssertEqual(finalUpdate.phase, .completing)

        } catch {
            XCTFail("Scanning failed with error: \(error)")
        }
    }

    func testVisionKitScannerProgressCancellation() async {
        let configuration = DocumentScannerConfiguration(
            scanMode: .singlePage,
            qualityTarget: .fast
        )

        let scannerClient = DocumentScannerClient.testValue
        var wasCancelled = false
        let expectation = XCTestExpectation(description: "Scanner cancelled")

        let mockProgressCallback: (ProgressUpdate) -> Void = { update in
            if update.phase == .preparing {
                // Cancel during preparation
                Task {
                    await scannerClient.cancelCurrentScan()
                    wasCancelled = true
                    expectation.fulfill()
                }
            }
        }

        do {
            _ = try await scannerClient.scanDocument(
                configuration,
                progressCallback: mockProgressCallback
            )
            XCTFail("Should have been cancelled")
        } catch DocumentScannerError.cancelled {
            // Expected cancellation
            await fulfillment(of: [expectation], timeout: 5.0)
            XCTAssertTrue(wasCancelled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - End-to-End Integration Tests

    func testEndToEndProgressWorkflow() async {
        // Create a complete scanning workflow with progress tracking
        let store = TestStore(
            initialState: DocumentScannerFeature.State()
        ) {
            DocumentScannerFeature()
        } withDependencies: {
            $0.progressClient = .liveValue
            $0.documentImageProcessor = .testValue
            $0.documentScanner = .testValue
            $0.ocrService = .testValue
        }

        let testPages = [
            createTestScannedPage(),
            createTestScannedPage(),
        ]

        // Start scanning
        await store.send(.scanDocument(testPages))

        // Progress session should start
        await store.receive(.progressFeedback(.startSession)) { state in
            XCTAssertTrue(state.progressFeedback.isActive)
            let config = state.progressFeedback.activeSessions.first?.value
            XCTAssertNotNil(config)
        }

        // Should receive scanning progress
        await store.receive(.progressFeedback(.updateProgress)) { state in
            let progress = state.progressFeedback.currentProgress
            XCTAssertEqual(progress?.phase, .scanning)
        }

        // Should receive processing progress
        await store.receive(.progressFeedback(.updateProgress)) { state in
            let progress = state.progressFeedback.currentProgress
            XCTAssertEqual(progress?.phase, .processing)
        }

        // Should receive OCR analysis progress
        await store.receive(.progressFeedback(.updateProgress)) { state in
            let progress = state.progressFeedback.currentProgress
            XCTAssertEqual(progress?.phase, .analyzing)
        }

        // Should complete successfully
        await store.receive(.progressFeedback(.completeSession)) { state in
            XCTAssertFalse(state.progressFeedback.isActive)
        }

        // Verify final state
        let finalState = store.state
        XCTAssertFalse(finalState.progressFeedback.isActive)
        XCTAssertNil(finalState.progressFeedback.currentSession)
        XCTAssertTrue(finalState.progressFeedback.activeSessions.isEmpty)
    }

    func testEndToEndProgressWorkflowWithError() async {
        let store = TestStore(
            initialState: DocumentScannerFeature.State()
        ) {
            DocumentScannerFeature()
        } withDependencies: {
            $0.progressClient = .testValue
            $0.documentImageProcessor = .failingTestValue // Will fail
            $0.documentScanner = .testValue
        }

        let testPages = [createTestScannedPage()]

        await store.send(.scanDocument(testPages))

        await store.receive(.progressFeedback(.startSession))

        // Should receive error and cancel session
        await store.receive(.progressFeedback(.cancelSession)) { state in
            XCTAssertFalse(state.progressFeedback.isActive)
        }

        // Should handle error gracefully
        await store.receive(.scanningFailed) { state in
            XCTAssertNotNil(state.error)
        }
    }

    // MARK: - Helper Methods

    private func createTestImageData() -> Data {
        // Create a simple test image (1x1 black pixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let bitmapContext = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            fatalError("Failed to create bitmap context")
        }

        guard let cgImage = bitmapContext.makeImage() else {
            fatalError("Failed to create CGImage")
        }

        #if os(iOS)
            let uiImage = UIImage(cgImage: cgImage)
            guard let pngData = uiImage.pngData() else {
                fatalError("Failed to create PNG data")
            }
            return pngData
        #else
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: 1, height: 1))
            guard let tiffData = nsImage.tiffRepresentation else {
                fatalError("Failed to create TIFF data")
            }
            return tiffData
        #endif
    }

    private func createTestScannedPage() -> ScannedPage {
        let testImageData = createTestImageData()
        return ScannedPage(
            id: UUID(),
            imageData: testImageData,
            detectedRectangle: nil,
            timestamp: Date()
        )
    }

    // MARK: - Performance Tests

    func testProgressIntegrationPerformance() async {
        let progressClient = ProgressClient.liveValue

        measure {
            Task {
                for i in 0 ..< 50 {
                    let config = ProgressSessionConfig(
                        type: .singlePageScan,
                        expectedPhases: [.scanning, .processing],
                        estimatedDuration: 1.0,
                        shouldAnnounceProgress: i % 2 == 0,
                        minimumUpdateInterval: 0.05
                    )

                    let session = await progressClient.createSession(config)

                    let update = ProgressUpdate(
                        sessionId: session.id,
                        phase: .processing,
                        fractionCompleted: Double(i) / 50.0,
                        message: "Performance test \(i)"
                    )

                    await progressClient.updateProgress(session.id, update)
                    await progressClient.completeSession(session.id)
                }
            }
        }
    }

    func testConcurrentProgressSessions() async {
        let progressClient = ProgressClient.liveValue
        let sessionCount = 10

        measure {
            Task {
                await withTaskGroup(of: Void.self) { group in
                    for i in 0 ..< sessionCount {
                        group.addTask {
                            let session = await progressClient.createSession(.defaultSinglePageScan)

                            for j in 0 ..< 10 {
                                let update = ProgressUpdate(
                                    sessionId: session.id,
                                    phase: .processing,
                                    fractionCompleted: Double(j) / 10.0,
                                    message: "Session \(i) step \(j)"
                                )
                                await progressClient.updateProgress(session.id, update)
                            }

                            await progressClient.completeSession(session.id)
                        }
                    }
                }
            }
        }
    }
}
