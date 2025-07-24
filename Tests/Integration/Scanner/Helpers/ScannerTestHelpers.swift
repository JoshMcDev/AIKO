@testable import AppCoreiOS
@testable import AppCore
import ComposableArchitecture
import Foundation
import XCTest

/// Reusable test assertions and utilities for scanner workflow integration tests
/// Following AIKO TCA patterns with async workflow support
@MainActor
public final class ScannerTestHelpers {
    // MARK: - Common Test Timing

    /// Standard timeout for scanner operations (meets <500ms requirement)
    public static let scannerPresentationTimeout: TimeInterval = 0.6

    /// Timeout for OCR processing operations
    public static let ocrProcessingTimeout: TimeInterval = 10.0

    /// Timeout for form auto-population operations
    public static let autoPopulationTimeout: TimeInterval = 5.0

    /// Timeout for complete end-to-end workflow
    public static let endToEndWorkflowTimeout: TimeInterval = 15.0

    // MARK: - Test Assertions for Scanner Workflows

    /// Assert scanner presentation speed meets requirements (<500ms)
    /// - Parameters:
    ///   - startTime: Time when scanner tap occurred
    ///   - presentationTime: Time when scanner became presented
    public static func assertScannerPresentationSpeed(
        startTime: Date,
        presentationTime: Date,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let elapsed = presentationTime.timeIntervalSince(startTime)
        XCTAssertLessThan(
            elapsed,
            0.5,
            "Scanner presentation exceeded 500ms requirement: \(elapsed)s",
            file: file,
            line: line
        )
    }

    /// Assert OCR accuracy meets requirements (>95%)
    /// - Parameters:
    ///   - extractedText: Text extracted by OCR
    ///   - expectedText: Expected ground truth text
    ///   - threshold: Minimum accuracy threshold (default 0.95)
    public static func assertOCRAccuracy(
        extractedText: String,
        expectedText: String,
        threshold: Double = 0.95,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let accuracy = calculateTextSimilarity(extractedText, expectedText)
        XCTAssertGreaterThan(
            accuracy,
            threshold,
            "OCR accuracy \(accuracy) below threshold \(threshold) for text: '\(extractedText)' vs expected: '\(expectedText)'",
            file: file,
            line: line
        )
    }

    /// Assert auto-population success rate meets requirements (>85%)
    /// - Parameters:
    ///   - populatedFields: Number of successfully populated fields
    ///   - totalFields: Total number of fields that should be populated
    ///   - threshold: Minimum success rate threshold (default 0.85)
    public static func assertAutoPopulationSuccess(
        populatedFields: Int,
        totalFields: Int,
        threshold: Double = 0.85,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard totalFields > 0 else {
            XCTFail("Total fields must be greater than 0", file: file, line: line)
            return
        }

        let successRate = Double(populatedFields) / Double(totalFields)
        XCTAssertGreaterThan(
            successRate,
            threshold,
            "Auto-population success rate \(successRate) below threshold \(threshold) (\(populatedFields)/\(totalFields))",
            file: file,
            line: line
        )
    }

    /// Assert document quality metrics meet requirements
    /// - Parameter qualityMetrics: Quality metrics from DocumentImageProcessor
    public static func assertDocumentQuality(
        _ qualityMetrics: DocumentImageProcessor.QualityMetrics,
        minimumConfidence: Double = 0.8,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertGreaterThan(
            qualityMetrics.overallConfidence,
            minimumConfidence,
            "Document quality confidence \(qualityMetrics.overallConfidence) below minimum \(minimumConfidence)",
            file: file,
            line: line
        )

        XCTAssertTrue(
            qualityMetrics.recommendedForOCR,
            "Document not recommended for OCR processing",
            file: file,
            line: line
        )
    }

    // MARK: - Common Setup/Teardown Helpers

    /// Setup test dependencies for scanner workflow tests
    /// - Returns: Configured test dependencies
    public static func setupScannerTestDependencies() -> DependencyValues {
        var dependencies = DependencyValues()

        // Mock DocumentImageProcessor with test values
        dependencies.documentImageProcessor = DocumentImageProcessor.testValue

        // Mock scanner client with test implementation
        dependencies.documentScannerClient = .testValue

        // Mock progress client for testing feedback
        dependencies.progressClient = .testValue

        return dependencies
    }

    /// Create test expectation for async scanner workflow
    /// - Parameters:
    ///   - description: Description for the expectation
    ///   - expectedFulfillmentCount: Number of times expectation should be fulfilled
    /// - Returns: Configured XCTestExpectation
    public static func createScannerWorkflowExpectation(
        description: String,
        expectedFulfillmentCount: Int = 1
    ) -> XCTestExpectation {
        let expectation = XCTestExpectation(description: description)
        expectation.expectedFulfillmentCount = expectedFulfillmentCount
        return expectation
    }

    /// Wait for multiple expectations with scanner-appropriate timeout
    /// - Parameter expectations: Array of expectations to wait for
    public static func waitForScannerExpectations(
        _ expectations: [XCTestExpectation],
        timeout: TimeInterval = endToEndWorkflowTimeout
    ) async {
        await fulfillment(of: expectations, timeout: timeout)
    }

    // MARK: - Test Data Helpers

    /// Create minimal valid JPEG test data
    /// - Returns: Minimal JPEG data for testing
    public static func createTestImageData() -> Data {
        // Minimal JPEG header for testing
        Data([
            0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46,
            0x49, 0x46, 0x00, 0x01, 0x01, 0x01, 0x00, 0x48,
            0x00, 0x48, 0x00, 0x00, 0xFF, 0xD9,
        ])
    }

    /// Create realistic test image data with document-like characteristics
    /// - Parameters:
    ///   - formType: Type of government form to simulate
    ///   - quality: Image quality level
    ///   - includeNoise: Whether to add noise for robustness testing
    /// - Returns: Realistic document image data
    public static func createGovernmentFormImageData(
        formType: GovernmentFormType = .sf18,
        quality: ImageQuality = .high,
        includeNoise: Bool = false
    ) -> Data {
        let width = quality == .high ? 2048 : 1024
        let height = quality == .high ? 2648 : 1324

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            return createTestImageData() // Fallback to minimal test data
        }

        // Fill with white background
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Add form-like content
        addMockFormContent(to: context, formType: formType, size: CGSize(width: width, height: height))

        // Add noise if requested for robustness testing
        if includeNoise {
            addImageNoise(to: context, size: CGSize(width: width, height: height))
        }

        guard let cgImage = context.makeImage() else {
            return createTestImageData() // Fallback to minimal test data
        }

        #if os(iOS)
            let image = UIImage(cgImage: cgImage)
            return image.pngData() ?? createTestImageData()
        #else
            let image = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
            return image.tiffRepresentation ?? createTestImageData()
        #endif
    }

    /// Create multi-page test document with various form types
    /// - Parameter pageCount: Number of pages to create
    /// - Returns: Array of ScannedPage objects
    public static func createMultiPageTestDocument(pageCount: Int = 3) -> [ScannedPage] {
        let formTypes: [GovernmentFormType] = [.sf18, .sf26, .dd1155]

        return (0 ..< pageCount).map { index in
            let formType = formTypes[index % formTypes.count]
            let imageData = createGovernmentFormImageData(formType: formType)

            return ScannedPage(
                id: UUID(),
                imageData: imageData,
                pageNumber: index + 1
            )
        }
    }

    /// Create mock OCR results for testing form population
    /// - Parameters:
    ///   - formType: Type of government form
    ///   - accuracy: OCR accuracy level (0.0-1.0)
    /// - Returns: Mock OCRResult for testing
    public static func createMockOCRResult(
        for formType: GovernmentFormType,
        accuracy: Double = 0.95
    ) -> OCRResult {
        let mockFields = createMockFormFields(for: formType)

        return OCRResult(
            extractedText: createMockExtractedText(for: formType),
            confidence: accuracy,
            detectedFields: mockFields,
            processingTime: TimeInterval.random(in: 0.5 ... 2.0),
            documentBounds: CGRect(x: 0, y: 0, width: 2048, height: 2648)
        )
    }

    /// Create test ScannedPage with mock data
    /// - Parameters:
    ///   - pageNumber: Page number for the scanned page
    ///   - imageData: Optional image data (uses test data if nil)
    /// - Returns: ScannedPage for testing
    public static func createTestScannedPage(
        pageNumber: Int = 1,
        imageData: Data? = nil
    ) -> ScannedPage {
        ScannedPage(
            id: UUID(),
            imageData: imageData ?? createTestImageData(),
            pageNumber: pageNumber
        )
    }

    // MARK: - Performance Testing Helpers

    /// Measures async workflow performance with detailed metrics
    /// - Parameters:
    ///   - description: Description of the operation being measured
    ///   - iterations: Number of iterations to run
    ///   - operation: The async operation to measure
    /// - Returns: Performance metrics
    public static func measureAsyncWorkflow(
        description: String,
        iterations: Int = 5,
        operation: () async throws -> some Any
    ) async throws -> PerformanceMetrics {
        var executionTimes: [TimeInterval] = []
        var memoryUsages: [UInt64] = []

        for _ in 0 ..< iterations {
            let startTime = CFAbsoluteTimeGetCurrent()
            let startMemory = getCurrentMemoryUsage()

            _ = try await operation()

            let endTime = CFAbsoluteTimeGetCurrent()
            let endMemory = getCurrentMemoryUsage()

            executionTimes.append(endTime - startTime)
            memoryUsages.append(endMemory > startMemory ? endMemory - startMemory : 0)
        }

        return PerformanceMetrics(
            description: description,
            executionTimes: executionTimes,
            memoryDeltas: memoryUsages,
            iterations: iterations
        )
    }

    /// Creates expectation for async progress tracking
    /// - Parameters:
    ///   - expectedUpdates: Expected number of progress updates
    ///   - timeout: Timeout for the expectation
    /// - Returns: Expectation and progress handler closure
    public static func createProgressExpectation(
        expectedUpdates: Int,
        timeout _: TimeInterval = 10.0
    ) -> (expectation: XCTestExpectation, progressHandler: (Any) -> Void) {
        let expectation = XCTestExpectation(description: "Progress updates received")
        expectation.expectedFulfillmentCount = expectedUpdates

        var receivedUpdates: [Any] = []

        let progressHandler: (Any) -> Void = { update in
            receivedUpdates.append(update)
            expectation.fulfill()
        }

        return (expectation, progressHandler)
    }

    // MARK: - Private Helpers

    /// Calculate text similarity for OCR accuracy testing
    /// Uses Levenshtein distance for similarity calculation
    private static func calculateTextSimilarity(_ text1: String, _ text2: String) -> Double {
        guard !text1.isEmpty || !text2.isEmpty else { return 1.0 }
        guard !text1.isEmpty, !text2.isEmpty else { return 0.0 }

        let distance = levenshteinDistance(text1, text2)
        let maxLength = max(text1.count, text2.count)
        return 1.0 - (Double(distance) / Double(maxLength))
    }

    /// Calculate Levenshtein distance between two strings
    private static func levenshteinDistance(_ firstString: String, _ secondString: String) -> Int {
        let firstLength = firstString.count
        let secondLength = secondString.count

        if firstLength == 0 { return secondLength }
        if secondLength == 0 { return firstLength }

        let firstArray = Array(firstString)
        let secondArray = Array(secondString)

        var matrix = Array(repeating: Array(repeating: 0, count: secondLength + 1), count: firstLength + 1)

        for rowIndex in 0 ... firstLength {
            matrix[rowIndex][0] = rowIndex
        }
        for columnIndex in 0 ... secondLength {
            matrix[0][columnIndex] = columnIndex
        }

        for rowIndex in 1 ... firstLength {
            for columnIndex in 1 ... secondLength {
                let cost = firstArray[rowIndex - 1] == secondArray[columnIndex - 1] ? 0 : 1
                matrix[rowIndex][columnIndex] = min(
                    matrix[rowIndex - 1][columnIndex] + 1, // deletion
                    matrix[rowIndex][columnIndex - 1] + 1, // insertion
                    matrix[rowIndex - 1][columnIndex - 1] + cost // substitution
                )
            }
        }

        return matrix[firstLength][secondLength]
    }

    // MARK: - Additional Helper Functions

    /// Create mock form fields based on government form type
    private static func createMockFormFields(for formType: GovernmentFormType) -> [DocumentFormField] {
        switch formType {
        case .sf18:
            [
                DocumentFormField(
                    id: "contractor_name",
                    label: "Contractor Name",
                    value: "ACME Corporation",
                    confidence: 0.92,
                    fieldType: .text,
                    boundingRect: CGRect(x: 100, y: 200, width: 300, height: 25)
                ),
                DocumentFormField(
                    id: "contract_number",
                    label: "Contract Number",
                    value: "W912HZ-24-C-0001",
                    confidence: 0.88,
                    fieldType: .alphanumeric,
                    boundingRect: CGRect(x: 500, y: 200, width: 200, height: 25)
                ),
            ]
        case .sf26:
            [
                DocumentFormField(
                    id: "award_number",
                    label: "Award Number",
                    value: "SP4701-25-A-0042",
                    confidence: 0.90,
                    fieldType: .alphanumeric,
                    boundingRect: CGRect(x: 100, y: 150, width: 200, height: 25)
                ),
            ]
        case .dd1155:
            [
                DocumentFormField(
                    id: "requisition_number",
                    label: "Requisition Number",
                    value: "DD-2024-REQ-5532",
                    confidence: 0.87,
                    fieldType: .alphanumeric,
                    boundingRect: CGRect(x: 100, y: 180, width: 180, height: 25)
                ),
            ]
        }
    }

    /// Create mock extracted text for government forms
    private static func createMockExtractedText(for formType: GovernmentFormType) -> String {
        switch formType {
        case .sf18:
            """
            REQUEST AND AUTHORIZATION FOR TDY
            Contractor Name: ACME Corporation
            Contract Number: W912HZ-24-C-0001
            Total Contract Value: $1,250,000.00
            """
        case .sf26:
            """
            AWARD/CONTRACT
            Award Number: SP4701-25-A-0042
            DUNS Number: 123456789
            """
        case .dd1155:
            """
            ORDER FOR SUPPLIES OR SERVICES
            Requisition Number: DD-2024-REQ-5532
            Required Delivery Date: 2024-08-15
            """
        }
    }

    /// Add mock form content to CGContext for realistic test images
    private static func addMockFormContent(
        to context: CGContext,
        formType: GovernmentFormType,
        size: CGSize
    ) {
        // Set up text rendering (simplified for testing)
        context.setFillColor(CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0))

        let headerY = size.height * 0.1
        let fieldStartY = size.height * 0.3

        // Add form-specific visual elements (simplified rectangles for testing)
        switch formType {
        case .sf18:
            // Add title area
            context.fill(CGRect(x: 50, y: headerY, width: 200, height: 30))
            // Add field areas
            context.fill(CGRect(x: 50, y: fieldStartY, width: 300, height: 20))
            context.fill(CGRect(x: 50, y: fieldStartY + 50, width: 250, height: 20))

        case .sf26:
            context.fill(CGRect(x: 50, y: headerY, width: 180, height: 30))
            context.fill(CGRect(x: 50, y: fieldStartY, width: 280, height: 20))

        case .dd1155:
            context.fill(CGRect(x: 50, y: headerY, width: 220, height: 30))
            context.fill(CGRect(x: 50, y: fieldStartY, width: 320, height: 20))
        }
    }

    /// Add noise to image for robustness testing
    private static func addImageNoise(to context: CGContext, size: CGSize) {
        context.setFillColor(CGColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.3))

        for _ in 0 ..< 100 {
            let xCoordinate = CGFloat.random(in: 0 ... size.width)
            let yCoordinate = CGFloat.random(in: 0 ... size.height)
            let noise = CGRect(x: xCoordinate, y: yCoordinate, width: 2, height: 2)
            context.fill(noise)
        }
    }

    /// Get current memory usage for performance testing
    private static func getCurrentMemoryUsage() -> UInt64 {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return taskInfo.phys_footprint
    }
}

// MARK: - Supporting Types

/// Government form types for testing
public enum GovernmentFormType: CaseIterable {
    case sf18 // Request and Authorization for TDY
    case sf26 // Award/Contract
    case dd1155 // Order for Supplies or Services
}

/// Image quality levels for testing
public enum ImageQuality {
    case low, medium, high
}

/// Performance metrics for async workflow testing
public struct PerformanceMetrics {
    public let description: String
    public let executionTimes: [TimeInterval]
    public let memoryDeltas: [UInt64]
    public let iterations: Int

    public var averageExecutionTime: TimeInterval {
        executionTimes.reduce(0, +) / Double(iterations)
    }

    public var averageMemoryDelta: UInt64 {
        memoryDeltas.reduce(0, +) / UInt64(iterations)
    }
}

// MARK: - Extensions for Test Support

public extension TestStore where State == DocumentScannerFeature.State {
    /// Configure test store with scanner test dependencies
    func withScannerTestDependencies() -> TestStore<DocumentScannerFeature.State, DocumentScannerFeature.Action> {
        TestStore(initialState: state) {
            DocumentScannerFeature()
        } withDependencies: {
            let testDeps = ScannerTestHelpers.setupScannerTestDependencies()
            $0 = testDeps
        }
    }
}

public extension XCTestExpectation {
    /// Configure expectation with scanner-appropriate timeout
    func withScannerTimeout(_: TimeInterval = ScannerTestHelpers.endToEndWorkflowTimeout) -> Self {
        // Note: XCTestExpectation doesn't have a timeout property to set directly
        // The timeout is specified in the wait/fulfillment call
        self
    }
}
