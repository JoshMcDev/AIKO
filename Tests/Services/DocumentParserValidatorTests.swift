@testable import AppCore
import UniformTypeIdentifiers
import XCTest

final class DocumentParserValidatorTests: XCTestCase {
    var validator: DocumentParserValidator?

    private var validatorUnwrapped: DocumentParserValidator {
        guard let validator else { fatalError("validator not initialized") }
        return validator
    }

    override func setUp() {
        super.setUp()
        validator = DocumentParserValidator()
    }

    override func tearDown() {
        validator = nil
        super.tearDown()
    }

    // MARK: - Document Validation Tests

    func testValidateDocument_EmptyData_ThrowsError() {
        // Given
        let emptyData = Data()
        let pdfType = UTType.pdf

        // When/Then
        XCTAssertThrowsError(try validatorUnwrapped.validateDocument(emptyData, type: pdfType)) { error in
            guard let validationError = error as? DocumentParserValidationError else {
                XCTFail("Expected DocumentParserValidationError")
                return
            }

            switch validationError {
            case .emptyDocument:
                // Expected
                break
            default:
                XCTFail("Expected emptyDocument error, got \(validationError)")
            }
        }
    }

    func testValidateDocument_TooLargeFile_ThrowsError() {
        // Given
        let largeData = Data(repeating: 0, count: 101 * 1024 * 1024) // 101 MB
        let pdfType = UTType.pdf

        // When/Then
        XCTAssertThrowsError(try validatorUnwrapped.validateDocument(largeData, type: pdfType)) { error in
            guard let validationError = error as? DocumentParserValidationError else {
                XCTFail("Expected DocumentParserValidationError")
                return
            }

            switch validationError {
            case .fileTooLarge:
                // Expected
                break
            default:
                XCTFail("Expected fileTooLarge error, got \(validationError)")
            }
        }
    }

    func testValidateDocument_UnsupportedType_ThrowsError() {
        // Given
        let data = Data("test".utf8)
        let unsupportedType = UTType(filenameExtension: "xyz") ?? .data

        // When/Then
        XCTAssertThrowsError(try validatorUnwrapped.validateDocument(data, type: unsupportedType)) { error in
            guard let validationError = error as? DocumentParserValidationError else {
                XCTFail("Expected DocumentParserValidationError")
                return
            }

            switch validationError {
            case .unsupportedDocumentType:
                // Expected
                break
            default:
                XCTFail("Expected unsupportedDocumentType error, got \(validationError)")
            }
        }
    }

    func testValidateDocument_InvalidPDFHeader_ThrowsError() {
        // Given
        let invalidPDFData = Data("Not a PDF".utf8)
        let pdfType = UTType.pdf

        // When/Then
        XCTAssertThrowsError(try validatorUnwrapped.validateDocument(invalidPDFData, type: pdfType)) { error in
            guard let validationError = error as? DocumentParserValidationError else {
                XCTFail("Expected DocumentParserValidationError")
                return
            }

            switch validationError {
            case .corruptedDocument:
                // Expected
                break
            default:
                XCTFail("Expected corruptedDocument error, got \(validationError)")
            }
        }
    }

    func testValidateDocument_ValidPDF_Succeeds() throws {
        // Given
        var data = Data()
        data.append(contentsOf: [0x25, 0x50, 0x44, 0x46]) // %PDF header
        data.append(Data("rest of PDF content".utf8))
        let pdfType = UTType.pdf

        // When/Then
        XCTAssertNoThrow(try validatorUnwrapped.validateDocument(data, type: pdfType))
    }

    // MARK: - Text Validation Tests

    func testValidateExtractedText_EmptyText_ThrowsError() {
        // Given
        let emptyText = ""

        // When/Then
        XCTAssertThrowsError(try validatorUnwrapped.validateExtractedText(emptyText)) { error in
            guard let validationError = error as? DocumentParserValidationError else {
                XCTFail("Expected DocumentParserValidationError")
                return
            }

            switch validationError {
            case .noTextExtracted:
                // Expected
                break
            default:
                XCTFail("Expected noTextExtracted error, got \(validationError)")
            }
        }
    }

    func testValidateExtractedText_TooShortText_ThrowsError() {
        // Given
        let shortText = "Hi"

        // When/Then
        XCTAssertThrowsError(try validatorUnwrapped.validateExtractedText(shortText)) { error in
            guard let validationError = error as? DocumentParserValidationError else {
                XCTFail("Expected DocumentParserValidationError")
                return
            }

            switch validationError {
            case .insufficientText:
                // Expected
                break
            default:
                XCTFail("Expected insufficientText error, got \(validationError)")
            }
        }
    }

    func testValidateExtractedText_NoMeaningfulContent_ThrowsError() {
        // Given
        let nonsenseText = "123 456 789 !@# $%^"

        // When/Then
        XCTAssertThrowsError(try validatorUnwrapped.validateExtractedText(nonsenseText)) { error in
            guard let validationError = error as? DocumentParserValidationError else {
                XCTFail("Expected DocumentParserValidationError")
                return
            }

            switch validationError {
            case .noMeaningfulContent:
                // Expected
                break
            default:
                XCTFail("Expected noMeaningfulContent error, got \(validationError)")
            }
        }
    }

    func testValidateExtractedText_ValidText_Succeeds() throws {
        // Given
        let validText = "This is a valid document with meaningful content and several words."

        // When/Then
        XCTAssertNoThrow(try validatorUnwrapped.validateExtractedText(validText))
    }

    // MARK: - Extracted Data Validation Tests

    func testValidateExtractedData_InvalidEmail_ThrowsError() {
        // Given
        let data = ExtractedData(vendorEmail: "not-an-email")

        // When/Then
        XCTAssertThrowsError(try validatorUnwrapped.validateExtractedData(data)) { error in
            guard let validationError = error as? DocumentParserValidationError else {
                XCTFail("Expected DocumentParserValidationError")
                return
            }

            switch validationError {
            case let .invalidField(field, _) where field == "Email":
                // Expected
                break
            default:
                XCTFail("Expected invalidField error for Email, got \(validationError)")
            }
        }
    }

    func testValidateExtractedData_InvalidUEI_ThrowsError() {
        // Given
        let data = ExtractedData(vendorUEI: "SHORT")

        // When/Then
        XCTAssertThrowsError(try validatorUnwrapped.validateExtractedData(data)) { error in
            guard let validationError = error as? DocumentParserValidationError else {
                XCTFail("Expected DocumentParserValidationError")
                return
            }

            switch validationError {
            case let .invalidField(field, _) where field == "UEI":
                // Expected
                break
            default:
                XCTFail("Expected invalidField error for UEI, got \(validationError)")
            }
        }
    }

    func testValidateExtractedData_InvalidCAGE_ThrowsError() {
        // Given
        let data = ExtractedData(vendorCAGE: "123456") // Too long

        // When/Then
        XCTAssertThrowsError(try validatorUnwrapped.validateExtractedData(data)) { error in
            guard let validationError = error as? DocumentParserValidationError else {
                XCTFail("Expected DocumentParserValidationError")
                return
            }

            switch validationError {
            case let .invalidField(field, _) where field == "CAGE":
                // Expected
                break
            default:
                XCTFail("Expected invalidField error for CAGE, got \(validationError)")
            }
        }
    }

    func testValidateExtractedData_NegativePrice_ThrowsError() {
        // Given
        let data = ExtractedData(totalPrice: -100.00)

        // When/Then
        XCTAssertThrowsError(try validatorUnwrapped.validateExtractedData(data)) { error in
            guard let validationError = error as? DocumentParserValidationError else {
                XCTFail("Expected DocumentParserValidationError")
                return
            }

            switch validationError {
            case let .invalidField(field, _) where field == "Price":
                // Expected
                break
            default:
                XCTFail("Expected invalidField error for Price, got \(validationError)")
            }
        }
    }

    func testValidateExtractedData_InvalidDateRange_ThrowsError() {
        // Given
        let quoteDate = Date()
        let validUntilDate = Date(timeIntervalSinceNow: -86400) // Yesterday
        let data = ExtractedData(quoteDate: quoteDate, validUntilDate: validUntilDate)

        // When/Then
        XCTAssertThrowsError(try validatorUnwrapped.validateExtractedData(data)) { error in
            guard let validationError = error as? DocumentParserValidationError else {
                XCTFail("Expected DocumentParserValidationError")
                return
            }

            switch validationError {
            case .invalidDateRange:
                // Expected
                break
            default:
                XCTFail("Expected invalidDateRange error, got \(validationError)")
            }
        }
    }

    func testValidateExtractedData_ValidData_Succeeds() throws {
        // Given
        let quoteDate = Date()
        let validUntilDate = Date(timeIntervalSinceNow: 30 * 86400) // 30 days from now

        let lineItems = [
            LineItem(description: "Test Item 1", quantity: 5, unitPrice: 10.00, totalPrice: 50.00),
            LineItem(description: "Test Item 2", quantity: 3, unitPrice: 20.00, totalPrice: 60.00),
        ]

        let data = ExtractedData(
            vendorName: "Test Vendor Inc.",
            vendorEmail: "vendor@example.com",
            vendorPhone: "+1 (555) 123-4567",
            vendorUEI: "ABC123DEF456",
            vendorCAGE: "12345",
            quoteDate: quoteDate,
            validUntilDate: validUntilDate,
            totalPrice: 110.00,
            lineItems: lineItems
        )

        // When/Then
        XCTAssertNoThrow(try validatorUnwrapped.validateExtractedData(data))
    }

    func testValidateExtractedData_EmptyLineItemDescription_ThrowsError() {
        // Given
        let lineItems = [
            LineItem(description: "", quantity: 5, unitPrice: 10.00, totalPrice: 50.00),
        ]

        let data = ExtractedData(lineItems: lineItems)

        // When/Then
        XCTAssertThrowsError(try validatorUnwrapped.validateExtractedData(data)) { error in
            guard let validationError = error as? DocumentParserValidationError else {
                XCTFail("Expected DocumentParserValidationError")
                return
            }

            switch validationError {
            case let .invalidField(field, _) where field.contains("Line Item"):
                // Expected
                break
            default:
                XCTFail("Expected invalidField error for Line Item, got \(validationError)")
            }
        }
    }

    func testValidateExtractedData_ZeroQuantityLineItem_ThrowsError() {
        // Given
        let lineItems = [
            LineItem(description: "Test Item", quantity: 0, unitPrice: 10.00, totalPrice: 0.00),
        ]

        let data = ExtractedData(lineItems: lineItems)

        // When/Then
        XCTAssertThrowsError(try validatorUnwrapped.validateExtractedData(data)) { error in
            guard let validationError = error as? DocumentParserValidationError else {
                XCTFail("Expected DocumentParserValidationError")
                return
            }

            switch validationError {
            case let .invalidField(field, _) where field.contains("Quantity"):
                // Expected
                break
            default:
                XCTFail("Expected invalidField error for Quantity, got \(validationError)")
            }
        }
    }
}
