@testable import AppCore
import Dependencies
import Foundation
import UIKit
import XCTest

final class ScreenshotServiceTests: XCTestCase {
    @Dependency(\.screenshotService) var screenshot

    // MARK: - Screenshot Capture Tests

    func testCaptureScreen() async throws {
        // When
        let asset = try await screenshot.captureScreen()

        // Then
        XCTAssertNotNil(asset)
        XCTAssertEqual(asset.type, .screenshot)
        XCTAssertGreaterThan(asset.data.count, 0)
        XCTAssertNotNil(asset.metadata.dimensions)
    }

    func testCaptureWindow() async throws {
        // Given
        let windowName = "Test Window"

        // When
        let asset = try await screenshot.captureWindow(windowName)

        // Then
        XCTAssertNotNil(asset)
        XCTAssertEqual(asset.type, .screenshot)
        XCTAssertGreaterThan(asset.data.count, 0)
    }

    // MARK: - Annotation Tests

    func testStartAnnotation() async throws {
        // Given
        let asset = createTestScreenshotAsset()

        // When
        let session = try await screenshot.startAnnotation(asset)

        // Then
        XCTAssertNotNil(session)
        XCTAssertEqual(session.originalAsset.id, asset.id)
        XCTAssertEqual(session.annotations.count, 0)
        XCTAssertEqual(session.currentTool, .pen)
    }

    func testAddAnnotations() async throws {
        // Given
        let asset = createTestScreenshotAsset()
        var session = try await screenshot.startAnnotation(asset)

        // When - Add multiple annotations
        let penAnnotation = Annotation(
            id: UUID(),
            tool: .pen,
            color: .red,
            strokeWidth: 2.0,
            path: createTestPath()
        )
        session.annotations.append(penAnnotation)

        let textAnnotation = Annotation(
            id: UUID(),
            tool: .text,
            color: .black,
            text: "Important note",
            position: CGPoint(x: 100, y: 100),
            fontSize: 16
        )
        session.annotations.append(textAnnotation)

        let arrowAnnotation = Annotation(
            id: UUID(),
            tool: .arrow,
            color: .blue,
            strokeWidth: 3.0,
            startPoint: CGPoint(x: 50, y: 50),
            endPoint: CGPoint(x: 150, y: 150)
        )
        session.annotations.append(arrowAnnotation)

        // Then
        XCTAssertEqual(session.annotations.count, 3)
        XCTAssertEqual(session.annotations[0].tool, .pen)
        XCTAssertEqual(session.annotations[1].tool, .text)
        XCTAssertEqual(session.annotations[2].tool, .arrow)
    }

    func testFinishAnnotation() async throws {
        // Given
        let asset = createTestScreenshotAsset()
        var session = try await screenshot.startAnnotation(asset)

        // Add some annotations
        session.annotations.append(Annotation(
            id: UUID(),
            tool: .pen,
            color: .red,
            strokeWidth: 2.0,
            path: createTestPath()
        ))

        // When
        let annotatedAsset = try await screenshot.finishAnnotation(session)

        // Then
        XCTAssertNotNil(annotatedAsset)
        XCTAssertEqual(annotatedAsset.type, .screenshot)
        XCTAssertNotEqual(annotatedAsset.data, asset.data) // Data should be different after annotation
        XCTAssertGreaterThan(annotatedAsset.data.count, 0)
    }

    // MARK: - Annotation Tool Tests

    func testAllAnnotationTools() {
        // Test all annotation tools are available
        let tools = AnnotationTool.allCases

        XCTAssertEqual(tools.count, 6)
        XCTAssertTrue(tools.contains(.pen))
        XCTAssertTrue(tools.contains(.highlighter))
        XCTAssertTrue(tools.contains(.text))
        XCTAssertTrue(tools.contains(.arrow))
        XCTAssertTrue(tools.contains(.rectangle))
        XCTAssertTrue(tools.contains(.eraser))
    }

    func testAnnotationColors() {
        // Test common annotation colors
        let colors: [UIColor] = [.black, .red, .blue, .green, .yellow, .orange]

        for color in colors {
            let annotation = Annotation(
                id: UUID(),
                tool: .pen,
                color: color,
                strokeWidth: 2.0,
                path: UIBezierPath()
            )
            XCTAssertEqual(annotation.color, color)
        }
    }

    // MARK: - Screenshot Settings Tests

    func testCaptureWithSettings() async throws {
        // Given
        let settings = ScreenshotSettings(
            includeStatusBar: false,
            includeNavigationBar: true,
            scale: 2.0
        )

        // When
        let asset = try await screenshot.captureWithSettings(settings)

        // Then
        XCTAssertNotNil(asset)
        XCTAssertEqual(asset.type, .screenshot)
    }

    // MARK: - Error Handling Tests

    func testCaptureScreenFailure() async {
        // Given
        withDependencies {
            $0.screenshotService.captureScreen = {
                throw MediaError.processingFailed("Screenshot capture failed")
            }
        } operation: {
            // When/Then
            do {
                _ = try await screenshot.captureScreen()
                XCTFail("Should throw error")
            } catch MediaError.processingFailed {
                // Expected
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - Performance Tests

    func testScreenshotCapturePerformance() {
        measure {
            let expectation = self.expectation(description: "Screenshot capture")

            Task {
                _ = try await screenshot.captureScreen()
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 2.0)
        }
    }

    // MARK: - Helper Methods

    private func createTestScreenshotAsset() -> MediaAsset {
        let imageData = createTestImageData()

        return MediaAsset(
            id: UUID(),
            type: .screenshot,
            data: imageData,
            metadata: MediaMetadata(
                fileName: "screenshot.png",
                fileSize: Int64(imageData.count),
                mimeType: "image/png",
                dimensions: MediaDimensions(width: 1170, height: 2532),
                securityInfo: SecurityInfo(isSafe: true)
            ),
            processingState: .pending,
            sourceInfo: MediaSource(type: .screenshot)
        )
    }

    private func createTestImageData() -> Data {
        UIGraphicsBeginImageContext(CGSize(width: 1170, height: 2532))
        defer { UIGraphicsEndImageContext() }

        // Draw test pattern
        UIColor.systemBackground.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 1170, height: 2532))

        UIColor.systemBlue.setFill()
        UIRectFill(CGRect(x: 100, y: 100, width: 200, height: 200))

        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            XCTFail("Failed to create test image from graphics context")
            return Data()
        }

        guard let pngData = image.pngData() else {
            XCTFail("Failed to convert test image to PNG data")
            return Data()
        }

        return pngData
    }

    private func createTestPath() -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 10, y: 10))
        path.addLine(to: CGPoint(x: 100, y: 100))
        path.addCurve(to: CGPoint(x: 200, y: 50),
                      controlPoint1: CGPoint(x: 150, y: 120),
                      controlPoint2: CGPoint(x: 180, y: 80))
        return path
    }
}
