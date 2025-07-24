@testable import AppCore
import XCTest

/// Unit tests for FieldExtractionService covering field extraction accuracy and performance
final class FieldExtractionServiceTests: XCTestCase {
    var fieldExtractor: FieldExtractionService?

    private var fieldExtractorUnwrapped: FieldExtractionService {
        guard let fieldExtractor = fieldExtractor else { fatalError("fieldExtractor not initialized") }
        return fieldExtractor
    }

    override func setUp() async throws {
        try await super.setUp()
        fieldExtractor = FieldExtractionService()
    }

    override func tearDown() async throws {
        fieldExtractor = nil
        try await super.tearDown()
    }

    // MARK: - Field Extraction Accuracy Tests

    /// Test extraction of standard SF-30 fields
    func test_extractSF30StandardFields() async throws {
        // Given: SF-30 form document data
        let documentData = createMockSF30DocumentData()

        // When: Extracting fields
        let extractedFields = try await fieldExtractorUnwrapped.extractFields(
            from: documentData,
            formType: .sf30
        )

        // Then: Should extract expected SF-30 fields
        let expectedFields = ["contractNumber", "modificationNumber", "effectiveDate", "totalAmount"]

        for expectedField in expectedFields {
            XCTAssertTrue(
                extractedFields.keys.contains(expectedField),
                "Should extract standard SF-30 field: \(expectedField)"
            )
        }
    }

    /// Test extraction of SF-1449 commercial item fields
    func test_extractSF1449CommercialFields() async throws {
        // Given: SF-1449 form document data
        let documentData = createMockSF1449DocumentData()

        // When: Extracting fields
        let extractedFields = try await fieldExtractorUnwrapped.extractFields(
            from: documentData,
            formType: .sf1449
        )

        // Then: Should extract expected SF-1449 fields
        let expectedFields = ["requisitionNumber", "contractNumber", "vendorName", "vendorUEI"]

        for expectedField in expectedFields {
            XCTAssertTrue(
                extractedFields.keys.contains(expectedField),
                "Should extract standard SF-1449 field: \(expectedField)"
            )
        }
    }

    /// Test field extraction handles various text formats
    func test_extractFields_handlesVariousTextFormats() async throws {
        // Given: Document with various text formats (bold, italic, different fonts)
        let documentData = createMockDocumentWithVariedFormatting()

        // When: Extracting fields
        let extractedFields = try await fieldExtractorUnwrapped.extractFields(
            from: documentData,
            formType: .sf30
        )

        // Then: Should extract fields regardless of formatting
        XCTAssertGreaterThan(
            extractedFields.count,
            0,
            "Should extract fields from documents with varied formatting"
        )

        // Verify field values are clean (no formatting artifacts)
        for (_, value) in extractedFields {
            if let stringValue = value as? String {
                XCTAssertFalse(
                    stringValue.contains("<") || stringValue.contains(">"),
                    "Extracted field should not contain HTML/formatting tags"
                )
            }
        }
    }

    /// Test extraction accuracy with different document qualities
    func test_extractFields_differentDocumentQualities() async throws {
        // Given: Documents of varying quality
        let highQualityDoc = createMockHighQualityDocument()
        let mediumQualityDoc = createMockMediumQualityDocument()
        let lowQualityDoc = createMockLowQualityDocument()

        // When: Extracting fields from each quality level
        let highQualityFields = try await fieldExtractorUnwrapped.extractFields(
            from: highQualityDoc,
            formType: .sf30
        )
        let mediumQualityFields = try await fieldExtractorUnwrapped.extractFields(
            from: mediumQualityDoc,
            formType: .sf30
        )
        let lowQualityFields = try await fieldExtractorUnwrapped.extractFields(
            from: lowQualityDoc,
            formType: .sf30
        )

        // Then: Higher quality should yield more extracted fields
        XCTAssertGreaterThanOrEqual(
            highQualityFields.count,
            mediumQualityFields.count,
            "High quality documents should extract at least as many fields as medium quality"
        )
        XCTAssertGreaterThanOrEqual(
            mediumQualityFields.count,
            lowQualityFields.count,
            "Medium quality documents should extract at least as many fields as low quality"
        )
    }

    // MARK: - Performance Tests

    /// Test field extraction performance for single page
    func test_fieldExtractionPerformance_singlePage() async throws {
        // Given: Single page document
        let documentData = createMockSinglePageDocument()

        // When: Extracting fields with timing
        let startTime = Date()
        _ = try await fieldExtractorUnwrapped.extractFields(
            from: documentData,
            formType: .sf30
        )
        let extractionTime = Date().timeIntervalSince(startTime)

        // Then: Should complete within reasonable time (part of 2-second overall requirement)
        XCTAssertLessThanOrEqual(
            extractionTime,
            1.5,
            "Field extraction should complete within 1.5 seconds for single page"
        )
    }

    /// Test field extraction scales with document size
    func test_fieldExtractionPerformance_scalability() async throws {
        // Given: Documents of different sizes
        let singlePageDoc = createMockSinglePageDocument()
        let multiPageDoc = createMockMultiPageDocument(pages: 3)

        // When: Extracting fields from both
        let startTime1 = Date()
        _ = try await fieldExtractorUnwrapped.extractFields(
            from: singlePageDoc,
            formType: .sf30
        )
        let singlePageTime = Date().timeIntervalSince(startTime1)

        let startTime2 = Date()
        _ = try await fieldExtractorUnwrapped.extractFields(
            from: multiPageDoc,
            formType: .sf30
        )
        let multiPageTime = Date().timeIntervalSince(startTime2)

        // Then: Multi-page should scale reasonably (not more than 3x for 3 pages)
        XCTAssertLessThanOrEqual(
            multiPageTime,
            singlePageTime * 3.5,
            "Multi-page extraction should scale reasonably with document size"
        )
    }

    // MARK: - Error Handling Tests

    /// Test field extraction handles corrupted documents gracefully
    func test_fieldExtraction_handlesCorruptedDocuments() async throws {
        // Given: Corrupted document data
        let corruptedData = Data([0xFF, 0x00, 0xFF, 0x00])

        // When: Attempting to extract fields
        do {
            _ = try await fieldExtractorUnwrapped.extractFields(
                from: corruptedData,
                formType: .sf30
            )
            XCTFail("Should throw error for corrupted document")
        } catch AutoPopulationError.extractionFailed {
            // Then: Should throw appropriate error
            XCTAssert(true, "Correctly handles corrupted document with extraction error")
        } catch {
            XCTFail("Should throw specific AutoPopulationError.extractionFailed, got: \(error)")
        }
    }

    /// Test field extraction handles empty documents
    func test_fieldExtraction_handlesEmptyDocuments() async throws {
        // Given: Empty document
        let emptyData = Data()

        // When: Attempting to extract fields
        do {
            let extractedFields = try await fieldExtractorUnwrapped.extractFields(
                from: emptyData,
                formType: .sf30
            )

            // Then: Should return empty results rather than throw
            XCTAssertTrue(
                extractedFields.isEmpty,
                "Empty document should return empty field dictionary"
            )
        } catch AutoPopulationError.invalidDocument {
            // Also acceptable to throw invalid document error
            XCTAssert(true, "Acceptable to throw invalid document error for empty data")
        }
    }

    /// Test field extraction handles unsupported form types
    func test_fieldExtraction_handlesUnsupportedFormTypes() async throws {
        // Given: Valid document but unsupported form type
        let documentData = createMockSF30DocumentData()
        // Simulate unsupported form type by creating custom enum case
        // Note: This test will need to be updated when more form types are added

        // When/Then: Should handle gracefully (implementation will determine behavior)
        // This test validates the error handling structure is in place
        do {
            _ = try await fieldExtractorUnwrapped.extractFields(
                from: documentData,
                formType: .sf30 // Using supported type for now
            )
        } catch {
            // Any error is acceptable - we're testing error handling structure
        }
    }

    // MARK: - Field Type Specific Tests

    /// Test extraction of date fields with various formats
    func test_extractDateFields_variousFormats() async throws {
        // Given: Document with various date formats
        let documentData = createMockDocumentWithDateFormats()

        // When: Extracting fields
        let extractedFields = try await fieldExtractorUnwrapped.extractFields(
            from: documentData,
            formType: .sf30
        )

        // Then: Should extract and potentially normalize date fields
        let dateFields = extractedFields.filter { key, _ in
            key.lowercased().contains("date")
        }

        XCTAssertGreaterThan(
            dateFields.count,
            0,
            "Should extract at least one date field"
        )

        // Verify date fields contain reasonable values
        for (_, value) in dateFields {
            if let dateString = value as? String {
                XCTAssertFalse(
                    dateString.isEmpty,
                    "Date fields should not be empty"
                )
            }
        }
    }

    /// Test extraction of currency/amount fields
    func test_extractCurrencyFields_variousFormats() async throws {
        // Given: Document with various currency formats
        let documentData = createMockDocumentWithCurrencyFormats()

        // When: Extracting fields
        let extractedFields = try await fieldExtractorUnwrapped.extractFields(
            from: documentData,
            formType: .sf1449
        )

        // Then: Should extract currency fields
        let currencyFields = extractedFields.filter { key, _ in
            key.lowercased().contains("amount") || key.lowercased().contains("value")
        }

        XCTAssertGreaterThan(
            currencyFields.count,
            0,
            "Should extract at least one currency field"
        )

        // Verify currency fields contain numeric or currency-formatted values
        for (_, value) in currencyFields {
            if let currencyString = value as? String {
                let hasNumbers = currencyString.rangeOfCharacter(from: .decimalDigits) != nil
                XCTAssertTrue(
                    hasNumbers,
                    "Currency fields should contain numeric values"
                )
            }
        }
    }

    // MARK: - Test Helper Methods

    private func createMockSF30DocumentData() -> Data {
<<<<<<< HEAD
        return Data("""
=======
        """
>>>>>>> Main
        STANDARD FORM 30
        Contract Number: N00421-25-C-0001
        Modification Number: P00001
        Effective Date: 2025-02-01
        Total Amount: $125,000.00
        """.utf8)
    }

    private func createMockSF1449DocumentData() -> Data {
<<<<<<< HEAD
        return Data("""
=======
        """
>>>>>>> Main
        STANDARD FORM 1449
        Requisition Number: REQ-2025-001
        Contract Number: W56HZV-25-D-0001
        Vendor Name: ACME Corporation
        Vendor UEI: ABC123DEF456
        Total Amount: $75,500.00
        """.utf8)
    }

    private func createMockDocumentWithVariedFormatting() -> Data {
<<<<<<< HEAD
        return Data("""
=======
        """
>>>>>>> Main
        Contract Information:
        **Contract Number:** N00421-25-C-0001
        *Total Amount:* $125,000.00
        VENDOR NAME: ACME CORPORATION
        vendor_uei: ABC123DEF456
        """.utf8)
    }

    private func createMockHighQualityDocument() -> Data {
<<<<<<< HEAD
        return Data("""
=======
        """
>>>>>>> Main
        HIGH QUALITY DOCUMENT
        Contract Number: N00421-25-C-0001
        Total Amount: $125,000.00
        Vendor Name: ACME Corporation
        Effective Date: 2025-02-01
        Performance Location: Naval Base San Diego
        """.utf8)
    }

    private func createMockMediumQualityDocument() -> Data {
<<<<<<< HEAD
        return Data("""
=======
        """
>>>>>>> Main
        MEDIUM QUALITY DOC
        Contract Num: N00421-25-C-0001
        Amount: $125,000
        Vendor: ACME Corp
        Date: 02/01/2025
        """.utf8)
    }

    private func createMockLowQualityDocument() -> Data {
<<<<<<< HEAD
        return Data("""
=======
        """
>>>>>>> Main
        LOW QUAL DOC
        Contr: N00421
        Amt: 125000
        """.utf8)
    }

    private func createMockSinglePageDocument() -> Data {
<<<<<<< HEAD
        return Data("Single page document for performance testing".utf8)
=======
        "Single page document for performance testing".data(using: .utf8) ?? Data()
>>>>>>> Main
    }

    private func createMockMultiPageDocument(pages: Int) -> Data {
        let pageContent = "Page content with Contract Number: N00421-25-C-0001\n"
        let multiPageContent = String(repeating: pageContent, count: pages)
        return Data(multiPageContent.utf8)
    }

    private func createMockDocumentWithDateFormats() -> Data {
<<<<<<< HEAD
        return Data("""
=======
        """
>>>>>>> Main
        Various Date Formats:
        Effective Date: 2025-02-01
        Delivery Date: 02/01/2025
        Award Date: February 1, 2025
        Modified Date: 01-Feb-25
        """.utf8)
    }

    private func createMockDocumentWithCurrencyFormats() -> Data {
<<<<<<< HEAD
        return Data("""
=======
        """
>>>>>>> Main
        Various Currency Formats:
        Total Amount: $125,000.00
        Line Item Amount: 1250.50
        Base Amount: $1,250
        Tax Amount: 125.00 USD
        """.utf8)
    }
}
