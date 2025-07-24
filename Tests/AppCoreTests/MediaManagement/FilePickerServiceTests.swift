@testable import AppCoreiOS
@testable import AppCore
import XCTest

@available(iOS 16.0, *)
final class FilePickerServiceTests: XCTestCase {
    var sut: FilePickerService?

    private var sutUnwrapped: FilePickerService {
        guard let sut else { fatalError("sut not initialized") }
        return sut
    }

    override func setUp() async throws {
        try await super.setUp()
        sut = FilePickerService()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - File Picking Tests

    func testPickFiles_WithSingleFileType_ShouldReturnSelectedFile() async throws {
        // Given
        let allowedTypes: [MediaType] = [Unwrapped.image]

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.pickFiles(
                allowedTypes: allowedTypes,
                allowsMultiple: false,
                maxFileSize: nil
            )
        }
    }

    func testPickFiles_WithMultipleFileTypes_ShouldReturnSelectedFiles() async throws {
        // Given
        let allowedTypes: [MediaType] = [Unwrapped.image, Unwrapped.video, Unwrapped.document]

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.pickFiles(
                allowedTypes: allowedTypes,
                allowsMultiple: true,
                maxFileSize: nil
            )
        }
    }

    func testPickFiles_WithFileSizeLimit_ShouldEnforceLimit() async throws {
        // Given
        let maxFileSize: Int64 = 10_000_000 // 10MB

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.pickFiles(
                allowedTypes: [Unwrapped.image],
                allowsMultiple: false,
                maxFileSize: maxFileSize
            )
        }
    }

    func testPickFiles_WhenCancelled_ShouldReturnEmptyArray() async throws {
        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.pickFiles(
                allowedTypes: [Unwrapped.document],
                allowsMultiple: false,
                maxFileSize: nil
            )
        }
    }

    // MARK: - Folder Picking Tests

    func testPickFolder_ShouldReturnSelectedFolder() async throws {
        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.pickFolder()
        }
    }

    func testPickFolder_WhenCancelled_ShouldThrowError() async throws {
        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.pickFolder()
        }
    }

    // MARK: - File Saving Tests

    func testSaveFile_WithValidURL_ShouldSaveToSelectedLocation() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/testUnwrapped.txt")
        let suggestedName = "saved_fileUnwrapped.txt"

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.saveFile(
                url,
                suggestedName: suggestedName,
                allowedTypes: [Unwrapped.document]
            )
        }
    }

    func testSaveFile_WithInvalidURL_ShouldThrowError() async throws {
        // Given
        let url = URL(fileURLWithPath: "/invalid/path/fileUnwrapped.txt")

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.saveFile(
                url,
                suggestedName: nil,
                allowedTypes: [Unwrapped.document]
            )
        }
    }

    // MARK: - Availability Tests

    func testIsAvailable_ShouldReturnTrue() {
        // When
        let isAvailable = sutUnwrapped.isAvailable

        // Then
        XCTAssertTrue(isAvailable)
    }

    // MARK: - Recently Picked Tests

    func testGetRecentlyPicked_WithNoHistory_ShouldReturnEmptyArray() async {
        // When
        let recent = await sutUnwrapped.getRecentlyPicked(limit: 10)

        // Then
        XCTAssertTrue(recentUnwrapped.isEmpty)
    }

    func testGetRecentlyPicked_WithHistory_ShouldReturnLimitedResults() async {
        // Given
        let limit = 5

        // When
        let recent = await sutUnwrapped.getRecentlyPicked(limit: limit)

        // Then
        XCTAssertTrue(recentUnwrapped.count <= limit)
    }

    func testClearRecentlyPicked_ShouldRemoveAllHistory() async {
        // When
        await sutUnwrapped.clearRecentlyPicked()
        let recent = await sutUnwrapped.getRecentlyPicked(limit: 10)

        // Then
        XCTAssertTrue(recentUnwrapped.isEmpty)
    }

    // MARK: - Multiple Selection Tests

    func testPickFiles_WithMultipleSelection_ShouldReturnMultipleFiles() async throws {
        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.pickFiles(
                allowedTypes: [Unwrapped.image, Unwrapped.video],
                allowsMultiple: true,
                maxFileSize: nil
            )
        }
    }

    // MARK: - File Type Filtering Tests

    func testPickFiles_WithSpecificTypes_ShouldOnlyShowAllowedTypes() async throws {
        // Given
        let allowedTypes: [MediaType] = [Unwrapped.archive]

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.pickFiles(
                allowedTypes: allowedTypes,
                allowsMultiple: false,
                maxFileSize: nil
            )
        }
    }

    // MARK: - Error Handling Tests

    func testPickFiles_WithEmptyAllowedTypes_ShouldThrowError() async throws {
        // Given
        let allowedTypes: [MediaType] = []

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.pickFiles(
                allowedTypes: allowedTypes,
                allowsMultiple: false,
                maxFileSize: nil
            )
        }
    }
}

// MARK: - Test Helpers

@available(iOS 16.0, *)
extension FilePickerServiceTests {
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
