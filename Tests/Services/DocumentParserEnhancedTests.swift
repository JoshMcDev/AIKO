@testable import AppCore
import PDFKit
import UniformTypeIdentifiers
import XCTest

final class DocumentParserEnhancedTests: XCTestCase {
    private var parser: DocumentParserEnhanced?

    private var parserUnwrapped: DocumentParserEnhanced {
        guard let parser else { fatalError("parser not initialized") }
        return parser
    }

    override func setUp() {
        super.setUp()
        parser = DocumentParserEnhanced()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    // MARK: - PDF Parsing Tests

    func testParsePDFWithText() async throws {
        // Create a simple PDF with text
        let pdfDocument = PDFDocument()
        let page = PDFPage()

        // Create attributed string with test content
        let testContent = """
        Quote #Q2025-001
        Date: 01/15/2025

        ABC Company
        123 Main Street
        New York, NY 10001
        Phone: (555) 123-4567
        Email: sales@abccompany.com

        Item Description: Office Supplies
        Quantity: 10
        Unit Price: $25.50
        Total: $255.00

        Payment Terms: Net 30
        Delivery: FOB Destination
        """

        let attributedString = NSAttributedString(string: testContent)
        page.attributedString = attributedString
        pdfDocument.insert(page, at: 0)

        guard let pdfData = pdfDocument.dataRepresentation() else {
            XCTFail("Failed to create PDF data")
            return
        }

        // Parse the PDF
        let result = try await parserUnwrapped.parseWithStructuredData(pdfData, type: .pdf, fileName: "test_quote.pdf")

        // Verify basic parsing
        XCTAssertFalse(result.extractedText.isEmpty)
        XCTAssertTrue(result.extractedText.contains("ABC Company"))
        XCTAssertEqual(result.sourceType, .pdf)

        // Verify metadata
        XCTAssertEqual(result.metadata.fileName, "test_quote.pdf")
        XCTAssertEqual(result.metadata.pageCount, 1)
        XCTAssertGreaterThan(result.metadata.fileSize, 0)

        // Verify extracted data
        XCTAssertEqual(result.extractedData.vendorName, "ABC Company")
        XCTAssertEqual(result.extractedData.vendorPhone, "(555) 123-4567")
        XCTAssertEqual(result.extractedData.vendorEmail, "sales@abccompany.com")
        XCTAssertEqual(result.extractedData.quoteNumber, "Q2025-001")
        XCTAssertEqual(result.extractedData.totalPrice, 255.00)
        XCTAssertEqual(result.extractedData.paymentTerms, "Net 30")
        XCTAssertEqual(result.extractedData.deliveryTerms, "FOB Destination")

        // Verify line items
        XCTAssertEqual(result.extractedData.lineItems.count, 1)
        if let firstItem = result.extractedData.lineItems.first {
            XCTAssertTrue(firstItem.description.contains("Office Supplies"))
            XCTAssertEqual(firstItem.quantity, 10)
            XCTAssertEqual(firstItem.unitPrice, 25.50)
            XCTAssertEqual(firstItem.totalPrice, 255.00)
        }

        // Verify confidence
        XCTAssertGreaterThan(result.confidence, 0.5)
    }

    func testParseEmptyPDF() async throws {
        // Create empty PDF
        let pdfDocument = PDFDocument()
        guard let pdfData = pdfDocument.dataRepresentation() else {
            XCTFail("Failed to create PDF data")
            return
        }

        // Parse the PDF
        let result = try await parserUnwrapped.parseWithStructuredData(pdfData, type: .pdf, fileName: "empty.pdf")

        // Verify parsing handles empty content
        XCTAssertTrue(result.extractedText.isEmpty || result.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertEqual(result.metadata.pageCount, 0)

        // Verify no data extracted
        XCTAssertNil(result.extractedData.vendorName)
        XCTAssertNil(result.extractedData.quoteNumber)
        XCTAssertTrue(result.extractedData.lineItems.isEmpty)

        // Confidence should be low
        XCTAssertLessThan(result.confidence, 0.2)
    }

    // MARK: - Data Extraction Tests

    func testExtractVendorInformation() async throws {
        let testText = """
        Vendor: Tech Solutions Inc.
        Address: 456 Innovation Blvd, Suite 200
        San Francisco, CA 94105
        Contact: John Smith
        Phone: +1 (415) 555-9876
        Email: john.smith@techsolutions.com
        UEI: ABCD1234EFGH
        CAGE Code: 12345
        """

        guard let data = testText.data(using: .utf8) else {
            XCTFail("Failed to convert test text to data")
            return
        }
        let result = try await parserUnwrapped.parseWithStructuredData(data, type: .plainText, fileName: "vendor_info.txt")

        XCTAssertEqual(result.extractedData.vendorName, "Tech Solutions Inc.")
        XCTAssertNotNil(result.extractedData.vendorAddress)
        XCTAssertTrue(result.extractedData.vendorAddress?.contains("San Francisco") ?? false)
        XCTAssertEqual(result.extractedData.vendorPhone, "+1 (415) 555-9876")
        XCTAssertEqual(result.extractedData.vendorEmail, "john.smith@techsolutions.com")
        XCTAssertEqual(result.extractedData.vendorUEI, "ABCD1234EFGH")
        XCTAssertEqual(result.extractedData.vendorCAGE, "12345")
    }

    func testExtractLineItems() async throws {
        let testText = """
        Quote Details:

        1. Laptop Computer - $1,200.00 x 5 = $6,000.00
        2. Wireless Mouse - $45.99 x 10 = $459.90
        3. USB-C Hub - $89.50 x 5 = $447.50

        Subtotal: $6,907.40
        Tax: $552.59
        Total: $7,459.99
        """

        guard let data = testText.data(using: .utf8) else {
            XCTFail("Failed to convert test text to data")
            return
        }
        let result = try await parserUnwrapped.parseWithStructuredData(data, type: .plainText, fileName: "line_items.txt")

        XCTAssertGreaterThanOrEqual(result.extractedData.lineItems.count, 3)

        // Check if we captured the total
        XCTAssertNotNil(result.extractedData.totalPrice)
        if let total = result.extractedData.totalPrice {
            XCTAssertEqual(total, 7459.99, accuracy: 0.01)
        }
    }

    func testExtractDates() async throws {
        let testText = """
        Quote Date: 01/15/2025
        Valid Until: February 15, 2025
        Delivery Date: 2025-03-01
        """

        guard let data = testText.data(using: .utf8) else {
            XCTFail("Failed to convert test text to data")
            return
        }
        let result = try await parserUnwrapped.parseWithStructuredData(data, type: .plainText, fileName: "dates.txt")

        XCTAssertNotNil(result.extractedData.quoteDate)
        XCTAssertNotNil(result.extractedData.validUntilDate)

        // Verify date parsing
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"
        if let quoteDate = result.extractedData.quoteDate {
            guard let expectedDate = dateFormatter.date(from: "01/15/2025") else {
                XCTFail("Failed to create expected date from string")
                return
            }
            XCTAssertEqual(quoteDate.timeIntervalSince1970, expectedDate.timeIntervalSince1970, accuracy: 86400) // Within 1 day
        }
    }

    func testExtractTerms() async throws {
        let testText = """
        Terms and Conditions:

        Payment Terms: 2/10 Net 30
        Shipping Terms: FOB Origin, Freight Prepaid
        Warranty: 1 year manufacturer warranty

        Additional Notes:
        - All prices in USD
        - Subject to availability
        """

        guard let data = testText.data(using: .utf8) else {
            XCTFail("Failed to convert test text to data")
            return
        }
        let result = try await parserUnwrapped.parseWithStructuredData(data, type: .plainText, fileName: "terms.txt")

        XCTAssertEqual(result.extractedData.paymentTerms, "2/10 Net 30")
        XCTAssertNotNil(result.extractedData.deliveryTerms)
        XCTAssertTrue(result.extractedData.deliveryTerms?.contains("FOB Origin") ?? false)
        XCTAssertEqual(result.extractedData.warrantyTerms, "1 year manufacturer warranty")
    }

    // MARK: - Error Handling Tests

    func testHandleCorruptedData() async throws {
        // Create some corrupted data
        let corruptedData = Data([0xFF, 0xFE, 0x00, 0x01, 0x02, 0x03])

        do {
            _ = try await parserUnwrapped.parseWithStructuredData(corruptedData, type: .pdf, fileName: "corrupted.pdf")
            XCTFail("Should have thrown an error for corrupted data")
        } catch {
            // Expected error
            XCTAssertTrue(error is DocumentParserError)
        }
    }

    // MARK: - Performance Tests

    func testParsingPerformance() throws {
        // Create a large text document
        var largeText = ""
        for i in 1 ... 1000 {
            largeText += "Line \(i): This is a test line with some content including price $\(i).99\n"
        }

        guard let data = largeText.data(using: .utf8) else {
            XCTFail("Failed to convert large text to data")
            return
        }

        measure {
            let expectation = self.expectation(description: "Parse large document")

            Task {
                _ = try await parserUnwrapped.parseWithStructuredData(data, type: .plainText, fileName: "large.txt")
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }
}

// MARK: - Helper Extensions

extension DocumentParserEnhanced {
    /// Parse plain text for testing
    func parseWithStructuredData(_ data: Data, type: UTType, fileName: String?) async throws -> ParsedDocument {
        if type == .plainText {
            let text = String(data: data, encoding: .utf8) ?? ""

            // Extract structured data
            let dataExtractor = DataExtractor()
            let extractedData = try await dataExtractor.extract(from: text)

            // Create metadata
            let metadata = ParsedDocumentMetadata(
                fileName: fileName,
                fileSize: data.count,
                creationDate: Date()
            )

            // Calculate confidence
            let confidence = calculateConfidence(for: extractedData)

            return ParsedDocument(
                sourceType: .pdf, // Default for plain text
                extractedText: text,
                metadata: metadata,
                extractedData: extractedData,
                confidence: confidence
            )
        }

        return try await parseWithStructuredData(data, type: type, fileName: fileName)
    }

    private func calculateConfidence(for extractedData: ExtractedData) -> Double {
        var filledFields = 0
        var totalFields = 0

        // Check vendor fields
        let vendorFields: [String?] = [
            extractedData.vendorName,
            extractedData.vendorAddress,
            extractedData.vendorPhone,
            extractedData.vendorEmail,
        ]
        totalFields += vendorFields.count
        filledFields += vendorFields.compactMap { $0 }.filter { !$0.isEmpty }.count

        // Check quote fields
        let quoteFields: [Any?] = [
            extractedData.quoteNumber,
            extractedData.quoteDate,
            extractedData.totalPrice,
        ]
        totalFields += quoteFields.count
        filledFields += quoteFields.compactMap { $0 }.count

        // Check line items
        if !extractedData.lineItems.isEmpty {
            filledFields += 2
            totalFields += 2
        }

        return totalFields > 0 ? Double(filledFields) / Double(totalFields) : 0.0
    }
}
