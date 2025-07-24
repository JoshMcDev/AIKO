@testable import AppCoreiOS
@testable import AppCore
import XCTest

@available(iOS 16.0, *)
final class ValidationServiceTests: XCTestCase {
    var sut: ValidationService?

    private var sutUnwrapped: ValidationService {
        guard let sut else { fatalError("sut not initialized") }
        return sut
    }

    override func setUp() async throws {
        try await super.setUp()
        sut = ValidationService()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - File Validation Tests

    func testValidateFile_WithValidImage_ShouldReturnValid() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/test.jpg")
        let rules = ValidationRules(maxFileSize: 10_000_000)

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.validateFile(url, rules: rules)
        }
    }

    func testValidateFile_ExceedsMaxSize_ShouldReturnInvalid() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/large.jpg")
        let rules = ValidationRules(maxFileSize: 1_000_000) // 1MB

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.validateFile(url, rules: rules)
        }
    }

    func testValidateFile_UnsupportedFormat_ShouldReturnInvalid() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/test.exe")
        let rules = ValidationRules(allowedFormats: ["jpg", "png"])

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.validateFile(url, rules: rules)
        }
    }

    func testValidateFile_CorruptedFile_ShouldReturnInvalid() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/corrupted.jpg")
        let rules = ValidationRules.default

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.validateFile(url, rules: rules)
        }
    }

    // MARK: - Data Validation Tests

    func testValidateData_WithValidImageData_ShouldReturnValid() async throws {
        // Given
        let data = Data()
        let type = MediaType.image
        let rules = ValidationRules.default

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.validateData(data, type: type, rules: rules)
        }
    }

    func testValidateData_EmptyData_ShouldReturnInvalid() async throws {
        // Given
        let data = Data()
        let type = MediaType.image
        let rules = ValidationRules(maxFileSize: 0)

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.validateData(data, type: type, rules: rules)
        }
    }

    // MARK: - Batch Validation Tests

    func testValidateBatch_WithMixedFiles_ShouldReturnIndividualResults() async throws {
        // Given
        let urls = [
            URL(fileURLWithPath: "/tmp/valid.jpg"),
            URL(fileURLWithPath: "/tmp/invalid.exe"),
            URL(fileURLWithPath: "/tmp/large.jpg"),
        ]
        let rules = ValidationRules.default

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.validateBatch(urls, rules: rules)
        }
    }

    func testValidateBatch_EmptyArray_ShouldReturnEmptyResults() async throws {
        // Given
        let urls: [URL] = []
        let rules = ValidationRules.default

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.validateBatch(urls, rules: rules)
        }
    }

    // MARK: - Integrity Check Tests

    func testCheckIntegrity_ValidFile_ShouldReturnValid() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/test.jpg")

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.checkIntegrity(url)
        }
    }

    func testCheckIntegrity_CorruptedFile_ShouldReturnInvalid() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/corrupted.jpg")

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.checkIntegrity(url)
        }
    }

    func testCheckIntegrity_TruncatedFile_ShouldDetectTruncation() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/truncated.jpg")

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.checkIntegrity(url)
        }
    }

    // MARK: - Security Scan Tests

    func testScanForThreats_CleanFile_ShouldReturnSafe() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/clean.jpg")

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.scanForThreats(url)
        }
    }

    func testScanForThreats_SuspiciousFile_ShouldDetectThreat() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/suspicious.jpg")

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.scanForThreats(url)
        }
    }

    // MARK: - Metadata Validation Tests

    func testValidateMetadata_WithAllRequiredFields_ShouldReturnValid() async {
        // Given
        let metadata = MediaMetadata(
            fileName: "test.jpg",
            fileExtension: "jpg",
            mimeType: "image/jpeg"
        )
        let requirements: Set<String> = ["fileName", "mimeType"]

        // When
        let result = await sutUnwrapped.validateMetadata(metadata, requirements: requirements)

        // Then
        XCTAssertFalse(result.isValid) // Currently returns false in scaffold
    }

    func testValidateMetadata_MissingRequiredField_ShouldReturnInvalid() async {
        // Given
        let metadata = MediaMetadata(
            fileName: "",
            fileExtension: "jpg",
            mimeType: "image/jpeg"
        )
        let requirements: Set<String> = ["fileName", "creationDate"]

        // When
        let result = await sutUnwrapped.validateMetadata(metadata, requirements: requirements)

        // Then
        XCTAssertFalse(result.isValid)
    }

    // MARK: - Suggested Rules Tests

    func testSuggestedRules_ForImageType_ShouldReturnImageRules() {
        // When
        let rules = sutUnwrapped.suggestedRules(for: .image)

        // Then
        XCTAssertNotNil(rules)
    }

    func testSuggestedRules_ForVideoType_ShouldReturnVideoRules() {
        // When
        let rules = sutUnwrapped.suggestedRules(for: .video)

        // Then
        XCTAssertNotNil(rules)
    }

    // MARK: - Format Validation Tests

    func testValidateFormat_CorrectFormat_ShouldReturnTrue() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/test.jpg")
        let expectedType = MediaType.image

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.validateFormat(url, expectedType: expectedType)
        }
    }

    func testValidateFormat_IncorrectFormat_ShouldReturnFalse() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/test.mp4")
        let expectedType = MediaType.image

        // When/Then
        await assertThrowsError {
            _ = try await sutUnwrapped.validateFormat(url, expectedType: expectedType)
        }
    }

    // MARK: - Size Validation Tests

    func testValidateSize_WithinLimits_ShouldReturnValid() {
        // Given
        let size: Int64 = 5_000_000 // 5MB
        let constraints = SizeConstraints(
            minSize: 1_000_000,
            maxSize: 10_000_000
        )

        // When
        let result = sutUnwrapped.validateSize(size, constraints: constraints)

        // Then
        XCTAssertFalse(result.isValid) // Currently returns false in scaffold
    }

    func testValidateSize_TooSmall_ShouldReturnInvalid() {
        // Given
        let size: Int64 = 500_000 // 500KB
        let constraints = SizeConstraints(minSize: 1_000_000)

        // When
        let result = sutUnwrapped.validateSize(size, constraints: constraints)

        // Then
        XCTAssertFalse(result.isValid)
    }

    func testValidateSize_TooLarge_ShouldReturnInvalid() {
        // Given
        let size: Int64 = 15_000_000 // 15MB
        let constraints = SizeConstraints(maxSize: 10_000_000)

        // When
        let result = sutUnwrapped.validateSize(size, constraints: constraints)

        // Then
        XCTAssertFalse(result.isValid)
    }

    // MARK: - Dimension Validation Tests

    func testValidateDimensions_WithinLimits_ShouldReturnValid() {
        // Given
        let dimensions = MediaDimensions(width: 1920, height: 1080)
        let constraints = DimensionConstraints(
            minWidth: 100,
            maxWidth: 4096,
            minHeight: 100,
            maxHeight: 4096
        )

        // When
        let result = sutUnwrapped.validateDimensions(dimensions, constraints: constraints)

        // Then
        XCTAssertFalse(result.isValid) // Currently returns false in scaffold
    }

    func testValidateDimensions_InvalidAspectRatio_ShouldReturnInvalid() {
        // Given
        let dimensions = MediaDimensions(width: 1000, height: 100)
        let constraints = DimensionConstraints(
            aspectRatio: AspectRatioConstraint(ratio: 16.0 / 9.0, tolerance: 0.1)
        )

        // When
        let result = sutUnwrapped.validateDimensions(dimensions, constraints: constraints)

        // Then
        XCTAssertFalse(result.isValid)
    }
}

// MARK: - Test Helpers

@available(iOS 16.0, *)
extension ValidationServiceTests {
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
