import ComposableArchitecture
import Foundation

// MARK: - Configuration Types

/// Configuration for processing individual pages in batch operations
private struct PageProcessingConfig: Sendable {
    let page: SessionPage
    let index: Int
    let total: Int
    let sessionEngine: SessionEngine
    let progressSession: String
    let progressHandler: @Sendable (Double) async -> Void
    let perPageCompletion: @Sendable (SessionPage.ID, Result<Void, Error>) async -> Void
    
    init(
        page: SessionPage,
        index: Int,
        total: Int,
        sessionEngine: SessionEngine,
        progressSession: String,
        progressHandler: @escaping @Sendable (Double) async -> Void,
        perPageCompletion: @escaping @Sendable (SessionPage.ID, Result<Void, Error>) async -> Void
    ) {
        self.page = page
        self.index = index
        self.total = total
        self.sessionEngine = sessionEngine
        self.progressSession = progressSession
        self.progressHandler = progressHandler
        self.perPageCompletion = perPageCompletion
    }
}

/// Protocol for batch processing of session pages
public protocol BatchProcessing: Sendable {
    /// Process pages in batch with progress tracking
    func processPages(
        _ pages: IdentifiedArrayOf<SessionPage>,
        sessionEngine: SessionEngine,
        progressHandler: @escaping @Sendable (Double) async -> Void,
        perPageCompletion: @escaping @Sendable (SessionPage.ID, Result<Void, Error>) async -> Void
    ) async throws

    /// Process a single page
    func processSinglePage(_ page: SessionPage) async throws -> SessionPage

    /// Cancel current batch operation
    func cancelBatch() async

    /// Get current processing status
    var isProcessing: Bool { get async }
}

/// Actor-based batch processor for scanning operations
public actor BatchProcessor: BatchProcessing {
    // Dependencies
    @Dependency(\.documentScanner) private var documentScanner
    @Dependency(\.documentImageProcessor) private var documentImageProcessor
    @Dependency(\.progressBridge) private var progressBridge

    // Processing state
    private var currentTask: Task<Void, Error>?
    private var _isProcessing: Bool = false

    public init() {}

    // MARK: - Processing Status

    public var isProcessing: Bool {
        _isProcessing
    }

    // MARK: - Batch Processing

    public func processPages(
        _ pages: IdentifiedArrayOf<SessionPage>,
        sessionEngine: SessionEngine,
        progressHandler: @escaping @Sendable (Double) async -> Void,
        perPageCompletion: @escaping @Sendable (SessionPage.ID, Result<Void, Error>) async -> Void
    ) async throws {
        guard !_isProcessing else {
            throw ScanError.batchOperationFailed("Batch operation already in progress")
        }

        _isProcessing = true
        defer { _isProcessing = false }

        let total = pages.count
        guard total > 0 else { return }

        // Create progress session for batch operation
        let sessionId = UUID()
        let progressSession = await progressBridge.createProgressSession(
            sessionId: sessionId,
            progressClient: ProgressClient.liveValue
        )

        await progressSession.transitionToPhase(.scanning, operation: "Starting batch processing of \(total) pages")

        // Process pages with concurrency limit to avoid overwhelming the system
        let maxConcurrency = min(3, total) // Limit to 3 concurrent operations

        await withTaskGroup(of: Void.self) { group in
            var index = 0
            var iterator = pages.makeIterator()

            // Start initial batch of tasks
            for _ in 0 ..< min(maxConcurrency, total) {
                if let page = iterator.next() {
                    let currentIndex = index
                    group.addTask { @Sendable in
                        let config = PageProcessingConfig(
                            page: page,
                            index: currentIndex,
                            total: total,
                            sessionEngine: sessionEngine,
                            progressSession: sessionId.uuidString,
                            progressHandler: progressHandler,
                            perPageCompletion: perPageCompletion
                        )
                        await self.processPageInGroup(config: config)
                    }
                    index += 1
                }
            }

            // As tasks complete, start new ones
            while await group.next() != nil {
                if let page = iterator.next() {
                    let currentIndex = index
                    group.addTask { @Sendable in
                        let config = PageProcessingConfig(
                            page: page,
                            index: currentIndex,
                            total: total,
                            sessionEngine: sessionEngine,
                            progressSession: sessionId.uuidString,
                            progressHandler: progressHandler,
                            perPageCompletion: perPageCompletion
                        )
                        await self.processPageInGroup(config: config)
                    }
                    index += 1
                }
            }
        }

        // Complete progress session
        await progressSession.complete()
        await progressBridge.removeProgressSession(sessionId)
    }

    private func processPageInGroup(
        config: PageProcessingConfig
    ) async {
        do {
            // Update page status to processing
            try await config.sessionEngine.updatePageStatus(id: config.page.id, status: .processing)

            // Process the page
            let processedPage = try await processSinglePage(config.page)

            // Update page status to processed
            try await config.sessionEngine.updatePageStatus(id: processedPage.id, status: .processed)

            // Report completion
            await config.perPageCompletion(config.page.id, .success(()))

            // Update overall progress
            let progress = Double(config.index + 1) / Double(config.total)
            await config.progressHandler(progress)

        } catch {
            // Update page status to failed
            _ = try? await config.sessionEngine.updatePageStatus(id: config.page.id, status: .failed(error.localizedDescription))

            // Report failure
            await config.perPageCompletion(config.page.id, .failure(error))

            print("Failed to process page \(config.page.id): \(error)")
        }
    }

    // MARK: - Single Page Processing

    public func processSinglePage(_ page: SessionPage) async throws -> SessionPage {
        var processedPage = page

        // 1. Image Enhancement (if needed)
        if processedPage.enhancedImageData == nil {
            let enhancedData = try await enhancePageImage(processedPage)
            processedPage.enhancedImageData = enhancedData
        }

        // 2. Generate thumbnail (if needed)
        if processedPage.thumbnailData == nil {
            let thumbnailData = try await generateThumbnail(for: processedPage)
            processedPage.thumbnailData = thumbnailData
        }

        // 3. OCR Processing (if needed)
        if processedPage.ocrText == nil, processedPage.ocrResult == nil {
            let ocrResult = try await performOCR(on: processedPage)
            processedPage.ocrResult = ocrResult
            processedPage.ocrText = ocrResult.fullText
        }

        // 4. Update metadata
        processedPage.pageMetadata.processingNotes = "Batch processed at \(Date())"
        processedPage.pageMetadata.qualityScore = processedPage.ocrResult?.confidence

        return processedPage
    }

    // MARK: - Processing Steps

    private func enhancePageImage(_ page: SessionPage) async throws -> Data {
        let imageData = page.enhancedImageData ?? page.imageData

        // Use DocumentImageProcessor for enhancement with progress tracking
        let options = DocumentImageProcessor.ProcessingOptions(
            qualityTarget: .balanced,
            preserveColors: true,
            optimizeForOCR: true
        )

        let result = try await documentImageProcessor.processImage(
            imageData,
            .documentScanner,
            options
        )

        return result.processedImageData
    }

    private func generateThumbnail(for page: SessionPage) async throws -> Data {
        let imageData = page.enhancedImageData ?? page.imageData
        let thumbnailSize = CGSize(width: 200, height: 300)

        return try await documentScanner.generateThumbnail(imageData, thumbnailSize)
    }

    private func performOCR(on page: SessionPage) async throws -> OCRResult {
        let imageData = page.enhancedImageData ?? page.imageData

        // Use enhanced OCR with DocumentImageProcessor for better progress tracking
        let ocrOptions = DocumentImageProcessor.OCROptions(
            automaticLanguageDetection: true
        )

        let detailedResult = try await documentImageProcessor.extractText(imageData, ocrOptions)

        // Convert to OCRResult format expected by the system
        return OCRResult(
            fullText: detailedResult.fullText,
            confidence: detailedResult.confidence,
            recognizedFields: [],
            documentStructure: DocumentStructure(),
            extractedMetadata: ExtractedMetadata(),
            processingTime: detailedResult.processingTime
        )
    }

    // MARK: - Cancellation

    public func cancelBatch() async {
        currentTask?.cancel()
        currentTask = nil
        _isProcessing = false
    }
}

// MARK: - Dependency Registration

extension BatchProcessor: DependencyKey {
    public static let liveValue: BatchProcessor = .init()
    public static let testValue: BatchProcessor = .init()
}

public extension DependencyValues {
    var batchProcessor: BatchProcessor {
        get { self[BatchProcessor.self] }
        set { self[BatchProcessor.self] = newValue }
    }
}

// MARK: - Batch Operation Status

// Note: BatchOperationStatus is defined in BatchOperations.swift
