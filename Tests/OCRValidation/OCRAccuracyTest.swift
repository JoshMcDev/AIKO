@testable import AppCore
import Foundation
import XCTest

final class OCRAccuracyTest: XCTestCase {
    let parser = DocumentParserEnhanced()

    // MARK: - Test Files

    let testImagePath = "/Users/J/Desktop/quote pic.jpeg"
    let testPDFPath = "/Users/J/Desktop/quote scan.pdf"

    // MARK: - Test Image OCR

    func testImageOCRAccuracy() async throws {
        print("\n========== IMAGE OCR TEST ==========")
        print("Processing: \(testImagePath)")

        // Load image file
        let imageData = try Data(contentsOf: URL(fileURLWithPath: testImagePath))
        print("Image size: \(imageData.count) bytes")

        // Parse the image
        let startTime = Date()
        let parsedDocument = try await parser.parse(imageData, type: .jpeg)
        let processingTime = Date().timeIntervalSince(startTime)

        // Print results
        print("\nProcessing time: \(String(format: "%.2f", processingTime)) seconds")
        print("Confidence score: \(String(format: "%.2f%%", parsedDocument.confidence * 100))")

        print("\n--- EXTRACTED TEXT ---")
        print(parsedDocument.extractedText)

        print("\n--- EXTRACTED ENTITIES ---")
        for entity in parsedDocument.extractedData.entities {
            print("[\(entity.type.rawValue)] \(entity.value) (confidence: \(String(format: "%.2f%%", entity.confidence * 100)))")
        }

        print("\n--- STRUCTURED DATA ---")
        analyzeExtractedData(parsedDocument.extractedData)

        // Validate accuracy
        let accuracy = calculateAccuracy(parsedDocument)
        print("\n--- ACCURACY METRICS ---")
        print("Overall accuracy: \(String(format: "%.2f%%", accuracy * 100))")

        XCTAssertGreaterThanOrEqual(accuracy, 0.95, "OCR accuracy should be at least 95%")
    }

    // MARK: - Test PDF OCR

    func testPDFOCRAccuracy() async throws {
        print("\n========== PDF OCR TEST ==========")
        print("Processing: \(testPDFPath)")

        // Load PDF file
        let pdfData = try Data(contentsOf: URL(fileURLWithPath: testPDFPath))
        print("PDF size: \(pdfData.count) bytes")

        // Parse the PDF
        let startTime = Date()
        let parsedDocument = try await parser.parse(pdfData, type: .pdf)
        let processingTime = Date().timeIntervalSince(startTime)

        // Print results
        print("\nProcessing time: \(String(format: "%.2f", processingTime)) seconds")
        print("Confidence score: \(String(format: "%.2f%%", parsedDocument.confidence * 100))")
        print("Page count: \(parsedDocument.metadata.pageCount ?? 0)")

        print("\n--- EXTRACTED TEXT ---")
        print(parsedDocument.extractedText)

        print("\n--- EXTRACTED ENTITIES ---")
        for entity in parsedDocument.extractedData.entities {
            print("[\(entity.type.rawValue)] \(entity.value) (confidence: \(String(format: "%.2f%%", entity.confidence * 100)))")
        }

        print("\n--- STRUCTURED DATA ---")
        analyzeExtractedData(parsedDocument.extractedData)

        // Validate accuracy
        let accuracy = calculateAccuracy(parsedDocument)
        print("\n--- ACCURACY METRICS ---")
        print("Overall accuracy: \(String(format: "%.2f%%", accuracy * 100))")

        XCTAssertGreaterThanOrEqual(accuracy, 0.95, "OCR accuracy should be at least 95%")
    }

    // MARK: - Comparative Analysis

    func testComparativeOCRAnalysis() async throws {
        print("\n========== COMPARATIVE OCR ANALYSIS ==========")

        // Process both files
        let imageData = try Data(contentsOf: URL(fileURLWithPath: testImagePath))
        let pdfData = try Data(contentsOf: URL(fileURLWithPath: testPDFPath))

        let imageParsed = try await parser.parse(imageData, type: .jpeg)
        let pdfParsed = try await parser.parse(pdfData, type: .pdf)

        print("\n--- COMPARISON METRICS ---")
        print("Image confidence: \(String(format: "%.2f%%", imageParsed.confidence * 100))")
        print("PDF confidence: \(String(format: "%.2f%%", pdfParsed.confidence * 100))")

        print("\nImage text length: \(imageParsed.extractedText.count) characters")
        print("PDF text length: \(pdfParsed.extractedText.count) characters")

        print("\nImage entities found: \(imageParsed.extractedData.entities.count)")
        print("PDF entities found: \(pdfParsed.extractedData.entities.count)")

        // Compare key extracted data
        compareExtractedData(image: imageParsed.extractedData, pdf: pdfParsed.extractedData)
    }

    // MARK: - Helper Methods

    private func analyzeExtractedData(_ data: ExtractedData) {
        // Vendor information
        if let vendor = data.entities.first(where: { $0.type == .vendor }) {
            print("Vendor: \(vendor.value)")
        }

        // Price information
        let prices = data.entities.filter { $0.type == .price }
        if !prices.isEmpty {
            print("Prices found: \(prices.count)")
            for price in prices {
                print("  - \(price.value)")
            }
        }

        // Dates
        let dates = data.entities.filter { $0.type == .date }
        if !dates.isEmpty {
            print("Dates found: \(dates.count)")
            for date in dates {
                print("  - \(date.value)")
            }
        }

        // Contact information
        if let email = data.entities.first(where: { $0.type == .email }) {
            print("Email: \(email.value)")
        }
        if let phone = data.entities.first(where: { $0.type == .phone }) {
            print("Phone: \(phone.value)")
        }

        // Tables
        if !data.tables.isEmpty {
            print("Tables found: \(data.tables.count)")
            for (index, table) in data.tables.enumerated() {
                print("  Table \(index + 1): \(table.headers.count) columns, \(table.rows.count) rows")
            }
        }
    }

    private func calculateAccuracy(_ document: ParsedDocument) -> Double {
        var scoreComponents: [Double] = []

        // Text extraction quality (based on length and readability)
        let textScore = document.extractedText.count > 100 ? 1.0 : Double(document.extractedText.count) / 100.0
        scoreComponents.append(textScore * 0.3) // 30% weight

        // Entity extraction quality
        let hasVendor = document.extractedData.entities.contains { $0.type == .vendor }
        let hasPrice = document.extractedData.entities.contains { $0.type == .price }
        let hasDate = document.extractedData.entities.contains { $0.type == .date }

        let entityScore = [hasVendor, hasPrice, hasDate].filter { $0 }.count / 3.0
        scoreComponents.append(entityScore * 0.4) // 40% weight

        // Confidence score from parser
        scoreComponents.append(document.confidence * 0.3) // 30% weight

        return scoreComponents.reduce(0, +)
    }

    private func compareExtractedData(image: ExtractedData, pdf: ExtractedData) {
        print("\n--- ENTITY COMPARISON ---")

        // Compare vendors
        let imageVendor = image.entities.first { $0.type == .vendor }?.value
        let pdfVendor = pdf.entities.first { $0.type == .vendor }?.value

        if let imageVendorValue = imageVendor, let pdfVendorValue = pdfVendor {
            let similarity = stringSimilarity(imageVendorValue, pdfVendorValue)
            print("Vendor match: \(String(format: "%.2f%%", similarity * 100))")
            print("  Image: \(imageVendorValue)")
            print("  PDF: \(pdfVendorValue)")
        }

        // Compare prices
        let imagePrices = image.entities.filter { $0.type == .price }.map(\.value)
        let pdfPrices = pdf.entities.filter { $0.type == .price }.map(\.value)

        print("\nPrice extraction:")
        print("  Image prices: \(imagePrices.joined(separator: ", "))")
        print("  PDF prices: \(pdfPrices.joined(separator: ", "))")

        // Compare overall entity counts
        let imageTypes = Dictionary(grouping: image.entities, by: { $0.type })
        let pdfTypes = Dictionary(grouping: pdf.entities, by: { $0.type })

        print("\nEntity type distribution:")
        let allTypes = Set(imageTypes.keys).union(Set(pdfTypes.keys))
        for type in allTypes {
            print("  \(type.rawValue): Image=\(imageTypes[type]?.count ?? 0), PDF=\(pdfTypes[type]?.count ?? 0)")
        }
    }

    private func stringSimilarity(_ firstString: String, _ secondString: String) -> Double {
        let longer = firstString.count > secondString.count ? firstString : secondString
        let shorter = firstString.count > secondString.count ? secondString : firstString

        if longer.isEmpty { return 1.0 }

        let editDistance = levenshteinDistance(shorter, longer)
        return (Double(longer.count) - Double(editDistance)) / Double(longer.count)
    }

    private func levenshteinDistance(_ firstString: String, _ secondString: String) -> Int {
        let firstLength = firstString.count
        let secondLength = secondString.count

        if firstLength == 0 { return secondLength }
        if secondLength == 0 { return firstLength }

        var matrix = Array(repeating: Array(repeating: 0, count: secondLength + 1), count: firstLength + 1)

        for rowIndex in 0 ... firstLength {
            matrix[rowIndex][0] = rowIndex
        }

        for columnIndex in 0 ... secondLength {
            matrix[0][columnIndex] = columnIndex
        }

        for rowIndex in 1 ... firstLength {
            for columnIndex in 1 ... secondLength {
                let cost = firstString[firstString.index(firstString.startIndex, offsetBy: rowIndex - 1)] == secondString[secondString.index(secondString.startIndex, offsetBy: columnIndex - 1)] ? 0 : 1
                matrix[rowIndex][columnIndex] = min(
                    matrix[rowIndex - 1][columnIndex] + 1,
                    matrix[rowIndex][columnIndex - 1] + 1,
                    matrix[rowIndex - 1][columnIndex - 1] + cost
                )
            }
        }

        return matrix[firstLength][secondLength]
    }
}

// MARK: - Performance Test Extension

extension OCRAccuracyTest {
    func testOCRPerformance() async throws {
        print("\n========== OCR PERFORMANCE TEST ==========")

        // Test image performance
        let imageData = try Data(contentsOf: URL(fileURLWithPath: testImagePath))

        let imageTime = try await measureTime {
            _ = try await parser.parse(imageData, type: .jpeg)
        }

        print("Image OCR time: \(String(format: "%.3f", imageTime)) seconds")

        // Test PDF performance
        let pdfData = try Data(contentsOf: URL(fileURLWithPath: testPDFPath))

        let pdfTime = try await measureTime {
            _ = try await parser.parse(pdfData, type: .pdf)
        }

        print("PDF OCR time: \(String(format: "%.3f", pdfTime)) seconds")

        // Performance requirements
        XCTAssertLessThan(imageTime, 5.0, "Image OCR should complete within 5 seconds")
        XCTAssertLessThan(pdfTime, 10.0, "PDF OCR should complete within 10 seconds")
    }

    private func measureTime(operation: () async throws -> some Any) async throws -> TimeInterval {
        let start = Date()
        _ = try await operation()
        return Date().timeIntervalSince(start)
    }
}
