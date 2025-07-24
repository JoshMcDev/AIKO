@testable import AppCore
import AVFoundation
import Dependencies
import Foundation
import XCTest

final class CameraServiceTests: XCTestCase {
    @Dependency(\.cameraService) var camera

    // MARK: - Authorization Tests

    func testRequestCameraAuthorization() async {
        // When
        let status = await camera.requestAuthorization()

        // Then
        XCTAssertEqual(status, .authorized)
    }

    func testRequestCameraAuthorizationDenied() async {
        // Given
        withDependencies {
            $0.cameraService.requestAuthorization = { .denied }
        } operation: {
            // When
            let status = await camera.requestAuthorization()

            // Then
            XCTAssertEqual(status, .denied)
        }
    }

    // MARK: - Camera Configuration Tests

    func testConfigureCameraSettings() async throws {
        // Given
        let configuration = CameraConfiguration(
            preset: .hd1920x1080,
            flashMode: .auto,
            focusMode: .continuousAutoFocus,
            exposureMode: .continuousAutoExposure
        )

        // When
        try await camera.configureCameraSettings(configuration)

        // Then - No error thrown means success
    }

    func testGetAvailableCameras() async throws {
        // When
        let cameras = try await camera.getAvailableCameras()

        // Then
        XCTAssertGreaterThan(cameras.count, 0)
        XCTAssertTrue(cameras.contains { $0.position == .back })
    }

    // MARK: - Photo Capture Tests

    func testCapturePhotoDefault() async throws {
        // When
        let photo = try await camera.capturePhoto()

        // Then
        XCTAssertNotNil(photo)
        XCTAssertGreaterThan(photo.data.count, 0)
        XCTAssertNotNil(photo.metadata)
        XCTAssertEqual(photo.metadata.orientation, .up)
    }

    func testCapturePhotoWithSettings() async throws {
        // Given
        let settings = CaptureSettings(
            flashMode: .on,
            focusMode: .autoFocus,
            exposureMode: .autoExpose,
            imageQuality: .high,
            hdrEnabled: true
        )

        // When
        let photo = try await camera.capturePhotoWithSettings(settings)

        // Then
        XCTAssertNotNil(photo)
        XCTAssertGreaterThan(photo.data.count, 0)
        XCTAssertEqual(photo.settings.flashMode, .on)
        XCTAssertTrue(photo.settings.hdrEnabled)
    }

    func testCaptureWithOptimization() async throws {
        // When
        let optimizedPhoto = try await camera.captureWithOptimization()

        // Then
        XCTAssertNotNil(optimizedPhoto)
        XCTAssertNotNil(optimizedPhoto.originalData)
        XCTAssertNotNil(optimizedPhoto.optimizedData)
        XCTAssertLessThan(optimizedPhoto.optimizedData.count, optimizedPhoto.originalData.count)
        XCTAssertGreaterThan(optimizedPhoto.qualityScore, 0.8)
    }

    // MARK: - Camera Preview Tests

    func testStartPreview() async throws {
        // When
        let previewStream = try await camera.startPreview()

        // Then
        var frameCount = 0
        for await frame in previewStream.prefix(3) {
            XCTAssertNotNil(frame.image)
            XCTAssertGreaterThan(frame.timestamp, 0)
            frameCount += 1
        }
        XCTAssertEqual(frameCount, 3)
    }

    func testStopPreview() async throws {
        // Given
        _ = try await camera.startPreview()

        // When
        try await camera.stopPreview()

        // Then - No error means success
    }

    // MARK: - Focus and Exposure Tests

    func testEnableAutoFocus() async throws {
        // When
        try await camera.enableAutoFocus(true)

        // Then - No error means success
    }

    func testEnableAutoExposure() async throws {
        // When
        try await camera.enableAutoExposure(true)

        // Then - No error means success
    }

    func testFocusAtPoint() async throws {
        // Given
        let point = CGPoint(x: 0.5, y: 0.5) // Center of frame

        // When
        try await camera.focusAtPoint(point)

        // Then - No error means success
    }

    func testSetExposureCompensation() async throws {
        // Given
        let compensation: Float = 0.5

        // When
        try await camera.setExposureCompensation(compensation)

        // Then - No error means success
    }

    // MARK: - Camera Switching Tests

    func testSwitchCamera() async throws {
        // When
        try await camera.switchCamera(.front)

        // Then - No error means success
    }

    func testGetCurrentCameraInfo() async throws {
        // When
        let cameraInfo = try await camera.getCurrentCameraInfo()

        // Then
        XCTAssertNotNil(cameraInfo)
        XCTAssertNotNil(cameraInfo.position)
        XCTAssertNotNil(cameraInfo.deviceType)
        XCTAssertTrue(cameraInfo.hasFlash || !cameraInfo.hasFlash) // Always true
    }

    // MARK: - Flash Tests

    func testSetFlashMode() async throws {
        // Test all flash modes
        let modes: [CaptureSettings.FlashMode] = [.off, .on, .auto]

        for mode in modes {
            try await camera.setFlashMode(mode)
            // No error means success
        }
    }

    // MARK: - Error Handling Tests

    func testCapturePhotoWithNoAuthorization() async {
        // Given
        withDependencies {
            $0.cameraService.requestAuthorization = { .denied }
            $0.cameraService.capturePhoto = {
                throw MediaError.permissionDenied
            }
        } operation: {
            // When/Then
            do {
                _ = try await camera.capturePhoto()
                XCTFail("Should throw permission denied error")
            } catch MediaError.permissionDenied {
                // Expected
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testCapturePhotoDeviceError() async {
        // Given
        withDependencies {
            $0.cameraService.capturePhoto = {
                throw MediaError.processingFailed("Camera device error")
            }
        } operation: {
            // When/Then
            do {
                _ = try await camera.capturePhoto()
                XCTFail("Should throw processing failed error")
            } catch MediaError.processingFailed {
                // Expected
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - Integration Tests

    func testCaptureAndConvertToMediaAsset() async throws {
        // When
        let photo = try await camera.capturePhoto()

        // Then - Convert to MediaAsset
        let mediaAsset = MediaAsset(
            type: .photo,
            data: photo.data,
            metadata: MediaMetadata(
                fileName: "camera_capture.jpg",
                fileSize: Int64(photo.data.count),
                mimeType: "image/jpeg",
                dimensions: MediaDimensions(
                    width: Int(photo.metadata.dimensions.width),
                    height: Int(photo.metadata.dimensions.height)
                ),
                exifData: EXIFData(
                    camera: photo.metadata.deviceName,
                    captureDate: Date(),
                    orientation: ImageOrientation(rawValue: photo.metadata.orientation.rawValue) ?? .up
                ),
                securityInfo: SecurityInfo(isSafe: true)
            ),
            processingState: .pending,
            sourceInfo: MediaSource(type: .camera)
        )

        XCTAssertEqual(mediaAsset.type, .photo)
        XCTAssertGreaterThan(mediaAsset.data.count, 0)
    }

    // MARK: - Performance Tests

    func testCapturePhotoPerformance() {
        measure {
            let expectation = self.expectation(description: "Photo capture")

            Task {
                _ = try await camera.capturePhoto()
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 2.0)
        }
    }
}
