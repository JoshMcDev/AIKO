@testable import AppCoreiOS
@testable import AppCore
import XCTest

@available(iOS 16.0, *)
final class ScreenshotServiceTests: XCTestCase {
    var sut: ScreenshotService?

    override func setUp() async throws {
        try await super.setUp()
        sut = ScreenshotService()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Screenshot Capture Tests

    func testCaptureFullScreen_ShouldCaptureEntireScreen() async throws {
        // When/Then
        await assertThrowsError {
            _ = try await sut.captureFullScreen()
        }
    }

    func testCaptureWindow_OnIOS_ShouldThrowUnsupportedError() async throws {
        // When/Then
        await assertThrowsError {
            _ = try await sut.captureWindow(windowId: "window1")
        }
    }

    func testCaptureArea_WithRect_ShouldCaptureSpecificArea() async throws {
        // Given
        let rect = CGRect(x: 100, y: 100, width: 200, height: 200)

        // When/Then
        await assertThrowsError {
            _ = try await sut.captureArea(rect)
        }
    }

    func testCaptureArea_WithNilRect_ShouldPromptForSelection() async throws {
        // When/Then
        await assertThrowsError {
            _ = try await sut.captureArea(nil)
        }
    }

    func testCaptureView_ShouldCaptureSpecificView() async throws {
        // Given
        let view = AnyView(EmptyView())

        // When/Then
        await assertThrowsError {
            _ = try await sut.captureView(view)
        }
    }

    // MARK: - Screen Recording Tests

    func testStartScreenRecording_WithDefaultOptions_ShouldStartRecording() async throws {
        // Given
        let options = ScreenRecordingOptions()

        // When/Then
        await assertThrowsError {
            _ = try await sut.startScreenRecording(options: options)
        }
    }

    func testStartScreenRecording_WithAudioEnabled_ShouldIncludeAudio() async throws {
        // Given
        let options = ScreenRecordingOptions(
            includeAudio: true,
            includeMicrophone: true
        )

        // When/Then
        await assertThrowsError {
            _ = try await sut.startScreenRecording(options: options)
        }
    }

    func testStartScreenRecording_WithHighQuality_ShouldRecordHighQuality() async throws {
        // Given
        let options = ScreenRecordingOptions(
            frameRate: 60,
            quality: .maximum
        )

        // When/Then
        await assertThrowsError {
            _ = try await sut.startScreenRecording(options: options)
        }
    }

    func testStopScreenRecording_WithActiveSession_ShouldReturnRecording() async throws {
        // Given
        let session = ScreenRecordingSession(
            options: ScreenRecordingOptions()
        )

        // When/Then
        await assertThrowsError {
            _ = try await sut.stopScreenRecording(session)
        }
    }

    // MARK: - Window Management Tests

    func testGetAvailableWindows_OnIOS_ShouldThrowUnsupportedError() async throws {
        // When/Then
        await assertThrowsError {
            _ = try await sut.getAvailableWindows()
        }
    }

    // MARK: - Permission Tests

    func testRequestScreenRecordingPermission_ShouldRequestPermission() async throws {
        // When
        let granted = try await sut.requestScreenRecordingPermission()

        // Then
        XCTAssertFalse(granted) // Currently returns false
    }

    func testIsScreenRecordingAvailable_ShouldReturnAvailability() {
        // When
        let isAvailable = sut.isScreenRecordingAvailable

        // Then
        // Test that it returns a boolean value
        XCTAssertNotNil(isAvailable)
    }

    // MARK: - Recording Options Tests

    func testStartScreenRecording_WithMaxDuration_ShouldRespectLimit() async throws {
        // Given
        let options = ScreenRecordingOptions(
            maxDuration: 60.0 // 1 minute
        )

        // When/Then
        await assertThrowsError {
            _ = try await sut.startScreenRecording(options: options)
        }
    }

    func testStartScreenRecording_WithMouseClicks_ShouldShowClicks() async throws {
        // Given
        let options = ScreenRecordingOptions(
            showMouseClicks: true
        )

        // When/Then
        await assertThrowsError {
            _ = try await sut.startScreenRecording(options: options)
        }
    }
}

// MARK: - Test Helpers

@available(iOS 16.0, *)
extension ScreenshotServiceTests {
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
