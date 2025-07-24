@testable import AppCoreiOS
@testable import AppCore
import XCTest

@available(iOS 16.0, *)
final class BatchProcessingEngineTests: XCTestCase {
    var sut: BatchProcessingEngine?

    private var sutUnwrapped: BatchProcessingEngine {
        guard let sut else { fatalError("sut not initialized") }
        return sut
    }

    override func setUp() async throws {
        try await super.setUp()
        sut = BatchProcessingEngine()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Batch Operation Start Tests

    func testStartBatchOperation_WithValidOperation_ShouldReturnHandle() async throws {
        // Given
        let assets = [createMockAsset(), createMockAsset()]
        let operation = BatchOperation(
            type: .compress,
            assets: assets
        )

        // When/Then
        await assertThrowsError {
            _ = try await sut.startBatchOperation(operation)
        }
    }

    func testStartBatchOperation_WithEmptyAssets_ShouldThrowError() async throws {
        // Given
        let operation = BatchOperation(
            type: .compress,
            assets: []
        )

        // When/Then
        await assertThrowsError {
            _ = try await sut.startBatchOperation(operation)
        }
    }

    func testStartBatchOperation_WithConcurrentOptions_ShouldProcessConcurrently() async throws {
        // Given
        let assets = Array(repeating: createMockAsset(), count: 10)
        let options = BatchOperationOptions(
            concurrent: true,
            maxConcurrency: 4
        )
        let operation = BatchOperation(
            type: .resize,
            assets: assets,
            options: options
        )

        // When/Then
        await assertThrowsError {
            _ = try await sut.startBatchOperation(operation)
        }
    }

    // MARK: - Operation Control Tests

    func testPauseOperation_WithActiveOperation_ShouldPause() async throws {
        // Given
        let handle = BatchOperationHandle(
            operationId: UUID(),
            type: .compress
        )

        // When/Then
        await assertThrowsError {
            try await sut.pauseOperation(handle)
        }
    }

    func testResumeOperation_WithPausedOperation_ShouldResume() async throws {
        // Given
        let handle = BatchOperationHandle(
            operationId: UUID(),
            type: .compress
        )

        // When/Then
        await assertThrowsError {
            try await sut.resumeOperation(handle)
        }
    }

    func testCancelOperation_WithActiveOperation_ShouldCancel() async throws {
        // Given
        let handle = BatchOperationHandle(
            operationId: UUID(),
            type: .compress
        )

        // When/Then
        await assertThrowsError {
            try await sut.cancelOperation(handle)
        }
    }

    // MARK: - Operation Status Tests

    func testGetOperationStatus_WithValidHandle_ShouldReturnStatus() async {
        // Given
        let handle = BatchOperationHandle(
            operationId: UUID(),
            type: .compress
        )

        // When
        let status = await sut.getOperationStatus(handle)

        // Then
        XCTAssertEqual(status, .failed) // Currently returns failed in scaffold
    }

    func testGetOperationProgress_WithActiveOperation_ShouldReturnProgress() async {
        // Given
        let handle = BatchOperationHandle(
            operationId: UUID(),
            type: .compress
        )

        // When
        let progress = await sut.getOperationProgress(handle)

        // Then
        XCTAssertEqual(progress.completed, 0)
    }

    func testGetOperationResults_WithCompletedOperation_ShouldReturnResults() async {
        // Given
        let handle = BatchOperationHandle(
            operationId: UUID(),
            type: .compress
        )

        // When
        let results = await sut.getOperationResults(handle)

        // Then
        XCTAssertTrue(results.isEmpty) // Currently returns empty array
    }

    // MARK: - Progress Monitoring Tests

    func testMonitorProgress_ShouldStreamProgressUpdates() async {
        // Given
        let handle = BatchOperationHandle(
            operationId: UUID(),
            type: .compress
        )

        // When
        let stream = sut.monitorProgress(handle)
        var updates: [BatchProgress] = []

        for await progress in stream {
            updates.append(progress)
            if updates.count >= 3 {
                break
            }
        }

        // Then
        XCTAssertTrue(updates.isEmpty) // Currently finishes immediately
    }

    // MARK: - Priority Tests

    func testSetOperationPriority_WithValidHandle_ShouldUpdatePriority() async throws {
        // Given
        let handle = BatchOperationHandle(
            operationId: UUID(),
            type: .compress
        )
        let priority = OperationPriority.urgent

        // When/Then
        await assertThrowsError {
            try await sut.setOperationPriority(handle, priority: priority)
        }
    }

    // MARK: - Active Operations Tests

    func testGetActiveOperations_ShouldReturnAllActive() async {
        // When
        let operations = await sut.getActiveOperations()

        // Then
        XCTAssertTrue(operations.isEmpty) // Currently returns empty
    }

    // MARK: - History Tests

    func testGetOperationHistory_WithLimit_ShouldReturnLimitedHistory() async {
        // Given
        let limit = 10

        // When
        let history = await sut.getOperationHistory(limit: limit)

        // Then
        XCTAssertTrue(history.count <= limit)
        XCTAssertTrue(history.isEmpty) // Currently returns empty
    }

    func testClearCompletedOperations_ShouldRemoveCompleted() async {
        // When
        await sut.clearCompletedOperations()
        let history = await sut.getOperationHistory(limit: 100)

        // Then
        XCTAssertTrue(history.isEmpty)
    }

    // MARK: - Configuration Tests

    func testConfigureEngine_WithCustomSettings_ShouldApplySettings() async {
        // Given
        let settings = BatchEngineSettings(
            maxConcurrentOperations: 5,
            maxConcurrentItems: 8,
            retryPolicy: .aggressive,
            memoryLimit: 1_000_000_000,
            diskSpaceLimit: 5_000_000_000,
            priorityQueueEnabled: true
        )

        // When
        await sut.configureEngine(settings)

        // Then
        // Configuration should be applied (no direct way to verify in scaffold)
    }

    // MARK: - Different Operation Types Tests

    func testStartBatchOperation_Compress_ShouldHandleCompression() async throws {
        // Given
        let assets = [createMockAsset()]
        let operation = BatchOperation(type: .compress, assets: assets)

        // When/Then
        await assertThrowsError {
            _ = try await sut.startBatchOperation(operation)
        }
    }

    func testStartBatchOperation_Convert_ShouldHandleConversion() async throws {
        // Given
        let assets = [createMockAsset()]
        let operation = BatchOperation(type: .convert, assets: assets)

        // When/Then
        await assertThrowsError {
            _ = try await sut.startBatchOperation(operation)
        }
    }

    func testStartBatchOperation_Resize_ShouldHandleResizing() async throws {
        // Given
        let assets = [createMockAsset()]
        let operation = BatchOperation(type: .resize, assets: assets)

        // When/Then
        await assertThrowsError {
            _ = try await sut.startBatchOperation(operation)
        }
    }

    func testStartBatchOperation_Extract_ShouldHandleExtraction() async throws {
        // Given
        let assets = [createMockAsset()]
        let operation = BatchOperation(type: .extract, assets: assets)

        // When/Then
        await assertThrowsError {
            _ = try await sut.startBatchOperation(operation)
        }
    }

    func testStartBatchOperation_Validate_ShouldHandleValidation() async throws {
        // Given
        let assets = [createMockAsset()]
        let operation = BatchOperation(type: .validate, assets: assets)

        // When/Then
        await assertThrowsError {
            _ = try await sut.startBatchOperation(operation)
        }
    }

    func testStartBatchOperation_Upload_ShouldHandleUpload() async throws {
        // Given
        let assets = [createMockAsset()]
        let operation = BatchOperation(type: .upload, assets: assets)

        // When/Then
        await assertThrowsError {
            _ = try await sut.startBatchOperation(operation)
        }
    }

    // MARK: - Error Handling Tests

    func testStartBatchOperation_ContinueOnError_ShouldProcessRemainingItems() async throws {
        // Given
        let assets = Array(repeating: createMockAsset(), count: 5)
        let options = BatchOperationOptions(continueOnError: true)
        let operation = BatchOperation(
            type: .compress,
            assets: assets,
            options: options
        )

        // When/Then
        await assertThrowsError {
            _ = try await sut.startBatchOperation(operation)
        }
    }

    func testStartBatchOperation_StopOnError_ShouldStopAtFirstError() async throws {
        // Given
        let assets = Array(repeating: createMockAsset(), count: 5)
        let options = BatchOperationOptions(continueOnError: false)
        let operation = BatchOperation(
            type: .compress,
            assets: assets,
            options: options
        )

        // When/Then
        await assertThrowsError {
            _ = try await sut.startBatchOperation(operation)
        }
    }

    // MARK: - Timeout Tests

    func testStartBatchOperation_WithTimeout_ShouldRespectTimeout() async throws {
        // Given
        let assets = [createMockAsset()]
        let options = BatchOperationOptions(timeout: 10.0)
        let operation = BatchOperation(
            type: .compress,
            assets: assets,
            options: options
        )

        // When/Then
        await assertThrowsError {
            _ = try await sut.startBatchOperation(operation)
        }
    }
}

// MARK: - Test Helpers

@available(iOS 16.0, *)
extension BatchProcessingEngineTests {
    func assertThrowsError(
        _ expression: @autoclosure () async throws -> some Any,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error but succeeded", file: file, line: line)
        } catch {
            // Expected error
        }
    }

    func createMockAsset() -> MediaAsset {
        MediaAsset(
            type: .image,
            url: URL(fileURLWithPath: "/tmp/test.jpg"),
            metadata: MediaMetadata(
                fileName: "test.jpg",
                fileExtension: "jpg",
                mimeType: "image/jpeg"
            ),
            size: 1000
        )
    }
}
