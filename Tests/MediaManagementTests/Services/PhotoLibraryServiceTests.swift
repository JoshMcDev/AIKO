@testable import AppCore
import Dependencies
import Foundation
import Photos
import PhotosUI
import XCTest

final class PhotoLibraryServiceTests: XCTestCase {
    @Dependency(\.photoLibraryService) var photoLibrary

    // MARK: - Authorization Tests

    func testRequestAuthorizationGranted() async {
        // When
        let status = await photoLibrary.requestAuthorization()

        // Then - In test environment, should return authorized
        XCTAssertEqual(status, .authorized)
    }

    func testRequestAuthorizationDenied() async {
        // Given - Configure test to return denied
        withDependencies {
            $0.photoLibraryService.requestAuthorization = { .denied }
        } operation: {
            // When
            let status = await photoLibrary.requestAuthorization()

            // Then
            XCTAssertEqual(status, .denied)
        }
    }

    // MARK: - Photo Selection Tests

    func testSelectSinglePhoto() async throws {
        // When
        let asset = try await photoLibrary.selectSinglePhoto()

        // Then
        XCTAssertNotNil(asset)
        XCTAssertEqual(asset?.type, .photo)
        XCTAssertGreaterThan(asset?.data.count ?? 0, 0)
        XCTAssertNotNil(asset?.metadata)
    }

    func testSelectMultiplePhotos() async throws {
        // Given
        let maxSelection = 5

        // When
        let assets = try await photoLibrary.selectPhotos(maxSelection)

        // Then
        XCTAssertGreaterThan(assets.count, 0)
        XCTAssertLessThanOrEqual(assets.count, maxSelection)
        for asset in assets {
            XCTAssertEqual(asset.type, .photo)
            XCTAssertGreaterThan(asset.data.count, 0)
        }
    }

    func testSelectPhotosWithNoAuthorization() async {
        // Given
        withDependencies {
            $0.photoLibraryService.requestAuthorization = { .denied }
            $0.photoLibraryService.selectPhotos = { _ in
                throw MediaError.permissionDenied
            }
        } operation: {
            // When/Then
            do {
                _ = try await photoLibrary.selectPhotos(5)
                XCTFail("Should throw permission denied error")
            } catch MediaError.permissionDenied {
                // Expected
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - Photo Optimization Tests

    func testOptimizePhotoDefaultSettings() async throws {
        // Given
        let originalAsset = createTestPhotoAsset(size: CGSize(width: 4000, height: 3000))
        let settings = CompressionSettings.default

        // When
        let optimizedAsset = try await photoLibrary.optimizePhoto(originalAsset, settings)

        // Then
        XCTAssertLessThan(optimizedAsset.data.count, originalAsset.data.count)
        XCTAssertEqual(optimizedAsset.type, .photo)
        XCTAssertNotNil(optimizedAsset.metadata.dimensions)
    }

    func testOptimizePhotoWithCustomSettings() async throws {
        // Given
        let originalAsset = createTestPhotoAsset(size: CGSize(width: 4000, height: 3000))
        let settings = CompressionSettings(
            maxDimension: 1920,
            compressionQuality: 0.7,
            preserveMetadata: true,
            targetSize: 500 * 1024 // 500KB
        )

        // When
        let optimizedAsset = try await photoLibrary.optimizePhoto(originalAsset, settings)

        // Then
        XCTAssertLessThan(optimizedAsset.data.count, originalAsset.data.count)
        XCTAssertLessThanOrEqual(optimizedAsset.metadata.dimensions?.width ?? 0, 1920)
        XCTAssertLessThanOrEqual(optimizedAsset.metadata.dimensions?.height ?? 0, 1920)
    }

    func testOptimizePhotoPreservesMetadata() async throws {
        // Given
        let originalAsset = createTestPhotoAssetWithEXIF()
        let settings = CompressionSettings(
            maxDimension: 2048,
            compressionQuality: 0.9,
            preserveMetadata: true
        )

        // When
        let optimizedAsset = try await photoLibrary.optimizePhoto(originalAsset, settings)

        // Then
        XCTAssertNotNil(optimizedAsset.metadata.exifData)
        XCTAssertEqual(optimizedAsset.metadata.exifData?.camera, originalAsset.metadata.exifData?.camera)
        XCTAssertEqual(optimizedAsset.metadata.exifData?.captureDate, originalAsset.metadata.exifData?.captureDate)
    }

    // MARK: - Metadata Extraction Tests

    func testExtractPhotoMetadata() async throws {
        // Given
        let asset = createTestPhotoAssetWithEXIF()

        // When
        let metadata = try await photoLibrary.extractPhotoMetadata(asset)

        // Then
        XCTAssertNotNil(metadata)
        XCTAssertNotNil(metadata.dimensions)
        XCTAssertNotNil(metadata.colorSpace)
        XCTAssertNotNil(metadata.creationDate)
        XCTAssertEqual(metadata.assetType, .photo)
    }

    // MARK: - Batch Operations Tests

    func testBatchPhotoSelection() async throws {
        // When
        let assets = try await photoLibrary.selectPhotos(10)

        // Then
        XCTAssertGreaterThan(assets.count, 0)
        XCTAssertLessThanOrEqual(assets.count, 10)

        // Verify all are photos
        for asset in assets {
            XCTAssertEqual(asset.type, .photo)
        }
    }

    func testBatchPhotoOptimization() async throws {
        // Given
        let originalAssets = (0 ..< 3).map { _ in
            createTestPhotoAsset(size: CGSize(width: 3000, height: 2000))
        }
        let settings = CompressionSettings.default

        // When
        let optimizedAssets = try await withThrowingTaskGroup(of: MediaAsset.self) { group in
            for asset in originalAssets {
                group.addTask {
                    try await self.photoLibrary.optimizePhoto(asset, settings)
                }
            }

            var results: [MediaAsset] = []
            for try await optimized in group {
                results.append(optimized)
            }
            return results
        }

        // Then
        XCTAssertEqual(optimizedAssets.count, originalAssets.count)
        for (index, optimized) in optimizedAssets.enumerated() {
            XCTAssertLessThan(optimized.data.count, originalAssets[index].data.count)
        }
    }

    // MARK: - Error Handling Tests

    func testHandleCorruptedPhotoData() async {
        // Given
        let corruptedAsset = MediaAsset(
            type: .photo,
            data: Data("corrupted".utf8),
            metadata: MediaMetadata(
                fileName: "corrupted.jpg",
                fileSize: 100,
                mimeType: "image/jpeg",
                securityInfo: SecurityInfo(isSafe: true)
            ),
            processingState: .pending,
            sourceInfo: MediaSource(type: .photoLibrary)
        )

        // When/Then
        do {
            _ = try await photoLibrary.optimizePhoto(corruptedAsset, .default)
            XCTFail("Should throw error for corrupted data")
        } catch {
            XCTAssertTrue(error is MediaError)
        }
    }

    // MARK: - Helper Methods

    private func createTestPhotoAsset(size: CGSize) -> MediaAsset {
        let imageData = createImageData(size: size)

        return MediaAsset(
            type: .photo,
            data: imageData,
            metadata: MediaMetadata(
                fileName: "test.jpg",
                fileSize: Int64(imageData.count),
                mimeType: "image/jpeg",
                dimensions: MediaDimensions(width: Int(size.width), height: Int(size.height)),
                securityInfo: SecurityInfo(isSafe: true)
            ),
            processingState: .pending,
            sourceInfo: MediaSource(type: .photoLibrary, identifier: "test-photo")
        )
    }

    private func createTestPhotoAssetWithEXIF() -> MediaAsset {
        let imageData = createImageData(size: CGSize(width: 2000, height: 1500))

        return MediaAsset(
            type: .photo,
            data: imageData,
            metadata: MediaMetadata(
                fileName: "test-exif.jpg",
                fileSize: Int64(imageData.count),
                mimeType: "image/jpeg",
                dimensions: MediaDimensions(width: 2000, height: 1500),
                exifData: EXIFData(
                    camera: "iPhone 15 Pro",
                    lens: "Main Camera",
                    captureDate: Date(),
                    orientation: .up,
                    cameraSettings: CameraSettings(
                        iso: 100,
                        shutterSpeed: "1/125",
                        aperture: 1.8,
                        focalLength: 24.0
                    )
                ),
                securityInfo: SecurityInfo(isSafe: true)
            ),
            processingState: .pending,
            sourceInfo: MediaSource(type: .photoLibrary, identifier: "test-photo-exif")
        )
    }

    private func createImageData(size: CGSize) -> Data {
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }

        // Draw a gradient
        guard let context = UIGraphicsGetCurrentContext() else {
            XCTFail("Failed to get current graphics context")
            return Data()
        }

        let colors = [UIColor.blue.cgColor, UIColor.purple.cgColor]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil) else {
            XCTFail("Failed to create gradient for test image")
            return Data()
        }

        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])

        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            XCTFail("Failed to get image from current graphics context")
            return Data()
        }

        guard let jpegData = image.jpegData(compressionQuality: 0.9) else {
            XCTFail("Failed to convert image to JPEG data")
            return Data()
        }

        return jpegData
    }
}
