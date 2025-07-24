@testable import AppCoreiOS
@testable import AppCore
import ComposableArchitecture
import XCTest

@available(iOS 16.0, *)
@MainActor
final class MediaManagementIntegrationTests: XCTestCase {
    var sut: MediaWorkflowCoordinator?
    var filePickerService: FilePickerService?
    var photoLibraryService: PhotoLibraryService?
    var cameraService: CameraService?
    var screenshotService: ScreenshotService?
    var metadataService: MediaMetadataService?
    var validationService: ValidationService?
    var batchEngine: BatchProcessingEngine?

    // MARK: - Computed Properties for Safe Access
    private var sutUnwrapped: MediaWorkflowCoordinator {
        guard let sut = sut else { fatalError("sut not initialized") }
        return sut
    }

    private var filePickerServiceUnwrapped: FilePickerService {
        guard let service = filePickerService else { fatalError("filePickerService not initialized") }
        return service
    }

    private var photoLibraryServiceUnwrapped: PhotoLibraryService {
        guard let service = photoLibraryService else { fatalError("photoLibraryService not initialized") }
        return service
    }

    private var cameraServiceUnwrapped: CameraService {
        guard let service = cameraService else { fatalError("cameraService not initialized") }
        return service
    }

    private var screenshotServiceUnwrapped: ScreenshotService {
        guard let service = screenshotService else { fatalError("screenshotService not initialized") }
        return service
    }

    private var metadataServiceUnwrapped: MediaMetadataService {
        guard let service = metadataService else { fatalError("metadataService not initialized") }
        return service
    }

    private var validationServiceUnwrapped: ValidationService {
        guard let service = validationService else { fatalError("validationService not initialized") }
        return service
    }

    private var batchEngineUnwrapped: BatchProcessingEngine {
        guard let engine = batchEngine else { fatalError("batchEngine not initialized") }
        return engine
    }

    override func setUp() async throws {
        try await super.setUp()

        // Initialize all services
        filePickerService = FilePickerService()
        photoLibraryService = PhotoLibraryService()
        cameraService = CameraService()
        screenshotService = ScreenshotService()
        metadataService = MediaMetadataService()
        validationService = ValidationService()
        batchEngine = BatchProcessingEngine()
        sut = MediaWorkflowCoordinator()
    }

    override func tearDown() async throws {
        sut = nil
        filePickerService = nil
        photoLibraryService = nil
        cameraService = nil
        screenshotService = nil
        metadataService = nil
        validationService = nil
        batchEngine = nil
        try await super.tearDown()
    }

    // MARK: - End-to-End File Processing Tests

    func testCompleteFileWorkflow_FromPicker_ToProcessedAsset() async throws {
        // Test complete flow: pick -> validate -> extract metadata -> compress
        await assertThrowsError {
            // 1. Pick files
            let urls = try await filePickerServiceUnwrapped.pickFiles(
                allowedTypes: [.image],
                allowsMultiple: false,
                maxFileSize: 10_000_000
            )

            // 2. Validate files
            let validationResults = try await validationServiceUnwrapped.validateBatch(
                urls,
                rules: ValidationRules.default
            )

            // 3. Extract metadata
            let metadata = try await metadataServiceUnwrapped.extractMetadata(from: urls[0])

            // 4. Create workflow
            let workflow = MediaWorkflow(
                name: "Process Image",
                steps: [
                    WorkflowStep(type: .compress, name: "Compress"),
                ]
            )

            // 5. Execute workflow
            let asset = MediaAsset(
                type: .image,
                url: urls[0],
                metadata: metadata,
                size: 0
            )
            _ = try await sutUnwrapped.executeWorkflow(workflow, with: [asset])
        }
    }

    func testCompletePhotoLibraryWorkflow_SelectionToExport() async throws {
        // Test photo library integration
        await assertThrowsError {
            // 1. Request permission
            _ = try await photoLibraryServiceUnwrapped.requestPhotoLibraryAccess()

            // 2. Load albums
            let albums = try await photoLibraryServiceUnwrapped.fetchAlbums()

            // 3. Select photos
            let assets = try await photoLibraryServiceUnwrapped.selectPhotos(limit: 5)

            // 4. Process selected photos
            let batchOp = BatchOperation(
                type: .resize,
                assets: assets
            )
            _ = try await batchEngineUnwrapped.startBatchOperation(batchOp)
        }
    }

    func testCompleteCameraWorkflow_CaptureToSave() async throws {
        // Test camera integration
        await assertThrowsError {
            // 1. Check camera availability
            let isAvailable = await cameraServiceUnwrapped.isCameraAvailable()

            // 2. Request permission
            _ = try await cameraServiceUnwrapped.requestCameraAccess()

            // 3. Capture photo
            let photoData = try await cameraServiceUnwrapped.capturePhoto()

            // 4. Extract metadata
            let metadata = try await metadataServiceUnwrapped.extractMetadata(
                from: photoData,
                type: .image
            )

            // 5. Save to library
            let asset = MediaAsset(
                type: .image,
                url: URL(fileURLWithPath: "/tmp/captured.jpg"),
                metadata: metadata,
                size: Int64(photoData.count)
            )
            _ = try await photoLibraryServiceUnwrapped.saveToPhotoLibrary(asset)
        }
    }

    // MARK: - Multi-Service Integration Tests

    func testCrossServiceWorkflow_MixedMediaTypes() async throws {
        // Test handling different media types across services
        await assertThrowsError {
            // Pick different file types
            let imageURL = URL(fileURLWithPath: "/tmp/image.jpg")
            let videoURL = URL(fileURLWithPath: "/tmp/video.mp4")
            let documentURL = URL(fileURLWithPath: "/tmp/document.pdf")

            // Validate each type with appropriate rules
            _ = try await validationServiceUnwrapped.validateFile(
                imageURL,
                rules: validationServiceUnwrapped.suggestedRules(for: .image)
            )
            _ = try await validationServiceUnwrapped.validateFile(
                videoURL,
                rules: validationServiceUnwrapped.suggestedRules(for: .video)
            )
            _ = try await validationServiceUnwrapped.validateFile(
                documentURL,
                rules: validationServiceUnwrapped.suggestedRules(for: .document)
            )
        }
    }

    func testBatchProcessingWithValidation_MultipleAssets() async throws {
        // Test batch processing with validation
        await assertThrowsError {
            let assets = [
                createMockAsset(type: .image),
                createMockAsset(type: .image),
                createMockAsset(type: .image),
            ]

            // Validate all assets
<<<<<<< HEAD
            let urls = assets.map { $0.url }
            let validationResults = try await validationServiceUnwrapped.validateBatch(
=======
            let urls = assets.map(\.url)
            let validationResults = try await validationService.validateBatch(
>>>>>>> Main
                urls,
                rules: ValidationRules.default
            )

            // Only process valid assets
            let validAssets = assets.enumerated().compactMap { index, asset in
                validationResults[index].isValid ? asset : nil
            }

            // Start batch operation
            let operation = BatchOperation(
                type: .compress,
                assets: validAssets,
                options: BatchOperationOptions(concurrent: true)
            )
            _ = try await batchEngineUnwrapped.startBatchOperation(operation)
        }
    }

    // MARK: - Screenshot and Recording Integration Tests

    func testScreenCaptureWorkflow_CaptureAndProcess() async throws {
        await assertThrowsError {
            // 1. Capture screenshot
            let screenshotData = try await screenshotServiceUnwrapped.captureFullScreen()

            // 2. Extract metadata
            let metadata = try await metadataServiceUnwrapped.extractMetadata(
                from: screenshotData,
                type: .image
            )

            // 3. Analyze content
            let analysis = try await metadataServiceUnwrapped.analyzeImageContent(screenshotData)

            // 4. Create workflow for processing
            let workflow = MediaWorkflow(
                name: "Process Screenshot",
                steps: [
                    WorkflowStep(type: .extractMetadata, name: "Extract"),
                    WorkflowStep(type: .generateThumbnail, name: "Thumbnail"),
                ]
            )

            // Execute workflow
            let asset = MediaAsset(
                type: .screenshot,
                url: URL(fileURLWithPath: "/tmp/screenshot.png"),
                metadata: metadata,
                size: Int64(screenshotData.count)
            )
            _ = try await sutUnwrapped.executeWorkflow(workflow, with: [asset])
        }
    }

    func testScreenRecordingWorkflow_RecordProcessUpload() async throws {
        await assertThrowsError {
            // 1. Start recording
            let session = try await screenshotServiceUnwrapped.startScreenRecording(
                options: ScreenRecordingOptions(
                    frameRate: 30,
                    quality: .high,
                    includeAudio: true
                )
            )

            // 2. Stop recording
            let recordingURL = try await screenshotServiceUnwrapped.stopScreenRecording(session)

            // 3. Extract metadata
            let metadata = try await metadataServiceUnwrapped.extractMetadata(from: recordingURL)

            // 4. Create processing workflow
            let workflow = MediaWorkflow(
                name: "Process Recording",
                steps: [
                    WorkflowStep(type: .compress, name: "Compress"),
                    WorkflowStep(type: .generateThumbnail, name: "Thumbnail"),
                    WorkflowStep(type: .upload, name: "Upload"),
                ]
            )

            let asset = MediaAsset(
                type: .video,
                url: recordingURL,
                metadata: metadata,
                size: 0
            )
            _ = try await sutUnwrapped.executeWorkflow(workflow, with: [asset])
        }
    }

    // MARK: - Complex Workflow Integration Tests

    func testConditionalWorkflow_DifferentPathsPerMediaType() async throws {
        await assertThrowsError {
            // Create workflow with conditional steps
            let workflow = MediaWorkflow(
                name: "Conditional Processing",
                steps: [
                    WorkflowStep(
                        type: .validate,
                        name: "Validate All"
                    ),
                    WorkflowStep(
                        type: .compress,
                        name: "Compress Images",
                        condition: WorkflowCondition(
                            type: .mediaType,
                            parameters: ["type": "image"]
                        )
                    ),
                    WorkflowStep(
                        type: .extractMetadata,
                        name: "Extract Video Metadata",
                        condition: WorkflowCondition(
                            type: .mediaType,
                            parameters: ["type": "video"]
                        )
                    ),
                ]
            )

            // Mixed media assets
            let assets = [
                createMockAsset(type: .image),
                createMockAsset(type: .video),
                createMockAsset(type: .document),
            ]

            _ = try await sutUnwrapped.executeWorkflow(workflow, with: assets)
        }
    }

    func testParallelWorkflow_ConcurrentProcessing() async throws {
        await assertThrowsError {
            let config = WorkflowConfiguration(
                parallel: true,
                maxParallelSteps: 3
            )

            let workflow = MediaWorkflow(
                name: "Parallel Processing",
                steps: [
                    WorkflowStep(type: .extractMetadata, name: "Extract"),
                    WorkflowStep(type: .generateThumbnail, name: "Thumbnail"),
                    WorkflowStep(type: .compress, name: "Compress"),
                ],
                configuration: config
            )

            let assets = Array(repeating: createMockAsset(), count: 10)
            _ = try await sutUnwrapped.executeWorkflow(workflow, with: assets)
        }
    }

    // MARK: - Error Recovery Integration Tests

    func testWorkflowErrorRecovery_RetryFailedSteps() async throws {
        await assertThrowsError {
            let workflow = MediaWorkflow(
                name: "Error Recovery",
                steps: [
                    WorkflowStep(type: .validate, name: "Validate", onError: .retry),
                    WorkflowStep(type: .compress, name: "Compress", onError: .skip),
                    WorkflowStep(type: .upload, name: "Upload", onError: .stop),
                ]
            )

            let assets = [createMockAsset()]
            let handle = try await sutUnwrapped.executeWorkflow(workflow, with: assets)

            // Monitor execution
            let stream = sutUnwrapped.monitorExecution(handle)
            for await update in stream {
                if case .failed = update.status {
                    // Retry or handle error
                    break
                }
            }
        }
    }

    func testBatchOperationRecovery_ContinueOnError() async throws {
        await assertThrowsError {
            let assets = Array(repeating: createMockAsset(), count: 20)
            let operation = BatchOperation(
                type: .validate,
                assets: assets,
                options: BatchOperationOptions(
                    continueOnError: true,
                    maxRetries: 3
                )
            )

            let handle = try await batchEngine.startBatchOperation(operation)

            // Monitor progress
            let progressStream = batchEngineUnwrapped.monitorProgress(handle)
            for await progress in progressStream where progress.failed > 0 {
                // Handle failed items
            }
        }
    }

    // MARK: - Performance Integration Tests

    func testLargeScaleProcessing_HundredsOfAssets() async throws {
        await assertThrowsError {
            // Create many assets
            let assets = (0 ..< 100).map { _ in createMockAsset() }

            // Configure for performance
            let settings = BatchEngineSettings(
                maxConcurrentOperations: 5,
                maxConcurrentItems: 10,
                priorityQueueEnabled: true
            )
            await batchEngineUnwrapped.configureEngine(settings)

            // Start processing
            let operation = BatchOperation(
                type: .compress,
                assets: assets,
                options: BatchOperationOptions(
                    concurrent: true,
                    priority: .high
                )
            )
            _ = try await batchEngineUnwrapped.startBatchOperation(operation)
        }
    }

    func testMemoryConstrainedProcessing_LargeFiles() async throws {
        await assertThrowsError {
            // Configure memory limits
            let settings = BatchEngineSettings(
                memoryLimit: 500_000_000, // 500MB
                diskSpaceLimit: 2_000_000_000 // 2GB
            )
            await batchEngineUnwrapped.configureEngine(settings)

            // Process large files
            let largeAssets = [
                createMockAsset(size: 100_000_000), // 100MB
                createMockAsset(size: 200_000_000), // 200MB
                createMockAsset(size: 150_000_000), // 150MB
            ]

            let operation = BatchOperation(
                type: .compress,
                assets: largeAssets
            )
            _ = try await batchEngineUnwrapped.startBatchOperation(operation)
        }
    }

    // MARK: - Template System Integration Tests

    func testWorkflowTemplateSystem_SaveLoadExecute() async throws {
        await assertThrowsError {
            // Create and save template
            let workflow = MediaWorkflow(
                name: "Photo Processing Template",
                steps: [
                    WorkflowStep(type: .validate, name: "Validate"),
                    WorkflowStep(type: .resize, name: "Resize to 1920x1080"),
                    WorkflowStep(type: .compress, name: "Compress 85%"),
                    WorkflowStep(type: .watermark, name: "Add Watermark"),
                ]
            )

            try await sutUnwrapped.saveWorkflowTemplate(workflow, name: "Standard Photo")

            // Load template
            let loadedWorkflow = try await sutUnwrapped.loadWorkflowTemplate("Standard Photo")

            // Execute with assets
            let assets = [createMockAsset(type: .image)]
            _ = try await sutUnwrapped.executeWorkflow(loadedWorkflow, with: assets)
        }
    }

    // MARK: - Permission and Security Integration Tests

    func testSecurityWorkflow_ScanValidateProcess() async throws {
        await assertThrowsError {
            let url = URL(fileURLWithPath: "/tmp/suspicious.jpg")

            // 1. Security scan
            let scanResult = try await validationServiceUnwrapped.scanForThreats(url)

            // 2. Validate if clean
            if scanResult.isSafe {
                let validationResult = try await validationServiceUnwrapped.validateFile(
                    url,
                    rules: ValidationRules(requireSecurityScan: true)
                )

                // 3. Process if valid
                if validationResult.isValid {
                    let metadata = try await metadataServiceUnwrapped.extractMetadata(from: url)

                    // 4. Remove sensitive metadata
                    _ = try await metadataServiceUnwrapped.removeMetadata(
                        from: url,
                        fields: [.location, .camera]
                    )
                }
            }
        }
    }

    func testPermissionHandling_AllServices() async throws {
        // Test permission requests across all services
        await assertThrowsError {
            // Photo library
            _ = try await photoLibraryServiceUnwrapped.requestPhotoLibraryAccess()

            // Camera
            _ = try await cameraServiceUnwrapped.requestCameraAccess()
            _ = try await cameraServiceUnwrapped.requestMicrophoneAccess()

            // Screen recording
            _ = try await screenshotServiceUnwrapped.requestScreenRecordingPermission()
        }
    }

    // MARK: - State Persistence Integration Tests

    func testWorkflowStatePersistence_ResumeAfterCrash() async throws {
        await assertThrowsError {
            // Start workflow
            let workflow = createComplexWorkflow()
            let assets = Array(repeating: createMockAsset(), count: 50)
            let handle = try await sutUnwrapped.executeWorkflow(workflow, with: assets)

            // Simulate interruption
            try await sutUnwrapped.pauseExecution(handle)

            // Get state
            let status = await sutUnwrapped.getExecutionStatus(handle)

            // Resume
            try await sutUnwrapped.resumeExecution(handle)
        }
    }

    // MARK: - UI Integration Tests

    func testUIIntegration_ProgressUpdates() async throws {
        await assertThrowsError {
            // Create workflow with UI updates
            let notifications = NotificationSettings(
                onStart: true,
                onComplete: true,
                onError: true,
                onStepComplete: true
            )
            let config = WorkflowConfiguration(
                notificationSettings: notifications
            )

            let workflow = MediaWorkflow(
                name: "UI Test Workflow",
                steps: [
                    WorkflowStep(type: .validate, name: "Validating..."),
                    WorkflowStep(type: .compress, name: "Compressing..."),
                    WorkflowStep(type: .upload, name: "Uploading..."),
                ],
                configuration: config
            )

            let assets = [createMockAsset()]
            let handle = try await sutUnwrapped.executeWorkflow(workflow, with: assets)

            // Monitor for UI updates
            let updateStream = sutUnwrapped.monitorExecution(handle)
            for await update in updateStream {
                // UI would update based on these
                _ = update
            }
        }
    }
}

// MARK: - Test Helpers

@available(iOS 16.0, *)
extension MediaManagementIntegrationTests {
    func assertThrowsError(
        _ expression: @autoclosure () async throws -> some Any,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error but succeeded", file: file, line: line)
        } catch {
            // Expected error
        }
    }

    func createMockAsset(
        type: MediaType = .image,
        size: Int64 = 1000
    ) -> MediaAsset {
        MediaAsset(
            type: type,
            url: URL(fileURLWithPath: "/tmp/test.\(type == .image ? "jpg" : "mp4")"),
            metadata: MediaMetadata(
                fileName: "test.\(type == .image ? "jpg" : "mp4")",
                fileExtension: type == .image ? "jpg" : "mp4",
                mimeType: type == .image ? "image/jpeg" : "video/mp4"
            ),
            size: size
        )
    }

    func createComplexWorkflow() -> MediaWorkflow {
        MediaWorkflow(
            name: "Complex Workflow",
            steps: [
                WorkflowStep(type: .validate, name: "Validate"),
                WorkflowStep(type: .extractMetadata, name: "Extract Metadata"),
                WorkflowStep(type: .compress, name: "Compress"),
                WorkflowStep(type: .generateThumbnail, name: "Generate Thumbnail"),
                WorkflowStep(type: .watermark, name: "Add Watermark"),
                WorkflowStep(type: .upload, name: "Upload"),
            ]
        )
    }
}
