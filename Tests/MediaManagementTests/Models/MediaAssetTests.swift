@testable import AppCore
import Foundation
import XCTest

final class MediaAssetTests: XCTestCase {
    func testMediaAssetInitialization() throws {
        // Given
        let id = UUID()
        let data = Data("Test data".utf8)
        let metadata = MediaMetadata(
            fileName: "test.jpg",
            fileSize: 1024,
            mimeType: "image/jpeg",
            dimensions: MediaDimensions(width: 800, height: 600),
            exifData: nil,
            processingMetrics: nil,
            securityInfo: SecurityInfo(isSafe: true, scanDate: Date())
        )
        let sourceInfo = MediaSource(type: .photoLibrary, identifier: "photo123")

        // When
        let asset = MediaAsset(
            id: id,
            type: .photo,
            data: data,
            metadata: metadata,
            processingState: .pending,
            sourceInfo: sourceInfo,
            capturedAt: Date()
        )

        // Then
        XCTAssertEqual(asset.id, id)
        XCTAssertEqual(asset.type, .photo)
        XCTAssertEqual(asset.data, data)
        XCTAssertEqual(asset.metadata.fileName, "test.jpg")
        XCTAssertEqual(asset.processingState, .pending)
        XCTAssertEqual(asset.sourceInfo.type, .photoLibrary)
    }

    func testMediaTypeAllowedExtensions() {
        // Photo extensions
        XCTAssertEqual(MediaType.photo.allowedExtensions, ["jpg", "jpeg", "png", "heic", "heif"])

        // Document extensions
        XCTAssertEqual(MediaType.document.allowedExtensions, ["pdf", "doc", "docx", "txt", "rtf"])

        // Screenshot extensions
        XCTAssertEqual(MediaType.screenshot.allowedExtensions, ["png", "jpg", "jpeg"])

        // PDF extensions
        XCTAssertEqual(MediaType.pdf.allowedExtensions, ["pdf"])

        // Video extensions
        XCTAssertEqual(MediaType.video.allowedExtensions, ["mp4", "mov", "m4v"])

        // Other extensions
        XCTAssertEqual(MediaType.other.allowedExtensions, [])
    }

    func testProcessingStateTransitions() {
        // Given
        var asset = createTestAsset()

        // Test state transitions
        XCTAssertEqual(asset.processingState, .pending)

        asset.processingState = .processing(progress: 0.5)
        if case let .processing(progress) = asset.processingState {
            XCTAssertEqual(progress, 0.5)
        } else {
            XCTFail("Expected processing state")
        }

        asset.processingState = .completed
        XCTAssertEqual(asset.processingState, .completed)

        asset.processingState = .failed(error: MediaError.processingFailed("Test error"))
        if case let .failed(error) = asset.processingState {
            XCTAssertNotNil(error)
        } else {
            XCTFail("Expected failed state")
        }
    }

    func testMediaAssetWithProcessingResult() {
        // Given
        var asset = createTestAsset()
        let processingResult = DocumentImageProcessor.ProcessingResult(
            enhancedImage: UIImage(),
            textRegions: [],
            confidence: 0.95
        )

        // When
        asset.documentProcessingResult = processingResult

        // Then
        XCTAssertNotNil(asset.documentProcessingResult)
        XCTAssertEqual(asset.documentProcessingResult?.confidence, 0.95)
    }

    func testMediaAssetWithFormPopulationData() {
        // Given
        var asset = createTestAsset()
        let populationData = FormAutoPopulationEngine.PopulationData(
            extractedFields: [:],
            confidence: 0.85,
            suggestions: []
        )

        // When
        asset.formPopulationData = populationData

        // Then
        XCTAssertNotNil(asset.formPopulationData)
        XCTAssertEqual(asset.formPopulationData?.confidence, 0.85)
    }

    func testMediaAssetEquality() {
        // Given
        let asset1 = createTestAsset()
        let asset2 = createTestAsset()

        // Then - Different assets should not be equal (different IDs)
        XCTAssertNotEqual(asset1, asset2)

        // When - Same ID
        let asset3 = MediaAsset(
            id: asset1.id,
            type: asset1.type,
            data: asset1.data,
            metadata: asset1.metadata,
            processingState: asset1.processingState,
            sourceInfo: asset1.sourceInfo,
            capturedAt: asset1.capturedAt
        )

        // Then
        XCTAssertEqual(asset1, asset3)
    }

    func testMediaAssetIdentifiable() {
        // Given
        let asset = createTestAsset()

        // Then
        XCTAssertNotNil(asset.id)
        XCTAssertTrue(!asset.id.uuidString.isEmpty)
    }

    // MARK: - Helper Methods

    private func createTestAsset() -> MediaAsset {
        MediaAsset(
            id: UUID(),
            type: .photo,
            data: Data("Test data".utf8),
            metadata: MediaMetadata(
                fileName: "test.jpg",
                fileSize: 1024,
                mimeType: "image/jpeg",
                dimensions: MediaDimensions(width: 800, height: 600),
                exifData: nil,
                processingMetrics: nil,
                securityInfo: SecurityInfo(isSafe: true, scanDate: Date())
            ),
            processingState: .pending,
            sourceInfo: MediaSource(type: .photoLibrary, identifier: "test"),
            capturedAt: Date()
        )
    }
}
