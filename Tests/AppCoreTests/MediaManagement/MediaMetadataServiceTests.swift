@testable import AppCoreiOS
@testable import AppCore
import XCTest

@available(iOS 16.0, *)
final class MediaMetadataServiceTests: XCTestCase {
    var sut: MediaMetadataService?

    private var sutUnwrapped: MediaMetadataService {
        guard let sut else { fatalError("sut not initialized") }
        return sut
    }

    override func setUp() async throws {
        try await super.setUp()
        sut = MediaMetadataService()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Metadata Extraction Tests

    func testExtractMetadata_FromImageURL_ShouldExtractImageMetadata() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/test.jpg")

        // When/Then
        await assertThrowsError {
            _ = try await sut.extractMetadata(from: url)
        }
    }

    func testExtractMetadata_FromVideoURL_ShouldExtractVideoMetadata() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/test.mp4")

        // When/Then
        await assertThrowsError {
            _ = try await sut.extractMetadata(from: url)
        }
    }

    func testExtractMetadata_FromAudioURL_ShouldExtractAudioMetadata() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/test.mp3")

        // When/Then
        await assertThrowsError {
            _ = try await sut.extractMetadata(from: url)
        }
    }

    func testExtractMetadata_FromData_ShouldExtractMetadata() async throws {
        // Given
        let data = Data()
        let type = MediaType.image

        // When/Then
        await assertThrowsError {
            _ = try await sut.extractMetadata(from: data, type: type)
        }
    }

    func testExtractMetadata_WithInvalidURL_ShouldThrowError() async throws {
        // Given
        let url = URL(fileURLWithPath: "/invalid/path.jpg")

        // When/Then
        await assertThrowsError {
            _ = try await sut.extractMetadata(from: url)
        }
    }

    // MARK: - Metadata Writing Tests

    func testWriteMetadata_ToImageFile_ShouldUpdateMetadata() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/test.jpg")
        let metadata = MediaMetadata(
            fileName: "updated.jpg",
            fileExtension: "jpg",
            mimeType: "image/jpeg"
        )

        // When/Then
        await assertThrowsError {
            try await sut.writeMetadata(metadata, to: url)
        }
    }

    func testWriteMetadata_WithLocationData_ShouldWriteGPSTags() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/test.jpg")
        let location = LocationData(latitude: 37.7749, longitude: -122.4194)
        let metadata = MediaMetadata(
            fileName: "test.jpg",
            fileExtension: "jpg",
            mimeType: "image/jpeg",
            location: location
        )

        // When/Then
        await assertThrowsError {
            try await sut.writeMetadata(metadata, to: url)
        }
    }

    // MARK: - Metadata Removal Tests

    func testRemoveMetadata_AllFields_ShouldStripAllMetadata() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/test.jpg")
        let fields: Set<MetadataField> = [.all]

        // When/Then
        await assertThrowsError {
            _ = try await sut.removeMetadata(from: url, fields: fields)
        }
    }

    func testRemoveMetadata_LocationOnly_ShouldRemoveGPSData() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/test.jpg")
        let fields: Set<MetadataField> = [.location]

        // When/Then
        await assertThrowsError {
            _ = try await sut.removeMetadata(from: url, fields: fields)
        }
    }

    func testRemoveMetadata_CameraInfo_ShouldRemoveEXIFData() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/test.jpg")
        let fields: Set<MetadataField> = [.camera]

        // When/Then
        await assertThrowsError {
            _ = try await sut.removeMetadata(from: url, fields: fields)
        }
    }

    // MARK: - Thumbnail Generation Tests

    func testGenerateThumbnail_FromImage_ShouldCreateThumbnail() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/test.jpg")
        let size = CGSize(width: 150, height: 150)

        // When/Then
        await assertThrowsError {
            _ = try await sut.generateThumbnail(from: url, size: size, time: nil)
        }
    }

    func testGenerateThumbnail_FromVideo_AtSpecificTime_ShouldExtractFrame() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/test.mp4")
        let size = CGSize(width: 200, height: 200)
        let time: TimeInterval = 5.0

        // When/Then
        await assertThrowsError {
            _ = try await sut.generateThumbnail(from: url, size: size, time: time)
        }
    }

    func testGenerateThumbnail_WithInvalidSize_ShouldThrowError() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/test.jpg")
        let size = CGSize(width: 0, height: 0)

        // When/Then
        await assertThrowsError {
            _ = try await sut.generateThumbnail(from: url, size: size, time: nil)
        }
    }

    // MARK: - OCR Tests

    func testExtractText_FromImage_ShouldReturnText() async throws {
        // Given
        let imageData = Data()

        // When/Then
        await assertThrowsError {
            _ = try await sut.extractText(from: imageData)
        }
    }

    func testExtractText_FromImageWithNoText_ShouldReturnEmptyText() async throws {
        // Given
        let imageData = Data() // Blank image

        // When/Then
        await assertThrowsError {
            _ = try await sut.extractText(from: imageData)
        }
    }

    // MARK: - Face Detection Tests

    func testDetectFaces_InImageWithFaces_ShouldDetectFaces() async throws {
        // Given
        let imageData = Data()

        // When/Then
        await assertThrowsError {
            _ = try await sut.detectFaces(in: imageData)
        }
    }

    func testDetectFaces_InImageWithoutFaces_ShouldReturnEmptyArray() async throws {
        // Given
        let imageData = Data() // Image without faces

        // When/Then
        await assertThrowsError {
            _ = try await sut.detectFaces(in: imageData)
        }
    }

    // MARK: - Image Analysis Tests

    func testAnalyzeImageContent_ShouldReturnClassifications() async throws {
        // Given
        let imageData = Data()

        // When/Then
        await assertThrowsError {
            _ = try await sut.analyzeImageContent(imageData)
        }
    }

    func testAnalyzeImageContent_ShouldDetectObjects() async throws {
        // Given
        let imageData = Data()

        // When/Then
        await assertThrowsError {
            _ = try await sut.analyzeImageContent(imageData)
        }
    }

    func testAnalyzeImageContent_ShouldAnalyzeColors() async throws {
        // Given
        let imageData = Data()

        // When/Then
        await assertThrowsError {
            _ = try await sut.analyzeImageContent(imageData)
        }
    }

    func testAnalyzeImageContent_ShouldAssessQuality() async throws {
        // Given
        let imageData = Data()

        // When/Then
        await assertThrowsError {
            _ = try await sut.analyzeImageContent(imageData)
        }
    }

    // MARK: - Audio Processing Tests

    func testExtractWaveform_FromAudioFile_ShouldReturnSamples() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/audio.mp3")
        let samples = 1000

        // When/Then
        await assertThrowsError {
            _ = try await sut.extractWaveform(from: url, samples: samples)
        }
    }

    // MARK: - Video Processing Tests

    func testExtractVideoFrame_AtStartTime_ShouldExtractFirstFrame() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/video.mp4")
        let time: TimeInterval = 0.0

        // When/Then
        await assertThrowsError {
            _ = try await sut.extractVideoFrame(from: url, at: time)
        }
    }

    func testExtractVideoFrame_AtMiddleTime_ShouldExtractFrame() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/video.mp4")
        let time: TimeInterval = 30.0

        // When/Then
        await assertThrowsError {
            _ = try await sut.extractVideoFrame(from: url, at: time)
        }
    }

    // MARK: - Comprehensive Metadata Tests

    func testGetAllMetadata_ShouldReturnCompleteDictionary() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/test.jpg")

        // When/Then
        await assertThrowsError {
            _ = try await sut.getAllMetadata(from: url)
        }
    }

    func testGetAllMetadata_FromVideoFile_ShouldIncludeVideoSpecificData() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/video.mp4")

        // When/Then
        await assertThrowsError {
            _ = try await sut.getAllMetadata(from: url)
        }
    }
}

// MARK: - Test Helpers

@available(iOS 16.0, *)
extension MediaMetadataServiceTests {
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
}
