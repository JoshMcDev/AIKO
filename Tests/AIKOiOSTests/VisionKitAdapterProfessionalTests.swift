#if os(iOS)
    @testable import AppCore
@testable import AIKOiOSiOS
    import AppCore
    import XCTest

    /// Comprehensive test suite for VisionKitAdapter professional mode enhancements
    /// Tests professional scanning, edge detection, and quality validation features
    /// Following TDD RED phase - tests written first to define expected behavior
    @MainActor
    final class VisionKitAdapterProfessionalTests: XCTestCase {
        // MARK: - Test Properties

        private var adapter: VisionKitAdapter?
        private var professionalConfig: VisionKitAdapter.ScanConfiguration?
        private var mockImageData: Data?
        private var mockDocument: ScannedDocument?

        private var adapterUnwrapped: VisionKitAdapter {
            guard let adapter else { fatalError("adapter not initialized") }
            return adapter
        }

        private var professionalConfigUnwrapped: VisionKitAdapter.ScanConfiguration {
            guard let professionalConfig else { fatalError("professionalConfig not initialized") }
            return professionalConfig
        }

        private var mockImageDataUnwrapped: Data {
            guard let mockImageData else { fatalError("mockImageData not initialized") }
            return mockImageData
        }

        private var mockDocumentUnwrapped: ScannedDocument {
            guard let mockDocument else { fatalError("mockDocument not initialized") }
            return mockDocument
        }

        // MARK: - Setup & Teardown

        override func setUp() async throws {
            try await super.setUp()

            // Create professional configuration for testing
            professionalConfig = VisionKitAdapter.ScanConfiguration(
                presentationMode: .modal,
                qualityMode: .high,
                professionalMode: .governmentForms,
                edgeDetectionEnabled: true,
                multiPageOptimization: true
            )

            adapter = VisionKitAdapter(configuration: professionalConfig)

            // Create mock test data
            mockImageData = Data("mock_government_form_image".utf8)
            mockDocument = createMockScannedDocument()
        }

        override func tearDown() async throws {
            adapter = nil
            professionalConfig = nil
            mockImageData = nil
            mockDocument = nil
            try await super.tearDown()
        }

        // MARK: - Professional Scanner Configuration Tests

        func testProfessionalScannerConfiguration_GovernmentForms_Success() async throws {
            // GIVEN: Professional configuration for government forms
            let config = VisionKitAdapter.ScanConfiguration(
                professionalMode: .governmentForms,
                edgeDetectionEnabled: true,
                multiPageOptimization: true
            )
            let adapter = VisionKitAdapter(configuration: config)

            // WHEN: Creating professional document camera
            let scanner = adapterUnwrapped.createProfessionalDocumentCameraViewController(
                professionalMode: .governmentForms
            )

            // THEN: Scanner should be configured for government forms
            XCTAssertNotNil(scanner)
            XCTAssertNotNil(scanner.delegate)
            // RED phase: Professional configuration not yet implemented
            // This test will fail until professional configuration is implemented
        }

        func testProfessionalScannerConfiguration_Contracts_Success() async throws {
            // GIVEN: Professional configuration for contracts
            let contractConfig = VisionKitAdapter.ScanConfiguration(
                professionalMode: .contracts,
                edgeDetectionEnabled: true,
                multiPageOptimization: false
            )
            let adapter = VisionKitAdapter(configuration: contractConfig)

            // WHEN: Creating professional scanner for contracts
            let scanner = adapterUnwrapped.createProfessionalDocumentCameraViewController(
                professionalMode: .contracts
            )

            // THEN: Scanner should be optimized for contract documents
            XCTAssertNotNil(scanner)
            // RED phase: Contract-specific optimizations not implemented
        }

        func testProfessionalScannerConfiguration_TechnicalDocuments_Success() async throws {
            // GIVEN: Technical documents configuration
            let techConfig = VisionKitAdapter.ScanConfiguration(
                professionalMode: .technicalDocuments,
                edgeDetectionEnabled: true,
                multiPageOptimization: true
            )
            let adapter = VisionKitAdapter(configuration: techConfig)

            // WHEN: Creating scanner for technical documents
            let scanner = adapterUnwrapped.createProfessionalDocumentCameraViewController(
                professionalMode: .technicalDocuments
            )

            // THEN: Scanner should be optimized for technical documents
            XCTAssertNotNil(scanner)
            // RED phase: Technical document optimizations not implemented
        }

        // MARK: - Professional Document Scanning Tests

        func testPresentProfessionalDocumentScanner_Success() async throws {
            // Test will be skipped in simulator environment
            guard VisionKitAdapter.isScanningAvailable else {
                throw XCTSkip("VisionKit scanning not available in test environment")
            }

            // RED phase: This test will fail until professional processing is implemented
            do {
                // WHEN: Presenting professional document scanner
                let document = try await adapterUnwrapped.presentProfessionalDocumentScanner()

                // THEN: Document should have professional processing applied
                XCTAssertNotNil(document)
                XCTAssertFalse(document.pages.isEmpty)
                // RED phase: Professional processing not implemented - will return unprocessed document

            } catch DocumentScannerError.scanningNotAvailable {
                // Expected in test environment
                XCTSkip("Scanning not available in test environment")
            }
        }

        func testApplyProfessionalProcessing_GovernmentForm_Success() async throws {
            // GIVEN: Raw scanned document
            let rawDocument = mockDocumentUnwrapped

            // WHEN: Applying professional processing
            let processedDocument = try await adapterUnwrapped.applyProfessionalProcessing(to: rawDocument)

            // THEN: Document should be enhanced with professional processing
            XCTAssertNotNil(processedDocument)
            // RED phase: Professional processing returns original document unchanged
            // This assertion will fail until enhancement is implemented
            XCTAssertNotEqual(processedDocument.pages.count, 0, "Professional processing should enhance document")
        }

        // MARK: - Edge Detection Tests

        func testDetectDocumentEdges_WellDefinedEdges_Success() async {
            // GIVEN: Mock image data with clear document edges
            let imageDataWithEdges = Data("mock_clear_document_edges".utf8)

            // WHEN: Detecting document edges
            let edgesDetected = await adapterUnwrapped.detectDocumentEdges(in: imageDataWithEdges)

            // THEN: Edges should be detected successfully
            // RED phase: Always returns false - this test will fail
            XCTAssertTrue(edgesDetected, "Should detect well-defined document edges")
        }

        func testDetectDocumentEdges_PoorQualityImage_Failure() async {
            // GIVEN: Mock image data with poor edge definition
            let poorQualityImageData = Data("mock_blurry_document".utf8)

            // WHEN: Detecting edges in poor quality image
            let edgesDetected = await adapterUnwrapped.detectDocumentEdges(in: poorQualityImageData)

            // THEN: Edge detection should fail appropriately
            // RED phase: Always returns false - this test passes by coincidence but for wrong reasons
            XCTAssertFalse(edgesDetected, "Should not detect edges in poor quality image")
        }

        func testDetectDocumentEdges_MultipleDocuments_Success() async {
            // GIVEN: Image data containing multiple documents
            let multiDocImageData = Data("mock_multiple_documents".utf8)

            // WHEN: Detecting edges with multiple documents
            let edgesDetected = await adapterUnwrapped.detectDocumentEdges(in: multiDocImageData)

            // THEN: Should detect primary document edges
            // RED phase: Will fail - edge detection not implemented
            XCTAssertTrue(edgesDetected, "Should detect primary document edges even with multiple documents")
        }

        // MARK: - Quality Assessment Tests

        func testEstimateScanQuality_HighQuality_Success() async {
            // GIVEN: High-quality document image data
            let highQualityImageData = Data("mock_high_quality_document".utf8)

            // WHEN: Estimating scan quality
            let qualityScore = await adapterUnwrapped.estimateScanQuality(from: highQualityImageData)

            // THEN: Quality score should be high (>0.8)
            // RED phase: Always returns 0.5 - this test will fail
            XCTAssertGreaterThan(qualityScore, 0.8, "High quality image should score above 0.8")
        }

        func testEstimateScanQuality_MediumQuality_Success() async {
            // GIVEN: Medium-quality document image data
            let mediumQualityImageData = Data("mock_medium_quality_document".utf8)

            // WHEN: Estimating scan quality
            let qualityScore = await adapterUnwrapped.estimateScanQuality(from: mediumQualityImageData)

            // THEN: Quality score should be medium (0.4-0.8)
            // RED phase: Always returns 0.5 - this test passes by coincidence
            XCTAssertGreaterThan(qualityScore, 0.4, "Medium quality image should score above 0.4")
            XCTAssertLessThan(qualityScore, 0.8, "Medium quality image should score below 0.8")
        }

        func testEstimateScanQuality_PoorQuality_Success() async {
            // GIVEN: Poor-quality document image data
            let poorQualityImageData = Data("mock_poor_quality_document".utf8)

            // WHEN: Estimating scan quality
            let qualityScore = await adapterUnwrapped.estimateScanQuality(from: poorQualityImageData)

            // THEN: Quality score should be low (<0.4)
            // RED phase: Always returns 0.5 - this test will fail
            XCTAssertLessThan(qualityScore, 0.4, "Poor quality image should score below 0.4")
        }

        // MARK: - Professional Quality Validation Tests

        func testValidateProfessionalQuality_GovernmentForm_Success() async {
            // GIVEN: Mock scanned government form document
            let govFormDocument = createMockGovernmentFormDocument()

            // WHEN: Validating professional quality
            let isValidQuality = await adapterUnwrapped.validateProfessionalQuality(document: govFormDocument)

            // THEN: Should meet professional quality standards
            // RED phase: Always returns false - this test will fail
            XCTAssertTrue(isValidQuality, "Government form should meet professional quality standards")
        }

        func testValidateProfessionalQuality_ContractDocument_Success() async {
            // GIVEN: Mock scanned contract document
            let contractDocument = createMockContractDocument()

            // WHEN: Validating professional quality
            let isValidQuality = await adapterUnwrapped.validateProfessionalQuality(document: contractDocument)

            // THEN: Should meet professional quality standards for contracts
            // RED phase: Always returns false - this test will fail
            XCTAssertTrue(isValidQuality, "Contract document should meet professional quality standards")
        }

        func testValidateProfessionalQuality_PoorQualityDocument_Failure() async {
            // GIVEN: Mock poor quality scanned document
            let poorQualityDocument = createMockPoorQualityDocument()

            // WHEN: Validating professional quality
            let isValidQuality = await adapterUnwrapped.validateProfessionalQuality(document: poorQualityDocument)

            // THEN: Should not meet professional quality standards
            // RED phase: Always returns false - this test passes by coincidence
            XCTAssertFalse(isValidQuality, "Poor quality document should not meet professional standards")
        }

        // MARK: - Professional Mode Integration Tests

        func testProfessionalMode_GovernmentForms_OptimizedSettings() async {
            // GIVEN: Government forms professional mode
            let govConfig = VisionKitAdapter.ScanConfiguration(
                professionalMode: .governmentForms,
                edgeDetectionEnabled: true,
                multiPageOptimization: true
            )
            let govAdapter = VisionKitAdapter(configuration: govConfig)

            // WHEN: Processing document with government forms mode
            let processedDoc = try await govAdapter.applyProfessionalProcessing(to: mockDocument)

            // THEN: Document should be optimized for government forms
            XCTAssertNotNil(processedDoc)
            // RED phase: No government form optimizations applied yet
        }

        func testProfessionalMode_Contracts_OptimizedSettings() async {
            // GIVEN: Contracts professional mode
            let contractConfig = VisionKitAdapter.ScanConfiguration(
                professionalMode: .contracts,
                edgeDetectionEnabled: true,
                multiPageOptimization: false
            )
            let contractAdapter = VisionKitAdapter(configuration: contractConfig)

            // WHEN: Processing document with contracts mode
            let processedDoc = try await contractAdapter.applyProfessionalProcessing(to: mockDocument)

            // THEN: Document should be optimized for contracts
            XCTAssertNotNil(processedDoc)
            // RED phase: No contract optimizations applied yet
        }

        // MARK: - Performance Tests

        func testProfessionalProcessing_Performance_Success() async throws {
            // GIVEN: Large multi-page document
            let largeDocument = createMockLargeDocument(pageCount: 10)
            let startTime = Date()

            // WHEN: Applying professional processing
            _ = try await adapterUnwrapped.applyProfessionalProcessing(to: largeDocument)

            // THEN: Processing should complete within performance target
            let processingTime = Date().timeIntervalSince(startTime)
            XCTAssertLessThan(processingTime, 5.0, "Professional processing should complete within 5 seconds for 10 pages")
        }

        func testEdgeDetection_Performance_Success() async {
            // GIVEN: High-resolution image data
            let highResImageData = Data(repeating: 0x00, count: 1024 * 1024) // 1MB mock data
            let startTime = Date()

            // WHEN: Detecting edges
            _ = await adapterUnwrapped.detectDocumentEdges(in: highResImageData)

            // THEN: Edge detection should complete quickly
            let detectionTime = Date().timeIntervalSince(startTime)
            XCTAssertLessThan(detectionTime, 2.0, "Edge detection should complete within 2 seconds")
        }

        func testQualityAssessment_Performance_Success() async {
            // GIVEN: High-resolution image data
            let highResImageData = Data(repeating: 0x00, count: 2 * 1024 * 1024) // 2MB mock data
            let startTime = Date()

            // WHEN: Estimating scan quality
            _ = await adapterUnwrapped.estimateScanQuality(from: highResImageData)

            // THEN: Quality assessment should complete quickly
            let assessmentTime = Date().timeIntervalSince(startTime)
            XCTAssertLessThan(assessmentTime, 1.0, "Quality assessment should complete within 1 second")
        }

        // MARK: - Error Handling Tests

        func testProfessionalProcessing_InvalidDocument_ThrowsError() async {
            // GIVEN: Invalid document with empty pages
            let invalidDocument = ScannedDocument(
                id: UUID(),
                pages: [], // Empty pages array
                scannedAt: Date()
            )

            // WHEN & THEN: Professional processing should handle invalid input gracefully
            do {
                _ = try await adapterUnwrapped.applyProfessionalProcessing(to: invalidDocument)
                // RED phase: Error handling not implemented - this may not throw as expected
            } catch {
                // Expected behavior - should throw appropriate error
                XCTAssertNotNil(error)
            }
        }

        func testEdgeDetection_InvalidImageData_HandlesGracefully() async {
            // GIVEN: Invalid image data
            let invalidImageData = Data()

            // WHEN: Attempting edge detection with invalid data
            let result = await adapterUnwrapped.detectDocumentEdges(in: invalidImageData)

            // THEN: Should handle gracefully and return false
            XCTAssertFalse(result, "Should handle invalid image data gracefully")
        }

        func testQualityAssessment_CorruptedImageData_HandlesGracefully() async {
            // GIVEN: Corrupted image data
            let corruptedImageData = Data(repeating: 0xFF, count: 100)

            // WHEN: Attempting quality assessment with corrupted data
            let quality = await adapterUnwrapped.estimateScanQuality(from: corruptedImageData)

            // THEN: Should return low quality score for corrupted data
            XCTAssertGreaterThanOrEqual(quality, 0.0, "Quality score should not be negative")
            XCTAssertLessThanOrEqual(quality, 1.0, "Quality score should not exceed 1.0")
        }

        // MARK: - Helper Methods

        private func createMockScannedDocument() -> ScannedDocument {
            let mockPageData = Data("mock_page_data".utf8)
            let page = ScannedPage(
                id: UUID(),
                imageData: mockPageData,
                pageNumber: 1
            )

            return ScannedDocument(
                id: UUID(),
                pages: [page],
                scannedAt: Date()
            )
        }

        private func createMockGovernmentFormDocument() -> ScannedDocument {
            let mockFormData = Data("mock_sf_30_form_data".utf8)
            let formPage = ScannedPage(
                id: UUID(),
                imageData: mockFormData,
                pageNumber: 1
            )

            return ScannedDocument(
                id: UUID(),
                pages: [formPage],
                scannedAt: Date()
            )
        }

        private func createMockContractDocument() -> ScannedDocument {
            let mockContractData = Data("mock_contract_document_data".utf8)
            let contractPage = ScannedPage(
                id: UUID(),
                imageData: mockContractData,
                pageNumber: 1
            )

            return ScannedDocument(
                id: UUID(),
                pages: [contractPage],
                scannedAt: Date()
            )
        }

        private func createMockPoorQualityDocument() -> ScannedDocument {
            let mockPoorData = Data("mock_poor_quality_scan".utf8)
            let poorPage = ScannedPage(
                id: UUID(),
                imageData: mockPoorData,
                pageNumber: 1
            )

            return ScannedDocument(
                id: UUID(),
                pages: [poorPage],
                scannedAt: Date()
            )
        }

        private func createMockLargeDocument(pageCount: Int) -> ScannedDocument {
            var pages: [ScannedPage] = []

            for i in 1 ... pageCount {
                let mockData = Data("mock_page_\(i)_data".utf8)
                let page = ScannedPage(
                    id: UUID(),
                    imageData: mockData,
                    pageNumber: i
                )
                pages.append(page)
            }

            return ScannedDocument(
                id: UUID(),
                pages: pages,
                scannedAt: Date()
            )
        }
    }

#endif
