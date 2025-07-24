@testable import AppCore
import Foundation
import XCTest

final class ProcessingJobTests: XCTestCase {
    func testProcessingJobInitialization() {
        // Given
        let assets = [createTestAsset(), createTestAsset()]
        let id = UUID()

        // When
        let job = ProcessingJob(
            id: id,
            assets: assets,
            state: .pending,
            progress: Progress(totalUnitCount: 100),
            jobType: .batchUpload,
            results: [],
            createdAt: Date()
        )

        // Then
        XCTAssertEqual(job.id, id)
        XCTAssertEqual(job.assets.count, 2)
        XCTAssertEqual(job.state, .pending)
        XCTAssertEqual(job.jobType, .batchUpload)
        XCTAssertEqual(job.results.count, 0)
    }

    func testJobStateTransitions() {
        // Given
        var job = createTestJob()

        // Test state transitions
        XCTAssertEqual(job.state, .pending)

        job.state = .processing
        XCTAssertEqual(job.state, .processing)

        job.state = .completed
        XCTAssertEqual(job.state, .completed)

        job.state = .failed(error: MediaError.processingFailed("Test"))
        if case let .failed(error) = job.state {
            XCTAssertNotNil(error)
        } else {
            XCTFail("Expected failed state")
        }

        job.state = .cancelled
        XCTAssertEqual(job.state, .cancelled)
    }

    func testProgressTracking() {
        // Given
        var job = createTestJob()
        job.progress.totalUnitCount = 100

        // When
        job.progress.completedUnitCount = 50

        // Then
        XCTAssertEqual(job.progress.fractionCompleted, 0.5, accuracy: 0.01)

        // When complete
        job.progress.completedUnitCount = 100
        XCTAssertEqual(job.progress.fractionCompleted, 1.0, accuracy: 0.01)
    }

    func testJobTypeVariants() {
        // Test all job types
        let types: [JobType] = [
            .batchUpload,
            .batchProcessing,
            .formPopulation,
            .export,
        ]

        for type in types {
            let job = ProcessingJob(
                assets: [],
                state: .pending,
                progress: Progress(),
                jobType: type,
                results: []
            )
            XCTAssertEqual(job.jobType, type)
        }
    }

    func testProcessingResultSuccess() {
        // Given
        let asset = createTestAsset()
        let result = ProcessingResult.success(asset: asset)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.asset)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.processingDuration, 0)
    }

    func testProcessingResultFailure() {
        // Given
        let originalAsset = createTestAsset()
        let error = MediaError.processingFailed("Test error")
        let result = ProcessingResult.failure(
            originalAsset: originalAsset,
            error: error,
            processingDuration: 2.5
        )

        // Then
        XCTAssertFalse(result.isSuccess)
        XCTAssertNil(result.asset)
        XCTAssertNotNil(result.originalAsset)
        XCTAssertEqual(result.error, error)
        XCTAssertEqual(result.processingDuration, 2.5)
    }

    func testJobWithMultipleResults() {
        // Given
        var job = createTestJob()
        let results = [
            ProcessingResult.success(asset: createTestAsset()),
            ProcessingResult.failure(
                originalAsset: createTestAsset(),
                error: MediaError.processingFailed("Error")
            ),
            ProcessingResult.success(asset: createTestAsset()),
        ]

        // When
        job.results = results

        // Then
        XCTAssertEqual(job.results.count, 3)
        XCTAssertTrue(job.results[0].isSuccess)
        XCTAssertFalse(job.results[1].isSuccess)
        XCTAssertTrue(job.results[2].isSuccess)
    }

    func testJobSuccessRate() {
        // Given
        var job = createTestJob()
        job.results = [
            ProcessingResult.success(asset: createTestAsset()),
            ProcessingResult.failure(originalAsset: createTestAsset(), error: MediaError.processingFailed("Error")),
            ProcessingResult.success(asset: createTestAsset()),
            ProcessingResult.success(asset: createTestAsset()),
        ]

        // When
        let successCount = job.results.filter(\.isSuccess).count
        let successRate = Double(successCount) / Double(job.results.count)

        // Then
        XCTAssertEqual(successCount, 3)
        XCTAssertEqual(successRate, 0.75, accuracy: 0.01)
    }

    // MARK: - Helper Methods

    private func createTestAsset() -> MediaAsset {
        MediaAsset(
            type: .photo,
            data: Data(),
            metadata: MediaMetadata(
                fileName: "test.jpg",
                fileSize: 1024,
                mimeType: "image/jpeg",
                securityInfo: SecurityInfo(isSafe: true)
            ),
            processingState: .pending,
            sourceInfo: MediaSource(type: .photoLibrary)
        )
    }

    private func createTestJob() -> ProcessingJob {
        ProcessingJob(
            assets: [createTestAsset(), createTestAsset()],
            state: .pending,
            progress: Progress(totalUnitCount: 100),
            jobType: .batchProcessing,
            results: []
        )
    }
}
