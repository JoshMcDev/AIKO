@testable import AppCore
import Dependencies
import Foundation
import XCTest

final class MediaValidationServiceTests: XCTestCase {
    @Dependency(\.mediaValidationService) var validationService

    // MARK: - File Type Validation

    func testValidateFileTypePhoto() async throws {
        // Given
        let imageData = createTestImageData()
        let fileName = "test.jpg"

        // When
        let mediaType = try await validationService.validateFileType(imageData, fileName)

        // Then
        XCTAssertEqual(mediaType, .photo)
    }

    func testValidateFileTypeDocument() async throws {
        // Given
        let pdfData = createTestPDFData()
        let fileName = "document.pdf"

        // When
        let mediaType = try await validationService.validateFileType(pdfData, fileName)

        // Then
        XCTAssertEqual(mediaType, .pdf)
    }

    func testValidateFileTypeInvalid() async {
        // Given
        let invalidData = Data("Invalid file".utf8)
        let fileName = "malware.exe"

        // When/Then
        do {
            _ = try await validationService.validateFileType(invalidData, fileName)
            XCTFail("Should throw error for invalid file type")
        } catch {
            XCTAssertTrue(error is MediaError)
        }
    }

    // MARK: - File Size Validation

    func testValidateFileSizeWithinLimit() {
        // Given
        let fileSize: Int64 = 5 * 1024 * 1024 // 5MB
        let mediaType = MediaType.photo

        // When
        let isValid = validationService.validateFileSize(fileSize, mediaType)

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidateFileSizeExceedsLimit() {
        // Given
        let fileSize: Int64 = 200 * 1024 * 1024 // 200MB
        let mediaType = MediaType.photo

        // When
        let isValid = validationService.validateFileSize(fileSize, mediaType)

        // Then
        XCTAssertFalse(isValid)
    }

    func testValidateFileSizePerType() {
        // Photo: 50MB limit
        XCTAssertTrue(validationService.validateFileSize(40 * 1024 * 1024, .photo))
        XCTAssertFalse(validationService.validateFileSize(60 * 1024 * 1024, .photo))

        // Document: 20MB limit
        XCTAssertTrue(validationService.validateFileSize(15 * 1024 * 1024, .document))
        XCTAssertFalse(validationService.validateFileSize(25 * 1024 * 1024, .document))

        // Video: 500MB limit
        XCTAssertTrue(validationService.validateFileSize(400 * 1024 * 1024, .video))
        XCTAssertFalse(validationService.validateFileSize(600 * 1024 * 1024, .video))
    }

    // MARK: - Security Scanning

    func testScanForMalwareSafe() async throws {
        // Given
        let safeData = createTestImageData()

        // When
        let securityInfo = try await validationService.scanForMalware(safeData)

        // Then
        XCTAssertTrue(securityInfo.isSafe)
        XCTAssertEqual(securityInfo.threats.count, 0)
    }

    func testScanForMalwareThreatDetected() async throws {
        // Given
        let suspiciousData = createSuspiciousData()

        // When
        let securityInfo = try await validationService.scanForMalware(suspiciousData)

        // Then
        XCTAssertFalse(securityInfo.isSafe)
        XCTAssertGreaterThan(securityInfo.threats.count, 0)
    }

    // MARK: - Metadata Extraction

    func testExtractMetadataFromPhoto() async throws {
        // Given
        let imageData = createTestImageData()
        let mediaType = MediaType.photo

        // When
        let metadata = try await validationService.extractMetadata(imageData, mediaType)

        // Then
        XCTAssertNotNil(metadata)
        XCTAssertGreaterThan(metadata.fileSize, 0)
        XCTAssertNotNil(metadata.dimensions)
        XCTAssertEqual(metadata.mimeType, "image/jpeg")
    }

    func testExtractMetadataWithEXIF() async throws {
        // Given
        let imageDataWithEXIF = createTestImageDataWithEXIF()
        let mediaType = MediaType.photo

        // When
        let metadata = try await validationService.extractMetadata(imageDataWithEXIF, mediaType)

        // Then
        XCTAssertNotNil(metadata.exifData)
        XCTAssertNotNil(metadata.exifData?.camera)
        XCTAssertNotNil(metadata.exifData?.captureDate)
    }

    // MARK: - Comprehensive Validation

    func testValidateMediaAssetSuccess() async throws {
        // Given
        let asset = createTestAsset()
        let rules = FileValidationRules.photoDefaults

        // When
        let result = try await validationService.validateMediaAsset(asset, rules)

        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.error)
    }

    func testValidateMediaAssetWithWarnings() async throws {
        // Given
        let largeAsset = createLargeTestAsset()
        let rules = FileValidationRules.photoDefaults

        // When
        let result = try await validationService.validateMediaAsset(largeAsset, rules)

        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertGreaterThan(result.warnings.count, 0)
        XCTAssertTrue(result.warnings.contains { $0.type == .fileSizeLarge })
    }

    func testValidateMediaAssetFailure() async throws {
        // Given
        let invalidAsset = createInvalidTestAsset()
        let rules = FileValidationRules.photoDefaults

        // When
        let result = try await validationService.validateMediaAsset(invalidAsset, rules)

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.error)
    }

    // MARK: - Batch Validation

    func testValidateBatch() async throws {
        // Given
        let assets = [
            createTestAsset(),
            createTestAsset(),
            createInvalidTestAsset(),
        ]
        let rules = FileValidationRules.default

        // When
        let results = try await validationService.validateBatch(assets, rules)

        // Then
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[0].isValid)
        XCTAssertTrue(results[1].isValid)
        XCTAssertFalse(results[2].isValid)
    }

    // MARK: - Helper Methods

    private func createTestImageData() -> Data {
        // Create a simple valid JPEG data
        UIGraphicsBeginImageContext(CGSize(width: 100, height: 100))
        defer { UIGraphicsEndImageContext() }

        UIColor.blue.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 100))

        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            XCTFail("Failed to create image from graphics context")
            return Data()
        }

        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            XCTFail("Failed to convert image to JPEG data")
            return Data()
        }

        return jpegData
    }

    private func createTestImageDataWithEXIF() -> Data {
        // In real implementation, this would include EXIF metadata
        createTestImageData()
    }

    private func createTestPDFData() -> Data {
        // Create simple PDF data
<<<<<<< HEAD
        return Data("%PDF-1.4\n%âãÏÓ\n".utf8)
=======
        "%PDF-1.4\n%âãÏÓ\n".data(using: .utf8)!
>>>>>>> Main
    }

    private func createSuspiciousData() -> Data {
        // Data that would trigger security warnings
<<<<<<< HEAD
        return Data("MZ\u{0090}\u{0003}".utf8) // PE header signature
=======
        "MZ\u{0090}\u{0003}".data(using: .utf8)! // PE header signature
>>>>>>> Main
    }

    private func createTestAsset() -> MediaAsset {
        MediaAsset(
            type: .photo,
            data: createTestImageData(),
            metadata: MediaMetadata(
                fileName: "test.jpg",
                fileSize: 1024 * 1024, // 1MB
                mimeType: "image/jpeg",
                dimensions: MediaDimensions(width: 800, height: 600),
                securityInfo: SecurityInfo(isSafe: true)
            ),
            processingState: .pending,
            sourceInfo: MediaSource(type: .photoLibrary)
        )
    }

    private func createLargeTestAsset() -> MediaAsset {
        MediaAsset(
            type: .photo,
            data: createTestImageData(),
            metadata: MediaMetadata(
                fileName: "large.jpg",
                fileSize: 45 * 1024 * 1024, // 45MB
                mimeType: "image/jpeg",
                dimensions: MediaDimensions(width: 4000, height: 3000),
                securityInfo: SecurityInfo(isSafe: true)
            ),
            processingState: .pending,
            sourceInfo: MediaSource(type: .photoLibrary)
        )
    }

    private func createInvalidTestAsset() -> MediaAsset {
        MediaAsset(
            type: .other,
            data: Data("Invalid".utf8),
            metadata: MediaMetadata(
                fileName: "malware.exe",
                fileSize: 1024,
                mimeType: "application/x-msdownload",
                securityInfo: SecurityInfo(isSafe: false, threats: [
                    ThreatInfo(type: .malware, severity: .critical, description: "Potential malware detected"),
                ])
            ),
            processingState: .pending,
            sourceInfo: MediaSource(type: .documentPicker)
        )
    }
}
