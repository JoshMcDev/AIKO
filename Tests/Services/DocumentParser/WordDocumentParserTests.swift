@testable import AppCore
import UniformTypeIdentifiers
import XCTest

final class WordDocumentParserTests: XCTestCase {
    var parser: WordDocumentParser?

    private var parserUnwrapped: WordDocumentParser {
        guard let parser else { fatalError("parser not initialized") }
        return parser
    }

    override func setUp() {
        super.setUp()
        parser = WordDocumentParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    // MARK: - Tests

    func testParseEmptyDocxData() async throws {
        // Given empty data
        let emptyData = Data()
        let docxType = UTType(filenameExtension: "docx") ?? .data

        // When parsing
        let result = try await parserUnwrapped.parse(emptyData, type: docxType)

        // Then it should return empty string
        XCTAssertEqual(result, "")
    }

    func testParseDocxWithPlainTextContent() async throws {
        // Given a simple docx structure with text
        let testText = "This is a test document with some content."
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <w:document>
            <w:body>
                <w:p>
                    <w:r>
                        <w:t>\(testText)</w:t>
                    </w:r>
                </w:p>
            </w:body>
        </w:document>
        """

        guard let data = xmlContent.data(using: .utf8) else {
            XCTFail("Failed to convert XML content to UTF-8 data for plain text test")
            return
        }
        let docxType = UTType(filenameExtension: "docx") ?? .data

        // When parsing
        let result = try await parserUnwrapped.parse(data, type: docxType)

        // Then it should extract the text
        XCTAssertTrue(result.contains(testText))
    }

    func testParseDocxWithMultipleParagraphs() async throws {
        // Given docx with multiple paragraphs
        let para1 = "First paragraph content"
        let para2 = "Second paragraph content"
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <w:document>
            <w:body>
                <w:p>
                    <w:r>
                        <w:t>\(para1)</w:t>
                    </w:r>
                </w:p>
                <w:p>
                    <w:r>
                        <w:t>\(para2)</w:t>
                    </w:r>
                </w:p>
            </w:body>
        </w:document>
        """

        guard let data = xmlContent.data(using: .utf8) else {
            XCTFail("Failed to convert XML content to UTF-8 data for multiple paragraphs test")
            return
        }
        let docxType = UTType(filenameExtension: "docx") ?? .data

        // When parsing
        let result = try await parserUnwrapped.parse(data, type: docxType)

        // Then it should extract both paragraphs
        XCTAssertTrue(result.contains(para1))
        XCTAssertTrue(result.contains(para2))
    }

    func testParseLegacyDocFormat() async throws {
        // Given binary data that simulates a .doc file
        var data = Data()

        // Add some binary data with embedded text
        data.append(contentsOf: [0x00, 0x01, 0x02]) // Binary header
        data.append(Data("This is readable text".utf8))
        data.append(contentsOf: [0x00, 0x00]) // Binary separator
        data.append(Data("More readable content".utf8))
        data.append(contentsOf: [0xFF, 0xFE, 0xFD]) // Binary footer

        let docType = UTType(filenameExtension: "doc") ?? .data

        // When parsing
        let result = try await parserUnwrapped.parse(data, type: docType)

        // Then it should extract readable text
        XCTAssertTrue(result.contains("readable text"))
        XCTAssertTrue(result.contains("readable content"))
    }

    func testParseUnsupportedFormat() async throws {
        // Given a non-Word format
        let data = Data("Plain text data".utf8)
        let txtType = UTType.plainText

        // When parsing
        do {
            _ = try await parserUnwrapped.parse(data, type: txtType)
            XCTFail("Should have thrown unsupportedFormat error")
        } catch {
            // Then it should throw unsupportedFormat error
            XCTAssertEqual(error as? DocumentParserError, DocumentParserError.unsupportedFormat)
        }
    }

    func testExtractTextFromComplexXML() async throws {
        // Given complex XML with nested elements
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <document>
            <w:p>
                <w:pPr>
                    <w:spacing w:after="200"/>
                </w:pPr>
                <w:r>
                    <w:rPr>
                        <w:b/>
                    </w:rPr>
                    <w:t>Bold text here</w:t>
                </w:r>
                <w:r>
                    <w:t> and normal text</w:t>
                </w:r>
            </w:p>
            <w:p>
                <w:r>
                    <w:t>Another paragraph</w:t>
                </w:r>
            </w:p>
        </document>
        """

        guard let data = xmlContent.data(using: .utf8) else {
            XCTFail("Failed to convert XML content to UTF-8 data for complex XML test")
            return
        }
        let docxType = UTType(filenameExtension: "docx") ?? .data

        // When parsing
        let result = try await parserUnwrapped.parse(data, type: docxType)

        // Then it should extract all text content
        XCTAssertTrue(result.contains("Bold text here"))
        XCTAssertTrue(result.contains("normal text"))
        XCTAssertTrue(result.contains("Another paragraph"))
    }

    func testCleanExtractedText() async throws {
        // Given text with excessive whitespace
        let xmlContent = """
        <w:document>
            <w:p><w:r><w:t>Text   with    spaces</w:t></w:r></w:p>
            <w:p><w:r><w:t>


        Multiple newlines</w:t></w:r></w:p>
        </w:document>
        """

        guard let data = xmlContent.data(using: .utf8) else {
            XCTFail("Failed to convert XML content to UTF-8 data for clean text test")
            return
        }
        let docxType = UTType(filenameExtension: "docx") ?? .data

        // When parsing
        let result = try await parserUnwrapped.parse(data, type: docxType)

        // Then it should clean up whitespace
        XCTAssertFalse(result.contains("   ")) // No triple spaces
        XCTAssertFalse(result.contains("\n\n\n")) // No triple newlines
    }

    func testBinaryDataExtraction() async throws {
        // Given binary data with scattered text
        var data = Data()

        // Simulate binary document with text fragments
        for i in 0 ..< 100 {
            if i % 10 == 0 {
                data.append(Data("Text\(i / 10)".utf8))
            } else {
                data.append(UInt8.random(in: 0 ... 255))
            }
        }

        let docType = UTType(filenameExtension: "doc") ?? .data

        // When parsing
        let result = try await parserUnwrapped.parse(data, type: docType)

        // Then it should extract text fragments
        XCTAssertTrue(result.contains("Text"))
        XCTAssertFalse(result.isEmpty)
    }
}
