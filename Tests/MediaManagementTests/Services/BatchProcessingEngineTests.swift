@testable import AppCore
import Dependencies
import Foundation
import XCTest

final class BatchProcessingEngineTests: XCTestCase {
    @Dependency(\.batchProcessingEngine) var batchEngine

    // MARK: - Basic Batch Processing Tests

    func testProcessBatchMedia() async throws {
        // Given
        let assets = createTestAssets(count: 5)
        let configuration = ProcessingConfiguration.default

        // When
        let results = try await batchEngine.processBatchMedia(assets, configuration)

        // Then
        XCTAssertEqual(results.count, assets.count)
        for result in results {
            XCTAssertTrue(result.isSuccess)
            XCTAssertNotNil(result.asset)
        }
    }

    func testProcessMediaQueue() async throws {
        // Given
        let queue = MediaQueue(
            assets: createTestAssets(count: 10),
            configuration: .default,
            maxConcurrentOperations: 3,
            priority: .normal
        )

        // When
        let progressStream = await batchEngine.processMediaQueue(queue)
        var progressUpdates: [QueueProgress] = []

        for await progress in progressStream {
            progressUpdates.append(progress)
            if progress.isComplete {
                break
            }
        }

        // Then
        XCTAssertGreaterThan(progressUpdates.count, 0)
        XCTAssertTrue(progressUpdates.last?.isComplete ?? false)
        XCTAssertEqual(progressUpdates.last?.processedCount, queue.assets.count)
    }

    // MARK: - Concurrent Processing Tests

    func testConcurrentOperationLimit() async throws {
        // Given
        let assets = createTestAssets(count: 20)
        let maxConcurrent = 5
        let queue = MediaQueue(
            assets: assets,
            configuration: .default,
            maxConcurrentOperations: maxConcurrent,
            priority: .high
        )

        // When
        let progressStream = await batchEngine.processMediaQueue(queue)
        var maxConcurrentObserved = 0

        for await progress in progressStream {
            maxConcurrentObserved = max(maxConcurrentObserved, progress.activeOperations)
            if progress.isComplete {
                break
            }
        }

        // Then
        XCTAssertLessThanOrEqual(maxConcurrentObserved, maxConcurrent)
        XCTAssertGreaterThan(maxConcurrentObserved, 0)
    }

    // MARK: - Cancellation Tests

    func testCancelBatchOperation() async throws {
        // Given
        let jobId = UUID()
        let assets = createTestAssets(count: 50) // Large batch

        // Start processing
        Task {
            _ = try await batchEngine.processBatchMedia(assets, .default)
        }

        // When - Cancel after short delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        try await batchEngine.cancelBatchOperation(jobId)

        // Then - Operation should be cancelled
        // (In real implementation, would check cancellation state)
    }

    // MARK: - Pause/Resume Tests

    func testPauseResumeOperation() async throws {
        // Given
        let jobId = UUID()
        let assets = createTestAssets(count: 10)
        var progressUpdates: [QueueProgress] = []

        // Start processing
        let queue = MediaQueue(
            id: jobId,
            assets: assets,
            configuration: .default,
            maxConcurrentOperations: 2,
            priority: .normal
        )

        let progressStream = await batchEngine.processMediaQueue(queue)

        Task {
            for await progress in progressStream {
                progressUpdates.append(progress)

                // Pause after processing 3 items
                if progress.processedCount == 3, !progress.isPaused {
                    try await batchEngine.pauseResumeOperation(jobId, true)
                }

                // Resume after a delay
                if progress.isPaused, progressUpdates.count > 5 {
                    try await Task.sleep(nanoseconds: 100_000_000)
                    try await batchEngine.pauseResumeOperation(jobId, false)
                }

                if progress.isComplete {
                    break
                }
            }
        }

        // Wait for completion
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Then
        XCTAssertTrue(progressUpdates.contains { $0.isPaused })
        XCTAssertTrue(progressUpdates.last?.isComplete ?? false)
    }

    // MARK: - Priority Queue Tests

    func testQueuePriority() async throws {
        // Given
        let highPriorityQueue = MediaQueue(
            assets: createTestAssets(count: 5),
            configuration: .default,
            maxConcurrentOperations: 2,
            priority: .high
        )

        let normalPriorityQueue = MediaQueue(
            assets: createTestAssets(count: 5),
            configuration: .default,
            maxConcurrentOperations: 2,
            priority: .normal
        )

        // When - Process both queues
        let highPriorityTask = Task {
            await batchEngine.processMediaQueue(highPriorityQueue)
        }

        let normalPriorityTask = Task {
            await batchEngine.processMediaQueue(normalPriorityQueue)
        }

        // Then - High priority should be processed first
        // (In real implementation, would verify processing order)
    }

    // MARK: - Error Handling Tests

    func testBatchProcessingWithErrors() async throws {
        // Given - Mix of valid and invalid assets
        var assets = createTestAssets(count: 3)
        assets.append(createInvalidAsset())
        guard let firstTestAsset = createTestAssets(count: 2).first else {
            XCTFail("Failed to create test asset for error handling test")
            return
        }
        assets.append(firstTestAsset)

        // When
        let results = try await batchEngine.processBatchMedia(assets, .default)

        // Then
        XCTAssertEqual(results.count, 5)

        let successCount = results.filter(\.isSuccess).count
        let failureCount = results.filter { !$0.isSuccess }.count

        XCTAssertEqual(successCount, 4)
        XCTAssertEqual(failureCount, 1)
    }

    func testRetryFailedOperations() async throws {
        // Given
        guard let firstAsset = createTestAssets(count: 2).first else {
            XCTFail("Failed to create test asset for retry operations test")
            return
        }
        let assets = [createInvalidAsset(), firstAsset]
        let configuration = ProcessingConfiguration(
            targetFormat: .optimized,
            compressionSettings: .default,
            ocrEnabled: false,
            enhancementEnabled: true,
            metadataPreservation: .keepEssential,
            retryFailedOperations: true,
            maxRetries: 2
        )

        // When
        let results = try await batchEngine.processBatchMedia(assets, configuration)

        // Then
        XCTAssertEqual(results.count, 2)
        // Verify retry attempts were made
    }

    // MARK: - Progress Tracking Tests

    func testDetailedProgressTracking() async throws {
        // Given
        let assets = createTestAssets(count: 10)
        let queue = MediaQueue(
            assets: assets,
            configuration: .default,
            maxConcurrentOperations: 3,
            priority: .normal
        )

        // When
        var progressUpdates: [QueueProgress] = []
        let progressStream = await batchEngine.processMediaQueue(queue)

        for await progress in progressStream {
            progressUpdates.append(progress)

            // Verify progress properties
            XCTAssertGreaterThanOrEqual(progress.processedCount, 0)
            XCTAssertLessThanOrEqual(progress.processedCount, assets.count)
            XCTAssertGreaterThanOrEqual(progress.successCount, 0)
            XCTAssertGreaterThanOrEqual(progress.failureCount, 0)
            XCTAssertEqual(progress.totalCount, assets.count)

            if progress.isComplete {
                break
            }
        }

        // Then
        guard let finalProgress = progressUpdates.last else {
            XCTFail("No progress updates received during detailed progress tracking")
            return
        }
        XCTAssertTrue(finalProgress.isComplete)
        XCTAssertEqual(finalProgress.processedCount, assets.count)
        XCTAssertEqual(finalProgress.fractionCompleted, 1.0, accuracy: 0.01)
    }

    // MARK: - Memory Management Tests

    func testMemoryEfficientProcessing() async throws {
        // Given - Large batch that would exceed memory if all loaded at once
        let largeAssets = createTestAssets(count: 100, large: true)
        let configuration = ProcessingConfiguration(
            targetFormat: .compressed,
            compressionSettings: CompressionSettings(
                maxDimension: 1024,
                compressionQuality: 0.7
            ),
            memoryLimit: 200 * 1024 * 1024 // 200MB limit
        )

        // When
        let queue = MediaQueue(
            assets: largeAssets,
            configuration: configuration,
            maxConcurrentOperations: 2, // Low concurrency for memory
            priority: .normal
        )

        let progressStream = await batchEngine.processMediaQueue(queue)
        var peakMemoryUsage: Int64 = 0

        for await progress in progressStream {
            peakMemoryUsage = max(peakMemoryUsage, progress.memoryUsage)
            if progress.isComplete {
                break
            }
        }

        // Then
        XCTAssertLessThan(peakMemoryUsage, configuration.memoryLimit ?? Int64.max)
    }

    // MARK: - Helper Methods

    private func createTestAssets(count: Int, large: Bool = false) -> [MediaAsset] {
        (0 ..< count).map { index in
            let size = large ? CGSize(width: 4000, height: 3000) : CGSize(width: 1000, height: 1000)
            let data = createTestImageData(size: size)

            return MediaAsset(
                type: .photo,
                data: data,
                metadata: MediaMetadata(
                    fileName: "test_\(index).jpg",
                    fileSize: Int64(data.count),
                    mimeType: "image/jpeg",
                    dimensions: MediaDimensions(width: Int(size.width), height: Int(size.height)),
                    securityInfo: SecurityInfo(isSafe: true)
                ),
                processingState: .pending,
                sourceInfo: MediaSource(type: .photoLibrary)
            )
        }
    }

    private func createInvalidAsset() -> MediaAsset {
        MediaAsset(
            type: .other,
            data: Data("Invalid data".utf8),
            metadata: MediaMetadata(
                fileName: "invalid.dat",
                fileSize: 100,
                mimeType: "application/octet-stream",
                securityInfo: SecurityInfo(isSafe: false)
            ),
            processingState: .pending,
            sourceInfo: MediaSource(type: .documentPicker)
        )
    }

    private func createTestImageData(size: CGSize) -> Data {
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }

        let colors: [UIColor] = [.red, .green, .blue, .yellow, .orange]
        guard let color = colors.randomElement() else {
            // This should never happen with a non-empty array, but we need to handle it
            fatalError("Failed to get random color from non-empty array")
        }

        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            fatalError("Failed to create image from graphics context")
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            fatalError("Failed to convert image to JPEG data")
        }

        return imageData
    }
}
