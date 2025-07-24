@testable import AppCoreiOS
@testable import AppCore
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Factory for generating test documents with various quality levels and government form types
/// Supports SF-18, SF-26, DD-1155 form templates for comprehensive testing
public enum TestDocumentFactory {
    // MARK: - Document Types

    public enum GovernmentFormType: String, CaseIterable {
        case sf18 = "SF-18"
        case sf26 = "SF-26"
        case dd1155 = "DD-1155"

        var displayName: String {
            switch self {
            case .sf18: "Request and Authorization for Job Analysis"
            case .sf26: "Request for Job Analysis"
            case .dd1155: "Request and Receipt for Issue of Subsistence"
            }
        }

        var expectedFields: [String] {
            switch self {
            case .sf18:
                [
                    "Employee Name",
                    "Employee ID",
                    "Department",
                    "Position Title",
                    "Request Date",
                    "Supervisor Name",
                    "Reason for Request",
                ]
            case .sf26:
                [
                    "Requestor Name",
                    "Organization",
                    "Job Title",
                    "Analysis Type",
                    "Priority Level",
                    "Due Date",
                ]
            case .dd1155:
                [
                    "Service Member Name",
                    "Rank/Grade",
                    "Unit",
                    "Request Date",
                    "Items Requested",
                    "Quantity",
                    "Authorizing Officer",
                ]
            }
        }
    }

    // MARK: - Document Quality Levels

    public enum DocumentQuality: String, CaseIterable {
        case clean
        case damaged
        case rotated
        case blurry
        case lowContrast = "low_contrast"
        case skewed
        case handwritten

        var confidenceRange: ClosedRange<Double> {
            switch self {
            case .clean: 0.95 ... 1.0
            case .damaged: 0.6 ... 0.8
            case .rotated: 0.8 ... 0.9
            case .blurry: 0.5 ... 0.7
            case .lowContrast: 0.6 ... 0.8
            case .skewed: 0.7 ... 0.85
            case .handwritten: 0.4 ... 0.7
            }
        }

        var ocrAccuracyRange: ClosedRange<Double> {
            switch self {
            case .clean: 0.95 ... 0.99
            case .damaged: 0.7 ... 0.85
            case .rotated: 0.85 ... 0.95
            case .blurry: 0.5 ... 0.75
            case .lowContrast: 0.65 ... 0.8
            case .skewed: 0.75 ... 0.9
            case .handwritten: 0.4 ... 0.7
            }
        }
    }

    // MARK: - Document Generation

    /// Generate test document with specified form type and quality
    /// - Parameters:
    ///   - formType: Government form type to generate
    ///   - quality: Quality level of the document
    ///   - pageCount: Number of pages (default 1)
    /// - Returns: ScannedDocument with generated pages
    public static func generateTestDocument(
        formType: GovernmentFormType,
        quality: DocumentQuality,
        pageCount: Int = 1
    ) -> ScannedDocument {
        let pages = (1 ... pageCount).map { pageNumber in
            generateTestPage(
                formType: formType,
                quality: quality,
                pageNumber: pageNumber
            )
        }

        return ScannedDocument(
            id: UUID(),
            pages: pages,
            documentType: formType.rawValue,
            createdAt: Date(),
            confidence: randomConfidence(for: quality)
        )
    }

    /// Generate a single test page
    /// - Parameters:
    ///   - formType: Government form type
    ///   - quality: Quality level of the page
    ///   - pageNumber: Page number
    /// - Returns: ScannedPage with test data
    public static func generateTestPage(
        formType: GovernmentFormType,
        quality: DocumentQuality,
        pageNumber: Int = 1
    ) -> ScannedPage {
        let imageData = generateImageData(formType: formType, quality: quality)
        let processingResult = generateProcessingResult(formType: formType, quality: quality)

        return ScannedPage(
            id: UUID(),
            imageData: imageData,
            pageNumber: pageNumber,
            processingResult: processingResult,
            extractedText: generateSampleText(formType: formType, quality: quality),
            confidence: randomConfidence(for: quality)
        )
    }

    /// Generate sample text content based on form type and quality
    /// - Parameters:
    ///   - formType: Government form type
    ///   - quality: Quality level affecting text accuracy
    /// - Returns: Sample extracted text
    public static func generateSampleText(
        formType: GovernmentFormType,
        quality: DocumentQuality
    ) -> String {
        let baseText = getSampleFormText(for: formType)
        return applyQualityEffects(to: baseText, quality: quality)
    }

    /// Generate realistic image data for testing
    /// - Parameters:
    ///   - formType: Government form type
    ///   - quality: Quality level
    /// - Returns: Mock image data representing the document
    public static func generateImageData(
        formType _: GovernmentFormType,
        quality: DocumentQuality
    ) -> Data {
        // Generate a minimal but valid image format for testing
        // In a real implementation, this would create actual form templates
        let baseImageData = createMinimalJPEGData(
            width: 612, // Standard 8.5x11" at 72 DPI
            height: 792,
            quality: quality
        )

        return baseImageData
    }

    /// Generate processing result for a test document
    /// - Parameters:
    ///   - formType: Government form type
    ///   - quality: Quality level
    /// - Returns: DocumentImageProcessor.ProcessingResult
    public static func generateProcessingResult(
        formType: GovernmentFormType,
        quality: DocumentQuality
    ) -> DocumentImageProcessor.ProcessingResult {
        let confidence = randomConfidence(for: quality)

        return DocumentImageProcessor.ProcessingResult(
            processedImageData: generateImageData(formType: formType, quality: quality),
            qualityMetrics: DocumentImageProcessor.QualityMetrics(
                overallConfidence: confidence,
                recommendedForOCR: confidence > 0.7
            ),
            processingTime: Double.random(in: 0.1 ... 2.0),
            appliedFilters: getAppliedFilters(for: quality)
        )
    }

    // MARK: - Batch Generation Helpers

    /// Generate a batch of test documents with different qualities
    /// - Parameter formType: Government form type
    /// - Returns: Array of ScannedDocuments with varying qualities
    public static func generateQualityVariationBatch(
        formType: GovernmentFormType
    ) -> [ScannedDocument] {
        DocumentQuality.allCases.map { quality in
            generateTestDocument(formType: formType, quality: quality)
        }
    }

    /// Generate batch of documents for all form types
    /// - Parameter quality: Quality level for all documents
    /// - Returns: Array of ScannedDocuments for different form types
    public static func generateFormTypeBatch(
        quality: DocumentQuality = .clean
    ) -> [ScannedDocument] {
        GovernmentFormType.allCases.map { formType in
            generateTestDocument(formType: formType, quality: quality)
        }
    }

    /// Generate comprehensive test suite with all combinations
    /// - Returns: Array of ScannedDocuments covering all form types and qualities
    public static func generateComprehensiveTestSuite() -> [ScannedDocument] {
        var documents: [ScannedDocument] = []

        for formType in GovernmentFormType.allCases {
            for quality in DocumentQuality.allCases {
                documents.append(generateTestDocument(formType: formType, quality: quality))
            }
        }

        return documents
    }

    // MARK: - Private Implementation

    private static func getSampleFormText(for formType: GovernmentFormType) -> String {
        switch formType {
        case .sf18:
            """
            REQUEST AND AUTHORIZATION FOR JOB ANALYSIS
            SF-18 (Rev. 10-83)

            Employee Name: John A. Smith
            Employee ID: EMP123456
            Department: Information Technology
            Position Title: Systems Analyst II
            Request Date: 03/15/2024
            Supervisor Name: Jane M. Johnson
            Reason for Request: Position reclassification review

            I hereby request a job analysis for the above position.

            Supervisor Signature: _________________ Date: _______
            """

        case .sf26:
            """
            REQUEST FOR JOB ANALYSIS
            SF-26 (Rev. 05-89)

            Requestor Name: Michael R. Davis
            Organization: Federal Aviation Administration
            Job Title: Air Traffic Controller
            Analysis Type: Classification Review
            Priority Level: High
            Due Date: 04/30/2024

            This request is being submitted for official classification review.

            Authorized Official: _________________ Date: _______
            """

        case .dd1155:
            """
            REQUEST AND RECEIPT FOR ISSUE OF SUBSISTENCE
            DD FORM 1155, JUN 2003

            Service Member Name: SSgt Robert K. Wilson
            Rank/Grade: E-5
            Unit: 23rd Fighter Wing
            Request Date: 03/20/2024
            Items Requested: MRE Meals, Type A Rations
            Quantity: 50 units
            Authorizing Officer: Capt. Sarah L. Martinez

            For Official Use Only

            Signature: _________________ Date: _______
            """
        }
    }

    private static func applyQualityEffects(to text: String, quality: DocumentQuality) -> String {
        switch quality {
        case .clean:
            text
        case .damaged:
            text.replacingOccurrences(of: "a", with: "o")
                .replacingOccurrences(of: "e", with: "c")
        case .rotated, .skewed:
            text.replacingOccurrences(of: "0", with: "O")
                .replacingOccurrences(of: "1", with "l")
        case .blurry, .lowContrast:
            text.replacingOccurrences(of: "m", with: "n")
                .replacingOccurrences(of: "r", with: "n")
        case .handwritten:
            text.replacingOccurrences(of: "Smith", with: "5m1th")
                .replacingOccurrences(of: "Date", with: "Oate")
        }
    }

    private static func randomConfidence(for quality: DocumentQuality) -> Double {
        let range = quality.confidenceRange
        return Double.random(in: range)
    }

    private static func getAppliedFilters(for quality: DocumentQuality) -> [String] {
        switch quality {
        case .clean:
            ["noise_reduction", "contrast_enhancement"]
        case .damaged:
            ["edge_enhancement", "fill_gaps", "noise_reduction"]
        case .rotated:
            ["rotation_correction", "contrast_enhancement"]
        case .blurry:
            ["sharpening", "deconvolution", "contrast_enhancement"]
        case .lowContrast:
            ["histogram_equalization", "gamma_correction"]
        case .skewed:
            ["perspective_correction", "rotation_correction"]
        case .handwritten:
            ["morphological_closing", "contrast_enhancement", "noise_reduction"]
        }
    }

    private static func createMinimalJPEGData(width _: Int, height _: Int, quality: DocumentQuality) -> Data {
        // Create minimal valid JPEG data for testing
        // In production, this would generate actual document images
        var jpegData = Data([
            0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46,
            0x49, 0x46, 0x00, 0x01, 0x01, 0x01, 0x00, 0x48,
            0x00, 0x48, 0x00, 0x00,
        ])

        // Add some mock content to simulate different qualities
        let contentSize = quality == .clean ? 1024 : 512
        let mockContent = Data(repeating: 0x80, count: contentSize)
        jpegData.append(mockContent)

        // JPEG end marker
        jpegData.append(Data([0xFF, 0xD9]))

        return jpegData
    }
}

// MARK: - Extensions for Test Data Models

public extension ScannedDocument {
    /// Convenience initializer for testing
    /// - Parameters:
    ///   - id: Document identifier
    ///   - pages: Scanned pages
    ///   - documentType: Type of document (optional)
    ///   - createdAt: Creation timestamp (optional)
    ///   - confidence: Overall confidence score (optional)
    init(
        id: UUID,
        pages: [ScannedPage],
        documentType: String? = nil,
        createdAt: Date? = nil,
        confidence: Double? = nil
    ) {
        self.id = id
        self.pages = pages
        self.documentType = documentType
        self.createdAt = createdAt ?? Date()
        self.confidence = confidence ?? 0.8
    }
}

public extension ScannedPage {
    /// Convenience initializer for testing
    /// - Parameters:
    ///   - id: Page identifier
    ///   - imageData: Raw image data
    ///   - pageNumber: Page number
    ///   - processingResult: Processing result (optional)
    ///   - extractedText: OCR extracted text (optional)
    ///   - confidence: Page confidence score (optional)
    init(
        id: UUID,
        imageData: Data,
        pageNumber: Int,
        processingResult: DocumentImageProcessor.ProcessingResult? = nil,
        extractedText: String? = nil,
        confidence: Double? = nil
    ) {
        self.id = id
        self.imageData = imageData
        self.pageNumber = pageNumber
        self.processingResult = processingResult
        self.extractedText = extractedText
        self.confidence = confidence ?? 0.8
    }
}
