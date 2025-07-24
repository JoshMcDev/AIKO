#if os(iOS)
    import Accelerate
    import AppCore
    @preconcurrency import CoreImage
    import Foundation
    import os
    import UIKit
    import Vision

    // Note: Use explicit CoreGraphics.CGRect/CGSize where needed to resolve ambiguity

    // MARK: - iOS Document Image Processor Implementation

    public extension DocumentImageProcessor {
        static let live: Self = {
            let processor = LiveDocumentImageProcessor()

            return Self(
                processImage: { imageData, mode, options in
                    try await processor.processImage(imageData, mode: mode, options: options)
                },
                estimateProcessingTime: { imageData, mode in
                    try await processor.estimateProcessingTime(imageData, mode: mode)
                },
                isProcessingModeAvailable: { mode in
                    processor.isProcessingModeAvailable(mode)
                },
                extractText: { imageData, options in
                    try await processor.extractText(imageData, options: options)
                },
                extractStructuredData: { imageData, documentType, options in
                    try await processor.extractStructuredData(imageData, documentType: documentType, options: options)
                },
                isOCRAvailable: {
                    processor.isOCRAvailable()
                }
            )
        }()
    }

    // MARK: - Progress Tracker
    
    private final class ProgressTracker: Sendable {
        private let totalSteps: Int
        private let startTime: CFAbsoluteTime
        private let options: DocumentImageProcessor.ProcessingOptions
        private let currentStepIndex = OSAllocatedUnfairLock(initialState: 0)
        
        init(totalSteps: Int, startTime: CFAbsoluteTime, options: DocumentImageProcessor.ProcessingOptions) {
            self.totalSteps = totalSteps
            self.startTime = startTime
            self.options = options
        }
        
        func makeUpdateProgress() -> @Sendable (ProcessingStep, Double) -> Void {
            { [weak self] step, stepProgress in
                guard let self = self else { return }
                
                let currentIndex = self.currentStepIndex.withLock { index in
                    let current = index
                    if stepProgress >= 1.0 {
                        index += 1
                    }
                    return current
                }
                
                let overallProgress = (Double(currentIndex) + stepProgress) / Double(self.totalSteps)
                let remainingTime = self.estimateRemainingTime(progress: overallProgress)
                
                self.options.progressCallback?(ProcessingProgress(
                    currentStep: step,
                    stepProgress: stepProgress,
                    overallProgress: overallProgress,
                    estimatedTimeRemaining: remainingTime
                ))
            }
        }
        
        private func estimateRemainingTime(progress: Double) -> TimeInterval? {
            guard progress > 0 else { return nil }
            let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
            let estimatedTotalTime = elapsedTime / progress
            let remainingTime = max(0, estimatedTotalTime - elapsedTime)
            return remainingTime
        }
    }

    // MARK: - Live Implementation

    private final class LiveDocumentImageProcessor: Sendable {
        private let context: CIContext
        private let documentProcessingPipeline: DocumentProcessingPipeline

        init() {
            // Create optimized CIContext for metal rendering if available
            if let metalDevice = MTLCreateSystemDefaultDevice() {
                context = CIContext(mtlDevice: metalDevice)
            } else {
                context = CIContext()
            }
            documentProcessingPipeline = DocumentProcessingPipeline()
        }

        func processImage(
            _ imageData: Data,
            mode: DocumentImageProcessor.ProcessingMode,
            options: DocumentImageProcessor.ProcessingOptions
        ) async throws -> DocumentImageProcessor.ProcessingResult {
            let startTime = CFAbsoluteTimeGetCurrent()
            var appliedFilters: [String] = []

            guard let uiImage = UIImage(data: imageData),
                  let cgImage = uiImage.cgImage
            else {
                throw ProcessingError.invalidImageData
            }

            let ciImage = CIImage(cgImage: cgImage)

            return try await performProcessing(
                ciImage: ciImage,
                mode: mode,
                options: options,
                appliedFilters: &appliedFilters,
                startTime: startTime
            )
        }

        private func performProcessing(
            ciImage: CIImage,
            mode: DocumentImageProcessor.ProcessingMode,
            options: DocumentImageProcessor.ProcessingOptions,
            appliedFilters: inout [String],
            startTime: CFAbsoluteTime
        ) async throws -> DocumentImageProcessor.ProcessingResult {
            var processedImage = ciImage
            let totalSteps = mode == .documentScanner ? 8 : (mode == .enhanced ? 6 : 3)
            
            // Create a helper to track progress without capturing mutable state
            let progressTracker = ProgressTracker(totalSteps: totalSteps, startTime: startTime, options: options)
            let updateProgress = progressTracker.makeUpdateProgress()

            // Step 1: Preprocessing
            updateProgress(.preprocessing, 0.0)
            processedImage = try performPreprocessing(processedImage, options: options)
            appliedFilters.append("preprocessing")
            updateProgress(.preprocessing, 1.0)

            // Document Scanner Mode: Edge Detection and Perspective Correction
            if mode == .documentScanner {
                let config = DocumentScannerProcessingConfig(
                    ciImage: processedImage,
                    originalImage: ciImage,
                    options: options,
                    startTime: startTime,
                    updateProgress: updateProgress
                )
                return try await performDocumentScannerProcessing(
                    config: config,
                    appliedFilters: &appliedFilters
                )
            }

            // Step 2: Basic enhancement (both modes)
            updateProgress(.enhancement, 0.0)
            processedImage = try performBasicEnhancement(processedImage, options: options)
            appliedFilters.append("basic_enhancement")
            updateProgress(.enhancement, mode == .basic ? 1.0 : 0.5)

            if mode == .enhanced {
                // Step 3: Advanced enhancement
                processedImage = try performAdvancedEnhancement(processedImage, options: options)
                appliedFilters.append("advanced_enhancement")
                updateProgress(.enhancement, 1.0)

                // Step 4: Denoising
                updateProgress(.denoising, 0.0)
                processedImage = try performDenoising(processedImage, options: options)
                appliedFilters.append("denoising")
                updateProgress(.denoising, 1.0)

                // Step 5: Advanced sharpening
                updateProgress(.sharpening, 0.0)
                processedImage = try performAdvancedSharpening(processedImage, options: options)
                appliedFilters.append("advanced_sharpening")
                updateProgress(.sharpening, 1.0)

                // Step 6: OCR optimization
                if options.optimizeForOCR {
                    updateProgress(.optimization, 0.0)
                    processedImage = try performOCROptimization(processedImage, options: options)
                    appliedFilters.append("ocr_optimization")
                    updateProgress(.optimization, 1.0)
                }
            } else {
                // Basic mode: simple sharpening
                updateProgress(.sharpening, 0.0)
                processedImage = try performBasicSharpening(processedImage, options: options)
                appliedFilters.append("basic_sharpening")
                updateProgress(.sharpening, 1.0)
            }

            // Final step: Quality analysis
            updateProgress(.qualityAnalysis, 0.0)
            let qualityMetrics = try analyzeQuality(processedImage, originalImage: ciImage)
            updateProgress(.qualityAnalysis, 1.0)

            // Convert to data
            guard let finalCGImage = context.createCGImage(processedImage, from: processedImage.extent) else {
                throw ProcessingError.processingFailed("Failed to create final image")
            }

            let finalUIImage = UIImage(cgImage: finalCGImage)
            guard let finalImageData = finalUIImage.jpegData(compressionQuality: 0.92) else {
                throw ProcessingError.processingFailed("Failed to convert to JPEG data")
            }

            let processingTime = CFAbsoluteTimeGetCurrent() - startTime

            return DocumentImageProcessor.ProcessingResult(
                processedImageData: finalImageData,
                qualityMetrics: qualityMetrics,
                processingTime: processingTime,
                appliedFilters: appliedFilters
            )
        }

        // MARK: - Processing Steps

        private func performPreprocessing(_ image: CIImage, options _: DocumentImageProcessor.ProcessingOptions) throws -> CIImage {
            var result = image

            // Correct orientation if needed
            let orientationFilter = CIFilter.straighten()
            orientationFilter.inputImage = result
            orientationFilter.angle = 0.0
            if let output = orientationFilter.outputImage {
                result = output
            }

            // Basic exposure correction
            let exposureFilter = CIFilter.exposureAdjust()
            exposureFilter.inputImage = result
            exposureFilter.ev = 0.2
            if let output = exposureFilter.outputImage {
                result = output
            }

            return result
        }

        private func performBasicEnhancement(_ image: CIImage, options: DocumentImageProcessor.ProcessingOptions) throws -> CIImage {
            var result = image

            // Contrast and brightness adjustment
            let colorFilter = CIFilter.colorControls()
            colorFilter.inputImage = result
            colorFilter.contrast = 1.3
            colorFilter.brightness = 0.1
            colorFilter.saturation = options.preserveColors ? 1.0 : 0.8
            if let output = colorFilter.outputImage {
                result = output
            }

            // Gamma adjustment for better text visibility
            let gammaFilter = CIFilter.gammaAdjust()
            gammaFilter.inputImage = result
            gammaFilter.power = 0.9
            if let output = gammaFilter.outputImage {
                result = output
            }

            return result
        }

        private func performAdvancedEnhancement(_ image: CIImage, options: DocumentImageProcessor.ProcessingOptions) throws -> CIImage {
            var result = image

            // Advanced tone mapping
            let toneFilter = CIFilter.highlightShadowAdjust()
            toneFilter.inputImage = result
            toneFilter.shadowAmount = 0.3
            toneFilter.highlightAmount = -0.2
            if let output = toneFilter.outputImage {
                result = output
            }

            // Local contrast enhancement using unsharp mask
            let unsharpFilter = CIFilter.unsharpMask()
            unsharpFilter.inputImage = result
            unsharpFilter.radius = 2.5
            unsharpFilter.intensity = 0.5
            if let output = unsharpFilter.outputImage {
                result = output
            }

            // Vibrance adjustment for better color balance
            let vibranceFilter = CIFilter.vibrance()
            vibranceFilter.inputImage = result
            vibranceFilter.amount = options.preserveColors ? 0.2 : 0.0
            if let output = vibranceFilter.outputImage {
                result = output
            }

            return result
        }

        private func performDenoising(_ image: CIImage, options _: DocumentImageProcessor.ProcessingOptions) throws -> CIImage {
            var result = image

            // Noise reduction using median filter
            let medianFilter = CIFilter.median()
            medianFilter.inputImage = result
            if let output = medianFilter.outputImage {
                result = output
            }

            // Additional noise reduction for enhanced mode
            let noiseFilter = CIFilter.noiseReduction()
            noiseFilter.inputImage = result
            noiseFilter.noiseLevel = 0.02
            noiseFilter.sharpness = 0.4
            if let output = noiseFilter.outputImage {
                result = output
            }

            return result
        }

        private func performBasicSharpening(_ image: CIImage, options _: DocumentImageProcessor.ProcessingOptions) throws -> CIImage {
            let sharpenFilter = CIFilter.sharpenLuminance()
            sharpenFilter.inputImage = image
            sharpenFilter.sharpness = 0.4

            return sharpenFilter.outputImage ?? image
        }

        private func performAdvancedSharpening(_ image: CIImage, options _: DocumentImageProcessor.ProcessingOptions) throws -> CIImage {
            var result = image

            // Multi-scale sharpening
            let sharpenFilter = CIFilter.sharpenLuminance()
            sharpenFilter.inputImage = result
            sharpenFilter.sharpness = 0.6
            if let output = sharpenFilter.outputImage {
                result = output
            }

            // Edge enhancement for text
            let edgeFilter = CIFilter.edges()
            edgeFilter.inputImage = result
            edgeFilter.intensity = 3.0
            if let output = edgeFilter.outputImage {
                // Blend with original for subtle enhancement
                let blendFilter = CIFilter.sourceOverCompositing()
                blendFilter.inputImage = output
                blendFilter.backgroundImage = result
                if let blended = blendFilter.outputImage {
                    result = blended
                }
            }

            return result
        }

        private func performOCROptimization(_ image: CIImage, options _: DocumentImageProcessor.ProcessingOptions) throws -> CIImage {
            var result = image

            // Increase contrast specifically for text recognition
            let colorFilter = CIFilter.colorControls()
            colorFilter.inputImage = result
            colorFilter.contrast = 1.5
            colorFilter.brightness = 0.05
            colorFilter.saturation = 0.0 // Convert to grayscale for better OCR
            if let output = colorFilter.outputImage {
                result = output
            }

            // Apply threshold for binary-like appearance
            let posterizeFilter = CIFilter.colorPosterize()
            posterizeFilter.inputImage = result
            posterizeFilter.levels = 6
            if let output = posterizeFilter.outputImage {
                result = output
            }

            return result
        }

        // MARK: - Document Scanner Processing

        /// Configuration for document scanner processing
        private struct DocumentScannerProcessingConfig: Sendable {
            let ciImage: CIImage
            let originalImage: CIImage
            let options: DocumentImageProcessor.ProcessingOptions
            let startTime: CFAbsoluteTime
            let updateProgress: @Sendable (ProcessingStep, Double) -> Void
        }

        private func performDocumentScannerProcessing(
            config: DocumentScannerProcessingConfig,
            appliedFilters: inout [String]
        ) async throws -> DocumentImageProcessor.ProcessingResult {
            var processedImage = config.ciImage

            // Step 2: Edge Detection
            config.updateProgress(.edgeDetection, 0.0)
            let documentProcessingResult = try await documentProcessingPipeline.processDocument(
                processedImage,
                options: config.options
            )
            processedImage = documentProcessingResult.processedImage
            appliedFilters.append("edge_detection")
            appliedFilters.append("perspective_correction")
            config.updateProgress(.perspectiveCorrection, 1.0)

            // Step 3: Enhanced processing for document scanner mode
            config.updateProgress(.enhancement, 0.0)
            processedImage = try performAdvancedEnhancement(processedImage, options: config.options)
            appliedFilters.append("advanced_enhancement")
            config.updateProgress(.enhancement, 1.0)

            // Step 4: Denoising
            config.updateProgress(.denoising, 0.0)
            processedImage = try performDenoising(processedImage, options: config.options)
            appliedFilters.append("denoising")
            config.updateProgress(.denoising, 1.0)

            // Step 5: Advanced sharpening
            config.updateProgress(.sharpening, 0.0)
            processedImage = try performAdvancedSharpening(processedImage, options: config.options)
            appliedFilters.append("advanced_sharpening")
            config.updateProgress(.sharpening, 1.0)

            // Step 6: OCR optimization (always enabled for document scanner)
            config.updateProgress(.optimization, 0.0)
            processedImage = try performOCROptimization(processedImage, options: config.options)
            appliedFilters.append("ocr_optimization")
            config.updateProgress(.optimization, 1.0)

            // Step 7: Quality analysis with enhanced metrics
            config.updateProgress(.qualityAnalysis, 0.0)
            let qualityMetrics = documentProcessingResult.qualityMetrics
            config.updateProgress(.qualityAnalysis, 1.0)

            // Convert to data
            guard let finalCGImage = context.createCGImage(processedImage, from: processedImage.extent) else {
                throw ProcessingError.processingFailed("Failed to create final image")
            }

            let finalUIImage = UIImage(cgImage: finalCGImage)
            guard let finalImageData = finalUIImage.jpegData(compressionQuality: 0.92) else {
                throw ProcessingError.processingFailed("Failed to convert to JPEG data")
            }

            let processingTime = CFAbsoluteTimeGetCurrent() - config.startTime

            return DocumentImageProcessor.ProcessingResult(
                processedImageData: finalImageData,
                qualityMetrics: qualityMetrics,
                processingTime: processingTime,
                appliedFilters: appliedFilters
            )
        }

        // MARK: - Quality Analysis

        private func analyzeQuality(_ processedImage: CIImage, originalImage _: CIImage) throws -> DocumentImageProcessor.QualityMetrics {
            // Calculate various quality metrics
            let sharpnessScore = calculateSharpness(processedImage)
            let contrastScore = calculateContrast(processedImage)
            let noiseLevel = calculateNoiseLevel(processedImage)
            let textClarity = calculateTextClarity(processedImage)

            // Overall confidence based on weighted metrics
            let overallConfidence = (
                sharpnessScore * 0.3 +
                    contrastScore * 0.25 +
                    (1.0 - noiseLevel) * 0.2 +
                    textClarity * 0.25
            )

            let recommendedForOCR = overallConfidence > 0.7 && textClarity > 0.6

            return DocumentImageProcessor.QualityMetrics(
                overallConfidence: overallConfidence,
                sharpnessScore: sharpnessScore,
                contrastScore: contrastScore,
                noiseLevel: noiseLevel,
                textClarity: textClarity,
                recommendedForOCR: recommendedForOCR
            )
        }

        private func calculateSharpness(_ image: CIImage) -> Double {
            // Use Sobel edge detection to measure sharpness
            let sobelFilter = CIFilter.convolution3X3()
            sobelFilter.inputImage = image
            sobelFilter.weights = CIVector(values: [-1, 0, 1, -2, 0, 2, -1, 0, 1], count: 9)
            sobelFilter.bias = 0.5

            guard let edgeImage = sobelFilter.outputImage else { return 0.5 }

            // Calculate average edge strength
            let stats = calculateImageStatistics(edgeImage)
            return min(1.0, stats.mean * 2.0)
        }

        private func calculateContrast(_ image: CIImage) -> Double {
            let stats = calculateImageStatistics(image)
            // Contrast as normalized standard deviation
            return min(1.0, stats.standardDeviation / 0.3)
        }

        private func calculateNoiseLevel(_ image: CIImage) -> Double {
            // Estimate noise using high-frequency components
            let highPassFilter = CIFilter.convolution3X3()
            highPassFilter.inputImage = image
            highPassFilter.weights = CIVector(values: [-1, -1, -1, -1, 8, -1, -1, -1, -1], count: 9)

            guard let noiseImage = highPassFilter.outputImage else { return 0.3 }

            let stats = calculateImageStatistics(noiseImage)
            return min(1.0, stats.standardDeviation)
        }

        private func calculateTextClarity(_ image: CIImage) -> Double {
            // Simplified text clarity assessment based on edge consistency
            let sharpness = calculateSharpness(image)
            let contrast = calculateContrast(image)

            // Text clarity correlates with both sharpness and contrast
            return sharpness * 0.6 + contrast * 0.4
        }

        private func calculateImageStatistics(_ image: CIImage) -> (mean: Double, standardDeviation: Double) {
            // Convert to grayscale for analysis
            let grayscaleFilter = CIFilter.colorControls()
            grayscaleFilter.inputImage = image
            grayscaleFilter.saturation = 0.0

            guard let grayscaleImage = grayscaleFilter.outputImage,
                  let cgImage = context.createCGImage(grayscaleImage, from: grayscaleImage.extent)
            else {
                return (mean: 0.5, standardDeviation: 0.2)
            }

            // Create a smaller sample for performance
            let sampleSize = 100
            let width = min(sampleSize, cgImage.width)
            let height = min(sampleSize, cgImage.height)

            guard let sampleCGImage = context.createCGImage(
                grayscaleImage,
                from: CGRect(x: 0, y: 0, width: width, height: height)
            ) else {
                return (mean: 0.5, standardDeviation: 0.2)
            }

            // Extract pixel data and calculate statistics
            let bytesPerPixel = 4
            let bytesPerRow = width * bytesPerPixel
            let totalBytes = height * bytesPerRow

            var pixelData = [UInt8](repeating: 0, count: totalBytes)

            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(
                      data: &pixelData,
                      width: width,
                      height: height,
                      bitsPerComponent: 8,
                      bytesPerRow: bytesPerRow,
                      space: colorSpace,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  )
            else {
                return (mean: 0.5, standardDeviation: 0.2)
            }

            context.draw(sampleCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))

            // Calculate mean
            var sum: Double = 0
            let pixelCount = width * height

            for i in stride(from: 0, to: totalBytes, by: bytesPerPixel) {
                let gray = Double(pixelData[i]) / 255.0
                sum += gray
            }

            let mean = sum / Double(pixelCount)

            // Calculate standard deviation
            var variance: Double = 0
            for i in stride(from: 0, to: totalBytes, by: bytesPerPixel) {
                let gray = Double(pixelData[i]) / 255.0
                let diff = gray - mean
                variance += diff * diff
            }

            let standardDeviation = sqrt(variance / Double(pixelCount))

            return (mean: mean, standardDeviation: standardDeviation)
        }

        // MARK: - Time Estimation

        func estimateProcessingTime(_ imageData: Data, mode: DocumentImageProcessor.ProcessingMode) async throws -> TimeInterval {
            let imageSize = Double(imageData.count)
            let megabytes = imageSize / 1_000_000.0

            // Base processing times (in seconds)
            let baseTime: TimeInterval = mode == .enhanced ? 3.0 : 0.8

            // Scale based on image size
            let sizeMultiplier = max(1.0, sqrt(megabytes))

            // Device performance factor (simplified)
            let performanceFactor = 1.0 // Could be adjusted based on device capabilities

            return baseTime * sizeMultiplier * performanceFactor
        }

        func isProcessingModeAvailable(_: DocumentImageProcessor.ProcessingMode) -> Bool {
            // Both modes are available on iOS with Core Image
            true
        }

        // MARK: - OCR Methods

        func extractText(_ imageData: Data, options: DocumentImageProcessor.OCROptions) async throws -> DocumentImageProcessor.OCRResult {
            guard isOCRAvailable() else {
                throw ProcessingError.ocrNotAvailable
            }

            let startTime = CFAbsoluteTimeGetCurrent()

            guard let uiImage = UIImage(data: imageData),
                  let cgImage = uiImage.cgImage
            else {
                throw ProcessingError.invalidImageData
            }

            let cgImageSize = CoreFoundation.CGSize(width: cgImage.width, height: cgImage.height)
            let imageSize = AppCore.CGSize(width: Double(cgImageSize.width), height: Double(cgImageSize.height))

            // Update progress: Starting OCR preprocessing
            options.progressCallback?(OCRProgress(
                currentStep: .preprocessing,
                stepProgress: 0.0,
                overallProgress: 0.0,
                estimatedTimeRemaining: 3.0
            ))

            // Create Vision text recognition request
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = options.recognitionLevel == .fast ? .fast : .accurate
            request.revision = options.revision
            request.minimumTextHeight = options.minimumTextHeight

            // Set up language preferences
            if !options.automaticLanguageDetection, options.language != .automatic {
                request.recognitionLanguages = [options.language.rawValue]
            }

            // Add custom words if provided
            if !options.customWords.isEmpty {
                request.customWords = options.customWords
            }

            // Update progress: Starting text detection
            options.progressCallback?(OCRProgress(
                currentStep: .textDetection,
                stepProgress: 0.0,
                overallProgress: 0.2,
                estimatedTimeRemaining: 2.5
            ))

            // Perform OCR
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            return try await withCheckedThrowingContinuation { continuation in
                do {
                    try requestHandler.perform([request])

                    guard let results = request.results else {
                        continuation.resume(throwing: ProcessingError.textDetectionFailed)
                        return
                    }

                    // Update progress: Processing recognition results
                    options.progressCallback?(OCRProgress(
                        currentStep: .textRecognition,
                        stepProgress: 0.5,
                        overallProgress: 0.7,
                        estimatedTimeRemaining: 1.0,
                        recognizedTextCount: results.count
                    ))

                    // Process results
                    let extractedTextElements = processVisionResults(results, imageSize: cgImageSize)

                    // Update progress: Language detection
                    options.progressCallback?(OCRProgress(
                        currentStep: .languageDetection,
                        stepProgress: 0.0,
                        overallProgress: 0.8,
                        estimatedTimeRemaining: 0.5
                    ))

                    // Detect languages
                    let detectedLanguages = detectLanguages(from: extractedTextElements)

                    // Update progress: Post-processing
                    options.progressCallback?(OCRProgress(
                        currentStep: .postprocessing,
                        stepProgress: 0.0,
                        overallProgress: 0.9,
                        estimatedTimeRemaining: 0.2
                    ))

                    // Create full text
                    let fullText = extractedTextElements.map(\.text).joined(separator: "\n")

                    // Calculate overall confidence
                    let overallConfidence = extractedTextElements.isEmpty ? 0.0 :
                        extractedTextElements.map(\.confidence).reduce(0, +) / Double(extractedTextElements.count)

                    let processingTime = CFAbsoluteTimeGetCurrent() - startTime

                    // Final progress update
                    options.progressCallback?(OCRProgress(
                        currentStep: .postprocessing,
                        stepProgress: 1.0,
                        overallProgress: 1.0,
                        estimatedTimeRemaining: 0.0,
                        recognizedTextCount: extractedTextElements.count
                    ))

                    let ocrResult = DocumentImageProcessor.OCRResult(
                        extractedText: extractedTextElements,
                        fullText: fullText,
                        confidence: overallConfidence,
                        detectedLanguages: detectedLanguages,
                        processingTime: processingTime,
                        imageSize: imageSize
                    )

                    continuation.resume(returning: ocrResult)

                } catch {
                    continuation.resume(throwing: ProcessingError.ocrFailed(error.localizedDescription))
                }
            }
        }

        func extractStructuredData(
            _ imageData: Data,
            documentType: DocumentImageProcessor.DocumentType,
            options: DocumentImageProcessor.OCROptions
        ) async throws -> DocumentImageProcessor.StructuredOCRResult {
            // First perform standard OCR
            let ocrResult = try await extractText(imageData, options: options)

            // Update progress: Structure analysis
            options.progressCallback?(OCRProgress(
                currentStep: .structureAnalysis,
                stepProgress: 0.0,
                overallProgress: 0.9,
                estimatedTimeRemaining: 0.5,
                recognizedTextCount: ocrResult.extractedText.count
            ))

            // Extract structured fields based on document type
            let extractedFields = await extractStructuredFields(
                from: ocrResult,
                documentType: documentType
            )

            // Calculate structure confidence based on field extraction success
            let structureConfidence = calculateStructureConfidence(
                extractedFields: extractedFields,
                documentType: documentType,
                ocrConfidence: ocrResult.confidence
            )

            return DocumentImageProcessor.StructuredOCRResult(
                documentType: documentType,
                extractedFields: extractedFields,
                ocrResult: ocrResult,
                structureConfidence: structureConfidence
            )
        }

        func isOCRAvailable() -> Bool {
            // OCR is available on iOS 13.0+ with Vision framework
            if #available(iOS 13.0, *) {
                true
            } else {
                false
            }
        }

        // MARK: - OCR Helper Methods

        private func processVisionResults(_ results: [VNRecognizedTextObservation], imageSize: CoreFoundation.CGSize) -> [DocumentImageProcessor.ExtractedText] {
            results.compactMap { observation -> DocumentImageProcessor.ExtractedText? in
                guard let topCandidate = observation.topCandidates(1).first else { return nil }

                // Convert Vision's normalized coordinates to image coordinates
                let boundingBox = convertToImageCoordinates(
                    normalizedBox: observation.boundingBox,
                    imageSize: imageSize
                )

                // Character boxes are not available in this Vision API version
                // Use empty array for now - this is optional data
                let characterBoxes: [CoreGraphics.CGRect] = []

                // Convert CoreFoundation.CGRect to AppCore.CGRect
                let appCoreBoundingBox = AppCore.CGRect(
                    x: Double(boundingBox.origin.x),
                    y: Double(boundingBox.origin.y),
                    width: Double(boundingBox.size.width),
                    height: Double(boundingBox.size.height)
                )

                // Convert array of CoreFoundation.CGRect to AppCore.CGRect
                let appCoreCharacterBoxes = characterBoxes.map { rect in
                    AppCore.CGRect(
                        x: Double(rect.origin.x),
                        y: Double(rect.origin.y),
                        width: Double(rect.size.width),
                        height: Double(rect.size.height)
                    )
                }

                return DocumentImageProcessor.ExtractedText(
                    text: topCandidate.string,
                    confidence: Double(topCandidate.confidence),
                    boundingBox: appCoreBoundingBox,
                    characterBoxes: appCoreCharacterBoxes,
                    detectedLanguage: nil // Language detection handled separately
                )
            }
        }

        private func convertToImageCoordinates(normalizedBox: CoreGraphics.CGRect, imageSize: CoreFoundation.CGSize) -> CoreGraphics.CGRect {
            // Vision uses normalized coordinates (0-1) with origin at bottom-left
            // Convert to image coordinates with origin at top-left
            let x = normalizedBox.origin.x * imageSize.width
            let y = (1.0 - normalizedBox.origin.y - normalizedBox.size.height) * imageSize.height
            let width = normalizedBox.size.width * imageSize.width
            let height = normalizedBox.size.height * imageSize.height

            return CoreGraphics.CGRect(x: x, y: y, width: width, height: height)
        }

        private func detectLanguages(from extractedText: [DocumentImageProcessor.ExtractedText]) -> [DocumentImageProcessor.OCRLanguage] {
            // Simple language detection based on character patterns
            // In a production implementation, this could use more sophisticated methods
            let allText = extractedText.map(\.text).joined(separator: " ")

            // Detect common language patterns
            var detectedLanguages: Set<DocumentImageProcessor.OCRLanguage> = []

            // Check for English (default)
            if !allText.isEmpty {
                detectedLanguages.insert(.english)
            }

            // Check for other languages based on character sets
            if allText.contains(where: { "àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ".contains($0) }) {
                detectedLanguages.insert(.french)
            }

            if allText.contains(where: { "äöüßÄÖÜ".contains($0) }) {
                detectedLanguages.insert(.german)
            }

            if allText.contains(where: { "áéíóúüñÁÉÍÓÚÜÑ".contains($0) }) {
                detectedLanguages.insert(.spanish)
            }

            // Check for CJK characters
            if allText.contains(where: { char in
                guard let scalar = char.unicodeScalars.first else { return false }
                return (0x4E00 ... 0x9FFF).contains(scalar.value) // CJK Unified Ideographs
            }) {
                detectedLanguages.insert(.chinese)
            }

            return Array(detectedLanguages)
        }

        private func extractStructuredFields(
            from ocrResult: DocumentImageProcessor.OCRResult,
            documentType: DocumentImageProcessor.DocumentType
        ) async -> [String: DocumentImageProcessor.StructuredFieldValue] {
            let fullText = ocrResult.fullText
            var fields: [String: DocumentImageProcessor.StructuredFieldValue] = [:]

            switch documentType {
            case .invoice:
                fields = await extractInvoiceFields(from: fullText, extractedText: ocrResult.extractedText)

            case .receipt:
                fields = await extractReceiptFields(from: fullText, extractedText: ocrResult.extractedText)

            case .businessCard:
                fields = await extractBusinessCardFields(from: fullText, extractedText: ocrResult.extractedText)

            case .form:
                fields = await extractFormFields(from: fullText, extractedText: ocrResult.extractedText)

            case .idDocument:
                fields = await extractIDDocumentFields(from: fullText, extractedText: ocrResult.extractedText)

            case .contract:
                fields = await extractContractFields(from: fullText, extractedText: ocrResult.extractedText)

            case .generic:
                fields = ["content": .string(fullText)]
            }

            return fields
        }

        private func calculateStructureConfidence(
            extractedFields: [String: Any],
            documentType: DocumentImageProcessor.DocumentType,
            ocrConfidence: Double
        ) -> Double {
            // Base confidence starts with OCR confidence
            var structureConfidence = ocrConfidence

            // Adjust based on extracted fields success
            let expectedFieldCount = getExpectedFieldCount(for: documentType)
            let extractedFieldCount = extractedFields.count

            if expectedFieldCount > 0 {
                let fieldSuccessRate = min(1.0, Double(extractedFieldCount) / Double(expectedFieldCount))
                structureConfidence = (structureConfidence + fieldSuccessRate) / 2.0
            }

            return structureConfidence
        }

        private func getExpectedFieldCount(for documentType: DocumentImageProcessor.DocumentType) -> Int {
            switch documentType {
            case .invoice: 6 // invoice_number, date, total, etc.
            case .receipt: 4 // store, total, date, items
            case .businessCard: 5 // name, company, phone, email, address
            case .form: 3 // variable fields
            case .idDocument: 4 // name, number, date, address
            case .contract: 3 // parties, date, terms
            case .generic: 1 // just content
            }
        }

        // MARK: - Document Type Specific Extractors

        private func extractInvoiceFields(from text: String, extractedText _: [DocumentImageProcessor.ExtractedText]) async -> [String: DocumentImageProcessor.StructuredFieldValue] {
            var fields: [String: DocumentImageProcessor.StructuredFieldValue] = [:]

            // Extract invoice number
            if let invoiceNumber = text.firstMatch(of: /(?:Invoice|INV|#)\s*:?\s*([A-Z0-9-]+)/.ignoresCase())?.1 {
                fields["invoice_number"] = .string(String(invoiceNumber))
            }

            // Extract dates
            if let date = text.firstMatch(of: /(\d{1,2}\/\d{1,2}\/\d{4}|\d{4}-\d{2}-\d{2})/)?.0 {
                fields["date"] = .string(String(date))
            }

            // Extract total amount
            if let total = text.firstMatch(of: /(?:Total|Amount|Due)\s*:?\s*\$?(\d+\.?\d*)/)?.1 {
                fields["total_amount"] = .string("$" + String(total))
            }

            return fields
        }

        private func extractReceiptFields(from text: String, extractedText _: [DocumentImageProcessor.ExtractedText]) async -> [String: DocumentImageProcessor.StructuredFieldValue] {
            var fields: [String: DocumentImageProcessor.StructuredFieldValue] = [:]

            // Find store name (usually at the top)
            let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if let firstLine = lines.first {
                fields["store_name"] = .string(firstLine.trimmingCharacters(in: .whitespacesAndNewlines))
            }

            // Extract total
            if let total = text.firstMatch(of: /(?:Total|Amount)\s*:?\s*\$?(\d+\.?\d*)/)?.1 {
                fields["total"] = .string("$" + String(total))
            }

            return fields
        }

        private func extractBusinessCardFields(from text: String, extractedText _: [DocumentImageProcessor.ExtractedText]) async -> [String: DocumentImageProcessor.StructuredFieldValue] {
            var fields: [String: DocumentImageProcessor.StructuredFieldValue] = [:]

            // Extract phone number
            if let phone = text.firstMatch(of: /(\+?1?[-.\s]?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4})/)?.0 {
                fields["phone"] = .string(String(phone))
            }

            // Extract email
            if let email = text.firstMatch(of: /([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/)?.0 {
                fields["email"] = .string(String(email))
            }

            return fields
        }

        private func extractFormFields(from text: String, extractedText _: [DocumentImageProcessor.ExtractedText]) async -> [String: DocumentImageProcessor.StructuredFieldValue] {
            var fields: [String: DocumentImageProcessor.StructuredFieldValue] = [:]

            // Generic form field extraction
            fields["content"] = .string(text)

            return fields
        }

        private func extractIDDocumentFields(from text: String, extractedText _: [DocumentImageProcessor.ExtractedText]) async -> [String: DocumentImageProcessor.StructuredFieldValue] {
            var fields: [String: DocumentImageProcessor.StructuredFieldValue] = [:]

            // Extract ID number
            if let idNumber = text.firstMatch(of: /(?:ID|License|Number)\s*:?\s*([A-Z0-9]+)/)?.1 {
                fields["id_number"] = .string(String(idNumber))
            }

            return fields
        }

        private func extractContractFields(from text: String, extractedText _: [DocumentImageProcessor.ExtractedText]) async -> [String: DocumentImageProcessor.StructuredFieldValue] {
            var fields: [String: DocumentImageProcessor.StructuredFieldValue] = [:]

            // Extract contract parties
            if let parties = text.firstMatch(of: /between\s+(.+?)\s+and\s+(.+?)[\.,]/.ignoresCase()) {
                fields["party_1"] = .string(String(parties.1).trimmingCharacters(in: .whitespacesAndNewlines))
                fields["party_2"] = .string(String(parties.2).trimmingCharacters(in: .whitespacesAndNewlines))
            }

            return fields
        }

        // MARK: - Helper Methods
    }#endif
