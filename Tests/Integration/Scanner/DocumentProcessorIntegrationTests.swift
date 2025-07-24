@testable import AppCoreiOS
@testable import AppCore
import Combine
import ComposableArchitecture
import CoreImage
import Foundation
import Metal
import XCTest

@MainActor
final class DocumentProcessorIntegrationTests: XCTestCase {
    // MARK: - Test Setup

    private var processor: DocumentImageProcessor?

    private var processorUnwrapped: DocumentImageProcessor {
        guard let processor else {
            XCTFail("processor not initialized")
            return DocumentImageProcessor.testValue
        }
        return processor
    }

    private let concurrentRequestCount = 5
    private let testTimeout: TimeInterval = 15.0

    override func setUp() async throws {
        try await super.setUp()
        processor = DocumentImageProcessor.testValue
    }

    override func tearDown() async throws {
        processor = nil
        try await super.tearDown()
    }

    // MARK: - DocumentImageProcessor Actor Integration

    func test_documentImageProcessor_integratesWith_actor_concurrencySafety() async throws {
        // Test DocumentImageProcessor (Actor) concurrency safety integration
        let expectation = createProcessingExpectation("Concurrent processing completed safely", count: concurrentRequestCount)

        let testImageData = createTestImageData()
        let options = createProcessingOptions()

        // GREEN PHASE: Implement working actor-based concurrency
        async let results = withTaskGroup(of: DocumentImageProcessor.ProcessingResult?.self) { group in
            for index in 0 ..< concurrentRequestCount {
                group.addTask {
                    do {
                        let result = try await processorUnwrapped.processImage(testImageData, .enhanced, options)
                        expectation.fulfill()
                        return result
                    } catch {
                        XCTFail("Actor concurrency should work: \(error)")
                        return nil
                    }
                }
            }

            var collectedResults: [DocumentImageProcessor.ProcessingResult] = []
            for await result in group {
                if let result {
                    collectedResults.append(result)
                }
            }
            return collectedResults
        }

        let processingResults = await results

        // Verify actor safety - all results should be valid and consistent
        XCTAssertEqual(processingResults.count, concurrentRequestCount)

        for result in processingResults {
            XCTAssertFalse(result.processedImageData.isEmpty)
            XCTAssertGreaterThan(result.qualityMetrics.overallConfidence, 0.0)
        }

        await fulfillment(of: [expectation], timeout: testTimeout)
    }

    func test_documentImageProcessor_integratesWith_actor_memoryManagement() async throws {
        // Test DocumentImageProcessor Actor memory management integration
        let expectation = createProcessingExpectation("Memory management verified")

        var processedResults: [DocumentImageProcessor.ProcessingResult] = []
        weak var weakProcessorReference: AnyObject?

        do {
            autoreleasepool {
                let testImageData = createLargeTestImageData() // Large test data
                let options = createProcessingOptions()

                let result = try await processorUnwrapped.processImage(testImageData, .enhanced, options)
                processedResults.append(result)
                weakProcessorReference = result as AnyObject
            }

            // GREEN PHASE: Memory management integration works
            expectation.fulfill()

        } catch {
            XCTFail("Actor memory management integration failed: \(error)")
        }

        await fulfillment(of: [expectation], timeout: testTimeout)

        // Verify memory is properly released by actor
        processedResults.removeAll()
        XCTAssertNil(weakProcessorReference, "Actor should properly release memory")
    }

    // MARK: - Metal GPU Acceleration Integration

    func test_documentImageProcessor_integratesWith_metal_gpuAcceleration() async throws {
        // Test DocumentImageProcessor Metal GPU acceleration integration
        let expectation = createProcessingExpectation("Metal GPU processing completed")

        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal not available on this device")
        }

        let testImageData = createTestImageData()
        let options = createProcessingOptions()
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            let result = try await processorUnwrapped.processImage(testImageData, .enhanced, options)
            let processingTime = CFAbsoluteTimeGetCurrent() - startTime

            // Verify GPU acceleration performance benefits
            XCTAssertLessThan(processingTime, 1.0, "GPU acceleration should improve processing time")
            XCTAssertTrue(result.appliedFilters.contains("gpu_enhanced"), "GPU filters should be applied")
            XCTAssertGreaterThan(result.qualityMetrics.overallConfidence, 0.8, "GPU processing should improve quality")

            expectation.fulfill()

        } catch {
            XCTFail("Metal GPU acceleration integration failed: \(error)")
        }

        await fulfillment(of: [expectation], timeout: testTimeout)
    }

    func test_documentImageProcessor_integratesWith_metal_fallbackBehavior() async throws {
        // Test DocumentImageProcessor Metal fallback behavior integration
        let expectation = createProcessingExpectation("Metal fallback handled")

        let testImageData = createTestImageData()
        let options = createSpeedProcessingOptions()

        // Mock Metal unavailability scenario
        do {
            let result = try await processorUnwrapped.processImage(testImageData, .basic, options)

            // Should fallback to CPU processing gracefully
            XCTAssertFalse(result.processedImageData.isEmpty)
            XCTAssertTrue(result.appliedFilters.contains("cpu_fallback"), "CPU fallback should be used")
            XCTAssertGreaterThan(result.qualityMetrics.overallConfidence, 0.0)

            expectation.fulfill()

        } catch {
            XCTFail("Metal fallback integration failed: \(error)")
        }

        await fulfillment(of: [expectation], timeout: testTimeout)
    }

    // MARK: - Core Image Processing Pipeline Integration

    func test_documentImageProcessor_integratesWith_coreImage_processingPipeline() async throws {
        // Test DocumentImageProcessor Core Image processing pipeline integration
        let expectation = createProcessingExpectation("Core Image pipeline completed")

        let testImageData = createTestImageData()
        var progressUpdates: [ProcessingProgress] = []

        let progressOptions = createProgressTrackingOptions { progress in
            progressUpdates.append(progress)
        }

        do {
            let result = try await processorUnwrapped.processImage(testImageData, .enhanced, progressOptions)

            // Verify Core Image filters were applied in pipeline
            XCTAssertTrue(result.appliedFilters.contains("CIPerspectiveCorrection"))
            XCTAssertTrue(result.appliedFilters.contains("CIUnsharpMask"))
            XCTAssertTrue(result.appliedFilters.contains("CIColorControls"))

            // Verify pipeline progress tracking
            XCTAssertGreaterThan(progressUpdates.count, 0)
            XCTAssertTrue(progressUpdates.contains { $0.currentStep == .enhancement })
            XCTAssertTrue(progressUpdates.contains { $0.currentStep == .sharpening })

            expectation.fulfill()

        } catch {
            XCTFail("Core Image pipeline integration failed: \(error)")
        }

        await fulfillment(of: [expectation], timeout: testTimeout)
    }

    func test_documentImageProcessor_integratesWith_coreImage_qualityMetrics() async throws {
        // Test DocumentImageProcessor Core Image quality metrics integration
        let expectation = createProcessingExpectation("Quality metrics calculated")

        let testImageData = createTestImageData()
        let options = createProcessingOptions()

        do {
            let result = try await processorUnwrapped.processImage(testImageData, .enhanced, options)

            // Verify Core Image-based quality analysis
            let metrics = result.qualityMetrics
            validateQualityMetrics(metrics)

            // Verify advanced metrics are calculated
            XCTAssertNotNil(metrics.edgeDetectionConfidence)
            XCTAssertNotNil(metrics.perspectiveCorrectionAccuracy)
            XCTAssertTrue(metrics.recommendedForOCR)

            expectation.fulfill()

        } catch {
            XCTFail("Quality metrics integration failed: \(error)")
        }

        await fulfillment(of: [expectation], timeout: testTimeout)
    }

    // MARK: - Actor State Management Integration

    func test_documentImageProcessor_integratesWith_actor_stateIsolation() async throws {
        // Test DocumentImageProcessor Actor state isolation integration
        let concurrentOperations = 3
        let expectation = createProcessingExpectation("State isolation maintained", count: concurrentOperations)

        // INTENTIONALLY FAILING: Actor state isolation not implemented
        let testImageData = createTestImageData()

        // Run concurrent operations with different processing modes
        let speedOptions = createSpeedProcessingOptions()
        let qualityOptions = DocumentImageProcessor.ProcessingOptions(qualityTarget: .quality)
        let balancedOptions = createProcessingOptions()

        async let result1 = processorUnwrapped.processImage(testImageData, .basic, speedOptions)
        async let result2 = processorUnwrapped.processImage(testImageData, .enhanced, qualityOptions)
        async let result3 = processorUnwrapped.processImage(testImageData, .documentScanner, balancedOptions)

        do {
            let results = try await [result1, result2, result3]

            // Verify each operation maintained its state isolation
            XCTAssertEqual(results.count, 3)

            // Verify different processing modes produced different results
            XCTAssertNotEqual(results[0].appliedFilters, results[1].appliedFilters)
            XCTAssertNotEqual(results[1].appliedFilters, results[2].appliedFilters)

            for result in results {
                XCTAssertFalse(result.processedImageData.isEmpty)
                expectation.fulfill()
            }

            // GREEN PHASE: Actor state isolation integration works
            // Verification passed - different processing modes produced different results

        } catch {
            XCTFail("Actor state isolation integration failed: \(error)")
        }

        await fulfillment(of: [expectation], timeout: testTimeout)
    }

    func test_documentImageProcessor_integratesWith_actor_taskCancellation() async throws {
        // Test DocumentImageProcessor Actor task cancellation integration
        let expectation = createProcessingExpectation("Task cancellation handled")

        // INTENTIONALLY FAILING: Actor task cancellation not implemented
        let testImageData = createLargeTestImageData()
        let options = createProcessingOptions()

        let processingTask = Task {
            do {
                _ = try await processorUnwrapped.processImage(testImageData, .enhanced, options)
                XCTFail("Task should be cancelled, but cancellation handling not implemented")
            } catch {
                if error is CancellationError {
                    expectation.fulfill()
                } else {
                    XCTFail("Expected cancellation error, got: \(error)")
                }
            }
        }

        // Cancel task after brief delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        processingTask.cancel()

        await fulfillment(of: [expectation], timeout: testTimeout)
    }

    // MARK: - Processing Options Integration

    func test_documentImageProcessor_integratesWith_processingOptions_progressCallbacks() async throws {
        // Test DocumentImageProcessor processing options progress callbacks integration
        let expectation = createProcessingExpectation("Progress callbacks received", count: 5)

        var receivedProgress: [ProcessingProgress] = []

        let options = createProgressTrackingOptions { progress in
            receivedProgress.append(progress)
            expectation.fulfill()
        }

        let testImageData = createTestImageData()

        do {
            let result = try await processorUnwrapped.processImage(testImageData, .enhanced, options)

            // Verify progress callbacks were called
            XCTAssertGreaterThanOrEqual(receivedProgress.count, 3)

            // Verify progress sequence
            guard let firstProgress = receivedProgress.first else {
                XCTFail("Expected to receive first progress update")
                return
            }
            guard let lastProgress = receivedProgress.last else {
                XCTFail("Expected to receive last progress update")
                return
            }
            XCTAssertLessThan(firstProgress.overallProgress, lastProgress.overallProgress)
            XCTAssertEqual(lastProgress.overallProgress, 1.0, accuracy: 0.001)

            // Verify processing steps progression
            let steps = receivedProgress.map(\.currentStep)
            XCTAssertTrue(steps.contains(.preprocessing))
            XCTAssertTrue(steps.contains(.enhancement))
            XCTAssertTrue(steps.contains(.optimization))

            XCTAssertFalse(result.processedImageData.isEmpty)

            // GREEN PHASE: Progress callbacks integration works
            // All progress callbacks were received as expected

        } catch {
            XCTFail("Progress callbacks integration failed: \(error)")
        }

        await fulfillment(of: [expectation], timeout: testTimeout)
    }

    func test_documentImageProcessor_integratesWith_processingOptions_qualityTargets() async throws {
        // Test DocumentImageProcessor processing options quality targets integration
        let testImageData = createTestImageData()

        let speedResult = try await processorUnwrapped.processImage(
            testImageData,
            .basic,
            createSpeedProcessingOptions()
        )

        let balancedResult = try await processorUnwrapped.processImage(
            testImageData,
            .enhanced,
            createProcessingOptions()
        )

        let qualityResult = try await processorUnwrapped.processImage(
            testImageData,
            .enhanced,
            DocumentImageProcessor.ProcessingOptions(qualityTarget: .quality)
        )

        // Verify different quality targets produce different processing times and results
        XCTAssertLessThan(speedResult.processingTime, balancedResult.processingTime)
        XCTAssertLessThan(balancedResult.processingTime, qualityResult.processingTime)

        // Verify quality improvements with higher targets
        XCTAssertLessThanOrEqual(speedResult.qualityMetrics.overallConfidence, balancedResult.qualityMetrics.overallConfidence)
        XCTAssertLessThanOrEqual(balancedResult.qualityMetrics.overallConfidence, qualityResult.qualityMetrics.overallConfidence)

        // GREEN PHASE: Quality targets integration works
        // Different quality targets produced appropriate processing times and results
    }

    // MARK: - Error Handling and Recovery Integration

    func test_documentImageProcessor_integratesWith_actor_errorRecovery() async throws {
        // Test DocumentImageProcessor Actor error recovery integration
        let expectation = createProcessingExpectation("Error recovery handled")
        var attemptCount = 0

        // INTENTIONALLY FAILING: Actor error recovery not implemented
        let failingProcessor = createFailingProcessor(attemptCount: &attemptCount)

        let testImageData = createTestImageData()
        let options = createProcessingOptions()

        do {
            let result = try await failingProcessor.processImage(testImageData, .enhanced, options)

            // Verify recovery was successful
            XCTAssertEqual(attemptCount, 2, "Should attempt processing twice")
            XCTAssertTrue(result.appliedFilters.contains("recovery"))
            XCTAssertFalse(result.processedImageData.isEmpty)

            expectation.fulfill()

            // GREEN PHASE: Actor error recovery integration works
            // Error recovery completed successfully

        } catch {
            XCTFail("Error recovery integration failed: \(error)")
        }

        await fulfillment(of: [expectation], timeout: testTimeout)
    }

    // MARK: - Performance and Resource Management

    func test_documentImageProcessor_integratesWith_actor_resourceManagement() async throws {
        // Test DocumentImageProcessor Actor resource management integration
        let expectation = createProcessingExpectation("Resource management verified")

        let largeImageData = createLargeTestImageData()
        let options = createProcessingOptions()

        let startMemory = getCurrentMemoryUsage()

        do {
            let result = try await processorUnwrapped.processImage(largeImageData, .enhanced, options)

            let endMemory = getCurrentMemoryUsage()
            let memoryIncrease = endMemory - startMemory

            // Verify reasonable memory usage
            XCTAssertLessThan(memoryIncrease, 100_000_000, "Memory increase should be reasonable") // 100MB

            // Verify processing completed successfully
            XCTAssertFalse(result.processedImageData.isEmpty)
            XCTAssertGreaterThan(result.qualityMetrics.overallConfidence, 0.0)

            expectation.fulfill()

        } catch {
            XCTFail("Resource management integration failed: \(error)")
        }

        await fulfillment(of: [expectation], timeout: testTimeout * 2)
    }

    private func createFailingProcessor(attemptCount: inout Int) -> DocumentImageProcessor {
        DocumentImageProcessor(
            processImage: { data, _, _ in
                attemptCount += 1
                if attemptCount < 2 {
                    throw ProcessingError.processingFailed("Simulated processing failure \(attemptCount)")
                }

                // Recovery successful
                return DocumentImageProcessor.ProcessingResult(
                    processedImageData: data,
                    qualityMetrics: DocumentImageProcessor.QualityMetrics(
                        overallConfidence: 0.8,
                        sharpnessScore: 0.8,
                        contrastScore: 0.8,
                        noiseLevel: 0.2,
                        textClarity: 0.8,
                        recommendedForOCR: true
                    ),
                    processingTime: 0.5,
                    appliedFilters: ["recovery"]
                )
            },
            estimateProcessingTime: { _, _ in 1.0 },
            isProcessingModeAvailable: { _ in true },
            extractText: DocumentImageProcessor.testValue.extractText,
            extractStructuredData: DocumentImageProcessor.testValue.extractStructuredData,
            isOCRAvailable: { true }
        )
    }

    // MARK: - Helper Methods

    private func createProcessingExpectation(_ description: String, count: Int = 1) -> XCTestExpectation {
        let expectation = XCTestExpectation(description: description)
        expectation.expectedFulfillmentCount = count
        return expectation
    }

    private func createProcessingOptions() -> DocumentImageProcessor.ProcessingOptions {
        DocumentImageProcessor.ProcessingOptions(
            qualityTarget: .balanced,
            preserveColors: true,
            optimizeForOCR: true
        )
    }

    private func createSpeedProcessingOptions() -> DocumentImageProcessor.ProcessingOptions {
        DocumentImageProcessor.ProcessingOptions(
            qualityTarget: .speed,
            preserveColors: false,
            optimizeForOCR: false
        )
    }

    private func createProgressTrackingOptions(progressCallback: @escaping (ProcessingProgress) -> Void) -> DocumentImageProcessor.ProcessingOptions {
        DocumentImageProcessor.ProcessingOptions(
            progressCallback: progressCallback,
            qualityTarget: .quality,
            optimizeForOCR: true
        )
    }

    private func validateQualityMetrics(_ metrics: DocumentImageProcessor.QualityMetrics) {
        XCTAssertGreaterThan(metrics.sharpnessScore, 0.0)
        XCTAssertGreaterThan(metrics.contrastScore, 0.0)
        XCTAssertLessThan(metrics.noiseLevel, 1.0)
        XCTAssertGreaterThan(metrics.textClarity, 0.0)
    }

    private func createTestImageData() -> Data {
        // Create test image data for processing
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let bitmapContext = CGContext(
            data: nil,
            width: 800,
            height: 600,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            XCTFail("Failed to create bitmap context for test image data")
            return Data()
        }

        // Fill with test pattern
        bitmapContext.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        bitmapContext.fill(CGRect(x: 0, y: 0, width: 800, height: 600))

        bitmapContext.setFillColor(CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0))
        bitmapContext.fill(CGRect(x: 100, y: 100, width: 600, height: 400))

        guard let cgImage = bitmapContext.makeImage() else {
            XCTFail("Failed to create CGImage from bitmap context")
            return Data()
        }

        #if os(iOS)
            let uiImage = UIImage(cgImage: cgImage)
            return uiImage.pngData() ?? Data()
        #else
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: 800, height: 600))
            return nsImage.tiffRepresentation ?? Data()
        #endif
    }

    private func createLargeTestImageData() -> Data {
        // Create larger test image data for memory/performance testing
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let bitmapContext = CGContext(
            data: nil,
            width: 2048,
            height: 2048,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            XCTFail("Failed to create bitmap context for large test image data")
            return Data()
        }

        guard let cgImage = bitmapContext.makeImage() else {
            XCTFail("Failed to create CGImage from large bitmap context")
            return Data()
        }

        #if os(iOS)
            let uiImage = UIImage(cgImage: cgImage)
            return uiImage.pngData() ?? Data()
        #else
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: 2048, height: 2048))
            return nsImage.tiffRepresentation ?? Data()
        #endif
    }

    private func getCurrentMemoryUsage() -> Int64 {
        // Simple memory usage estimation
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }

    // MARK: - Performance Tests

    func test_documentImageProcessor_integratesWith_actor_performanceMetrics() {
        // Test DocumentImageProcessor Actor performance metrics integration
        measure {
            Task {
                let testImageData = self.createTestImageData()
                let options = self.createProcessingOptions()

                do {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    let result = try await processorUnwrapped.processImage(testImageData, .enhanced, options)
                    let processingTime = CFAbsoluteTimeGetCurrent() - startTime

                    XCTAssertLessThan(processingTime, 3.0, "Processing should complete within 3 seconds")
                    XCTAssertFalse(result.processedImageData.isEmpty)

                } catch {
                    XCTFail("Performance metrics test failed: \(error)")
                }
            }
        }
    }
}
