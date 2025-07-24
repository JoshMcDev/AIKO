@testable import AppCore
import Foundation
import XCTest

final class ValidationResultTests: XCTestCase {
    func testValidationResultSuccess() {
        // Given
        let result = ValidationResult.success

        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.warnings.count, 0)
    }

    func testValidationResultFailure() {
        // Given
        let error = MediaError.invalidFileType("exe")
        let result = ValidationResult.failure(error: error)

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.error)
        XCTAssertEqual(result.error, error)
    }

    func testValidationResultWarnings() {
        // Given
        let warnings = [
            ValidationWarning(type: .fileSizeLarge, message: "File size is large"),
            ValidationWarning(type: .metadataIncomplete, message: "Missing EXIF data"),
        ]
        let result = ValidationResult.successWithWarnings(warnings)

        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.warnings.count, 2)
        XCTAssertEqual(result.warnings[0].type, .fileSizeLarge)
        XCTAssertEqual(result.warnings[1].type, .metadataIncomplete)
    }

    func testValidationWarningTypes() {
        // Test all warning types
        let types: [ValidationWarning.WarningType] = [
            .fileSizeLarge,
            .metadataIncomplete,
            .qualityLow,
            .formatDeprecated,
            .securityConcern,
        ]

        for type in types {
            let warning = ValidationWarning(type: type, message: "Test")
            XCTAssertEqual(warning.type, type)
            XCTAssertEqual(warning.message, "Test")
        }
    }

    func testFileValidationRules() {
        // Given
        let rules = FileValidationRules(
            maxFileSize: 10 * 1024 * 1024, // 10MB
            allowedTypes: [.photo, .document],
            requireMetadata: true,
            requireSecurityScan: true
        )

        // Then
        XCTAssertEqual(rules.maxFileSize, 10 * 1024 * 1024)
        XCTAssertEqual(rules.allowedTypes, [.photo, .document])
        XCTAssertTrue(rules.requireMetadata)
        XCTAssertTrue(rules.requireSecurityScan)
    }

    func testDefaultFileValidationRules() {
        // Given
        let rules = FileValidationRules.default

        // Then
        XCTAssertEqual(rules.maxFileSize, 100 * 1024 * 1024) // 100MB
        XCTAssertEqual(rules.allowedTypes, MediaType.allCases)
        XCTAssertFalse(rules.requireMetadata)
        XCTAssertTrue(rules.requireSecurityScan)
    }

    func testPhotoValidationRules() {
        // Given
        let rules = FileValidationRules.photoDefaults

        // Then
        XCTAssertEqual(rules.maxFileSize, 50 * 1024 * 1024) // 50MB
        XCTAssertEqual(rules.allowedTypes, [.photo])
        XCTAssertTrue(rules.requireMetadata)
        XCTAssertTrue(rules.requireSecurityScan)
    }

    func testDocumentValidationRules() {
        // Given
        let rules = FileValidationRules.documentDefaults

        // Then
        XCTAssertEqual(rules.maxFileSize, 20 * 1024 * 1024) // 20MB
        XCTAssertEqual(rules.allowedTypes, [.document, .pdf])
        XCTAssertFalse(rules.requireMetadata)
        XCTAssertTrue(rules.requireSecurityScan)
    }
}
