import ComposableArchitecture
import Dependencies
import Foundation
import IdentifiedCollections

/*
 ============================================================================
 TDD SCAFFOLD - MediaManagementFeature (RED Phase)
 ============================================================================

 Following DocumentScannerFeature patterns with TCA architecture:
 - @ObservableState for reactive UI updates
 - Hierarchical Action enum with proper Sendable conformance
 - Actor-based concurrency with MediaProcessingEngine
 - Session management extending ScanSession patterns
 - Progress tracking through ProgressBridge
 - Swift 6 strict concurrency compliance

 All methods currently throw "NotImplemented" to establish RED test state.
 Implementation will be added in GREEN phase.
 */

// MARK: - Media Management Feature (TCA Implementation)

@Reducer
public struct MediaManagementFeature: Sendable {
    // MARK: - State

    @ObservableState
    public struct State {
        // Core asset management
        public var assets: IdentifiedArrayOf<MediaAsset> = []
        public var selectedAssets: Set<MediaAsset.ID> = []

        // Loading and processing states
        public var isLoading: Bool = false
        public var isProcessing: Bool = false
        public var isCapturing: Bool = false
        public var isRecording: Bool = false

        // Permissions
        public var hasCameraPermission: Bool = false
        public var hasPhotoLibraryPermission: Bool = false
        public var hasMicrophonePermission: Bool = false

        // Error handling and retry
        public var error: MediaError?
        public var lastFailedOperation: Action?

        // Media library
        public var albums: IdentifiedArrayOf<PhotoAlbum> = []

        // Batch operations
        public var currentBatchOperation: BatchOperationHandle?
        public var batchProgress: BatchProgress?

        // Workflows
        public var availableWorkflows: IdentifiedArrayOf<MediaWorkflow> = []
        public var workflowTemplates: IdentifiedArrayOf<WorkflowTemplate> = []

        // Filtering and sorting
        public var filter: MediaFilter = .none
        public var sortOrder: MediaSortOrder = .dateDescending

        // Session management (extending ScanSession patterns)
        public var mediaSession: MediaSession?
        public var isSessionActive: Bool = false

        public init() {}

        // Computed properties
        public var hasAssets: Bool {
            !assets.isEmpty
        }

        public var hasSelectedAssets: Bool {
            !selectedAssets.isEmpty
        }

        public var canStartBatchOperation: Bool {
            hasSelectedAssets && !isProcessing
        }
    }

    // MARK: - Actions

    public enum Action: Sendable {
        // File Picking
        case pickFiles(allowedTypes: [MediaFileType], allowsMultiple: Bool)
        case pickFilesResponse(Result<[MediaAsset], MediaError>)

        // Photo Library
        case selectPhotos(limit: Int)
        case selectPhotosResponse(Result<[MediaAsset], MediaError>)
        case requestPhotoLibraryPermission
        case photoLibraryPermissionResponse(Bool)
        case loadAlbums
        case loadAlbumsResponse(Result<[PhotoAlbum], MediaError>)

        // Camera
        case capturePhoto
        case capturePhotoResponse(Result<MediaAsset, MediaError>)
        case startVideoRecording
        case startVideoRecordingResponse(Result<Void, MediaError>)
        case stopVideoRecording
        case stopVideoRecordingResponse(Result<MediaAsset, MediaError>)
        case requestCameraPermission
        case cameraPermissionResponse(Bool)

        // Screenshots
        case captureScreenshot(ScreenshotType)
        case captureScreenshotResponse(Result<MediaAsset, MediaError>)
        case startScreenRecording
        case startScreenRecordingResponse(Result<Void, MediaError>)
        case stopScreenRecording
        case stopScreenRecordingResponse(Result<MediaAsset, MediaError>)

        // Asset Management
        case selectAsset(MediaAsset.ID)
        case deselectAsset(MediaAsset.ID)
        case selectAllAssets
        case deselectAllAssets
        case deleteAsset(MediaAsset.ID)
        case deleteSelectedAssets

        // Metadata
        case extractMetadata(assetId: MediaAsset.ID)
        case extractMetadataResponse(assetId: MediaAsset.ID, Result<MediaMetadata, MediaError>)
        case updateMetadata(assetId: MediaAsset.ID, metadata: MediaMetadata)

        // Validation
        case validateAsset(MediaAsset.ID)
        case validateAssetResponse(assetId: MediaAsset.ID, Result<AssetValidationResult, MediaError>)
        case validateAllAssets
        case validateAllAssetsComplete

        // Batch Processing
        case startBatchOperation(BatchOperationType)
        case batchOperationResponse(Result<BatchOperationHandle, MediaError>)
        case monitorBatchProgress(BatchOperationHandle)
        case batchProgressUpdate(BatchProgress)
        case cancelBatchOperation
        case batchOperationCancelled

        // Workflows
        case executeWorkflow(MediaWorkflow)
        case workflowResponse(Result<WorkflowExecutionHandle, MediaError>)
        case saveWorkflowTemplate(MediaWorkflow, name: String)
        case saveWorkflowTemplateResponse(Result<WorkflowTemplate, MediaError>)

        // Filtering and Sorting
        case setFilter(MediaFilter)
        case setSortOrder(MediaSortOrder)

        // Error Handling
        case clearError
        case retryFailedOperation

        // Session Management
        case startMediaSession
        case endMediaSession
        case sessionUpdate(MediaSession)
    }

    // MARK: - Dependencies

    @Dependency(\.filePickerClient) var filePickerClient
    @Dependency(\.photoLibraryClient) var photoLibraryClient
    @Dependency(\.screenshotClient) var screenshotClient
    @Dependency(\.mediaValidationClient) var mediaValidationClient
    @Dependency(\.mediaMetadataClient) var mediaMetadataClient

    // MARK: - Reducer Implementation

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // File Picking
            case let .pickFiles(_, allowsMultiple):
                state.isLoading = true
                state.error = nil
                state.lastFailedOperation = action
                return .run { send in
                    do {
                        let assets: [MediaAsset]
                        if allowsMultiple {
                            assets = try await filePickerClient.pickMultipleFiles()
                        } else {
                            let singleAsset = try await filePickerClient.pickFile()
                            assets = [singleAsset]
                        }
                        await send(.pickFilesResponse(.success(assets)))
                    } catch {
                        await send(.pickFilesResponse(.failure(MediaError.filePickingFailed(error.localizedDescription))))
                    }
                }

            case let .pickFilesResponse(result):
                state.isLoading = false
                switch result {
                case let .success(assets):
                    state.assets.append(contentsOf: assets)
                    state.lastFailedOperation = nil
                case let .failure(error):
                    state.error = error
                }
                return .none

            // Photo Library
            case let .selectPhotos(limit):
                state.isLoading = true
                state.error = nil
                return .run { send in
                    do {
                        let assets: [MediaAsset]
                        if limit == 1 {
                            let singleAsset = try await photoLibraryClient.pickPhoto()
                            assets = [singleAsset]
                        } else {
                            assets = try await photoLibraryClient.pickMultiplePhotos()
                        }
                        await send(.selectPhotosResponse(.success(assets)))
                    } catch {
                        await send(.selectPhotosResponse(.failure(MediaError.photoLibraryAccessFailed(error.localizedDescription))))
                    }
                }

            case let .selectPhotosResponse(result):
                state.isLoading = false
                switch result {
                case let .success(assets):
                    state.assets.append(contentsOf: assets)
                case let .failure(error):
                    state.error = error
                }
                return .none

            case .requestPhotoLibraryPermission:
                return .run { send in
                    let granted = await photoLibraryClient.requestAccess()
                    await send(.photoLibraryPermissionResponse(granted))
                }

            case let .photoLibraryPermissionResponse(granted):
                state.hasPhotoLibraryPermission = granted
                return .none

            case .loadAlbums:
                state.isLoading = true
                return .run { send in
                    let result: Result<[PhotoAlbum], MediaError> = .failure(
                        MediaError.unsupportedOperation("Not implemented")
                    )
                    await send(.loadAlbumsResponse(result))
                }

            case let .loadAlbumsResponse(result):
                state.isLoading = false
                switch result {
                case let .success(albums):
                    state.albums = IdentifiedArrayOf(uniqueElements: albums)
                case let .failure(error):
                    state.error = error
                }
                return .none

            // Camera
            case .capturePhoto:
                state.isCapturing = true
                state.error = nil
                state.lastFailedOperation = action
                return .run { send in
                    do {
                        // Note: CameraClient not defined yet - using placeholder
                        // In full implementation, would use: let asset = try await cameraClient.capturePhoto()
                        throw NSError(domain: "CameraNotImplemented", code: -1, userInfo: [NSLocalizedDescriptionKey: "Camera functionality requires CameraClient implementation"])
                    } catch {
                        await send(.capturePhotoResponse(.failure(MediaError.cameraAccessFailed(error.localizedDescription))))
                    }
                }

            case let .capturePhotoResponse(result):
                state.isCapturing = false
                switch result {
                case let .success(asset):
                    state.assets.append(asset)
                case let .failure(error):
                    state.error = error
                }
                return .none

            case .startVideoRecording:
                state.isRecording = true
                state.error = nil
                state.lastFailedOperation = action
                return .run { send in
                    do {
                        // Note: CameraClient not defined yet - using placeholder
                        // In full implementation, would use: try await cameraClient.startVideoRecording()
                        throw NSError(domain: "CameraNotImplemented", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video recording requires CameraClient implementation"])
                    } catch {
                        await send(.startVideoRecordingResponse(.failure(MediaError.cameraAccessFailed(error.localizedDescription))))
                    }
                }

            case let .startVideoRecordingResponse(result):
                switch result {
                case .success:
                    break // Keep recording state
                case let .failure(error):
                    state.isRecording = false
                    state.error = error
                }
                return .none

            case .stopVideoRecording:
                state.isRecording = false
                return .run { send in
                    do {
                        // Note: CameraClient not defined yet - using placeholder
                        // In full implementation, would use: let asset = try await cameraClient.stopVideoRecording()
                        throw NSError(domain: "CameraNotImplemented", code: -1, userInfo: [NSLocalizedDescriptionKey: "Stop video recording requires CameraClient implementation"])
                    } catch {
                        await send(.stopVideoRecordingResponse(.failure(MediaError.cameraAccessFailed(error.localizedDescription))))
                    }
                }

            case let .stopVideoRecordingResponse(result):
                switch result {
                case let .success(asset):
                    state.assets.append(asset)
                case let .failure(error):
                    state.error = error
                }
                return .none

            case .requestCameraPermission:
                return .run { send in
                    // In full implementation, would use CameraClient
                    // For now, assume permission denied until CameraClient is implemented
                    await send(.cameraPermissionResponse(false))
                }

            case let .cameraPermissionResponse(granted):
                state.hasCameraPermission = granted
                return .none

            // Screenshots
            case .captureScreenshot:
                state.isCapturing = true
                state.error = nil
                state.lastFailedOperation = action
                return .run { send in
                    do {
                        let asset = try await screenshotClient.captureScreen()
                        await send(.captureScreenshotResponse(.success(asset)))
                    } catch {
                        await send(.captureScreenshotResponse(.failure(MediaError.screenshotFailed(error.localizedDescription))))
                    }
                }

            case let .captureScreenshotResponse(result):
                state.isCapturing = false
                switch result {
                case let .success(asset):
                    state.assets.append(asset)
                case let .failure(error):
                    state.error = error
                }
                return .none

            case .startScreenRecording:
                state.isRecording = true
                state.error = nil
                state.lastFailedOperation = action
                return .run { send in
                    do {
                        try await screenshotClient.startRecording()
                        await send(.startScreenRecordingResponse(.success(())))
                    } catch {
                        await send(.startScreenRecordingResponse(.failure(MediaError.screenshotFailed(error.localizedDescription))))
                    }
                }

            case let .startScreenRecordingResponse(result):
                switch result {
                case .success:
                    break
                case let .failure(error):
                    state.isRecording = false
                    state.error = error
                }
                return .none

            case .stopScreenRecording:
                state.isRecording = false
                return .run { send in
                    do {
                        let asset = try await screenshotClient.stopRecording()
                        await send(.stopScreenRecordingResponse(.success(asset)))
                    } catch {
                        await send(.stopScreenRecordingResponse(.failure(MediaError.screenshotFailed(error.localizedDescription))))
                    }
                }

            case let .stopScreenRecordingResponse(result):
                switch result {
                case let .success(asset):
                    state.assets.append(asset)
                case let .failure(error):
                    state.error = error
                }
                return .none

            // Asset Management
            case let .selectAsset(assetId):
                state.selectedAssets.insert(assetId)
                return .none

            case let .deselectAsset(assetId):
                state.selectedAssets.remove(assetId)
                return .none

            case .selectAllAssets:
                state.selectedAssets = Set(state.assets.map(\.id))
                return .none

            case .deselectAllAssets:
                state.selectedAssets = []
                return .none

            case let .deleteAsset(assetId):
                state.assets.remove(id: assetId)
                state.selectedAssets.remove(assetId)
                return .none

            case .deleteSelectedAssets:
                let selectedIds = Array(state.selectedAssets)
                for assetId in selectedIds {
                    state.assets.remove(id: assetId)
                }
                state.selectedAssets = []
                return .none

            // Metadata
            case let .extractMetadata(assetId):
                state.isProcessing = true
                state.error = nil
                state.lastFailedOperation = action
                return .run { [assets = state.assets] send in
                    guard let asset = assets[id: assetId] else {
                        await send(.extractMetadataResponse(assetId: assetId, .failure(MediaError.fileNotFound("Asset not found"))))
                        return
                    }

                    do {
                        guard let assetURL = asset.url else {
                            await send(.extractMetadataResponse(assetId: assetId, .failure(MediaError.fileNotFound("Asset URL is nil"))))
                            return
                        }

                        let metadata = try await mediaMetadataClient.extractMetadata(assetURL)
                        await send(.extractMetadataResponse(assetId: assetId, .success(metadata)))
                    } catch {
                        await send(.extractMetadataResponse(assetId: assetId, .failure(MediaError.metadataExtractionFailed(error.localizedDescription))))
                    }
                }

            case let .extractMetadataResponse(assetId, result):
                state.isProcessing = false
                switch result {
                case let .success(metadata):
                    state.assets[id: assetId]?.metadata = metadata
                case let .failure(error):
                    state.error = error
                }
                return .none

            case let .updateMetadata(assetId, metadata):
                state.assets[id: assetId]?.metadata = metadata
                return .none

            // Validation
            case let .validateAsset(assetId):
                state.lastFailedOperation = action
                return .run { [assets = state.assets] send in
                    guard let asset = assets[id: assetId] else {
                        await send(.validateAssetResponse(assetId: assetId, .failure(MediaError.fileNotFound("Asset not found"))))
                        return
                    }

                    do {
                        guard let assetURL = asset.url else {
                            await send(.validateAssetResponse(assetId: assetId, .failure(MediaError.fileNotFound("Asset URL is nil"))))
                            return
                        }

                        let validationResult = try await mediaValidationClient.validateFile(assetURL)
                        let result = AssetValidationResult(
                            isValid: validationResult.isValid,
                            issues: validationResult.issues ?? [],
                            assetId: assetId
                        )
                        await send(.validateAssetResponse(assetId: assetId, .success(result)))
                    } catch {
                        await send(.validateAssetResponse(assetId: assetId, .failure(MediaError.validationFailed(error.localizedDescription))))
                    }
                }

            case let .validateAssetResponse(_, result):
                switch result {
                case .success:
                    break // Update asset validation status
                case let .failure(error):
                    state.error = error
                }
                return .none

            case .validateAllAssets:
                state.isProcessing = true
                state.lastFailedOperation = action
                return .run { [assets = state.assets] send in
                    // Send validation requests for each asset
                    for asset in assets {
                        do {
                            guard let assetURL = asset.url else {
                                await send(.validateAssetResponse(assetId: asset.id, .failure(MediaError.fileNotFound("Asset URL is nil"))))
                                continue
                            }

                            let validationResult = try await mediaValidationClient.validateFile(assetURL)
                            let result = AssetValidationResult(
                                isValid: validationResult.isValid,
                                issues: validationResult.issues ?? [],
                                assetId: asset.id
                            )
                            await send(.validateAssetResponse(assetId: asset.id, .success(result)))
                        } catch {
                            await send(.validateAssetResponse(assetId: asset.id, .failure(MediaError.validationFailed(error.localizedDescription))))
                        }
                    }
                    await send(.validateAllAssetsComplete)
                }

            case .validateAllAssetsComplete:
                state.isProcessing = false
                return .none

            // Batch Processing
            case let .startBatchOperation(operationType):
                state.isProcessing = true
                state.error = nil
                state.lastFailedOperation = action
                return .run { [selectedAssets = state.selectedAssets] send in
                    guard !selectedAssets.isEmpty else {
                        await send(.batchOperationResponse(.failure(MediaError.invalidInput("No assets selected for batch operation"))))
                        return
                    }

                    // Create batch operation handle
                    let handle = BatchOperationHandle(
                        operationId: UUID(),
                        type: operationType
                    )

                    // In full implementation, would start actual batch processing
                    // For now, just return the handle to indicate operation started
                    await send(.batchOperationResponse(.success(handle)))
                }

            case let .batchOperationResponse(result):
                state.isProcessing = false
                switch result {
                case let .success(handle):
                    state.currentBatchOperation = handle
                case let .failure(error):
                    state.error = error
                }
                return .none

            case let .monitorBatchProgress(handle):
                // In full implementation, would start monitoring progress
                // For now, just create mock progress
                let progress = BatchProgress(
                    operationId: handle.operationId,
                    totalItems: state.selectedAssets.count,
                    status: .running
                )
                state.batchProgress = progress
                return .none

            case let .batchProgressUpdate(progress):
                state.batchProgress = progress
                return .none

            case .cancelBatchOperation:
                state.isProcessing = false
                return .run { send in
                    await send(.batchOperationCancelled)
                }

            case .batchOperationCancelled:
                state.currentBatchOperation = nil
                return .none

            // Workflows
            case let .executeWorkflow(workflow):
                state.isProcessing = true
                state.error = nil
                state.lastFailedOperation = action
                return .run { [selectedAssets = state.selectedAssets] send in
                    guard !selectedAssets.isEmpty else {
                        await send(.workflowResponse(.failure(MediaError.invalidInput("No assets selected for workflow execution"))))
                        return
                    }

                    // Create workflow execution handle
                    let handle = WorkflowExecutionHandle(
                        id: UUID(),
                        workflowId: workflow.id,
                        assetIds: Array(selectedAssets)
                    )

                    // In full implementation, would execute workflow steps
                    // For now, just return the handle to indicate execution started
                    await send(.workflowResponse(.success(handle)))
                }

            case let .workflowResponse(result):
                state.isProcessing = false
                switch result {
                case .success:
                    break
                case let .failure(error):
                    state.error = error
                }
                return .none

            case let .saveWorkflowTemplate(workflow, name):
                state.lastFailedOperation = action
                return .run { send in
                    // Create workflow template
                    let template = WorkflowTemplate(
                        id: UUID(),
                        name: name,
                        workflow: workflow,
                        createdAt: Date()
                    )

                    // In full implementation, would persist template to storage
                    // For now, just return success
                    await send(.saveWorkflowTemplateResponse(.success(template)))
                }

            case let .saveWorkflowTemplateResponse(result):
                switch result {
                case let .success(template):
                    state.workflowTemplates.append(template)
                case let .failure(error):
                    state.error = error
                }
                return .none

            // Filtering and Sorting
            case let .setFilter(filter):
                state.filter = filter
                return .none

            case let .setSortOrder(sortOrder):
                state.sortOrder = sortOrder
                return .none

            // Error Handling
            case .clearError:
                state.error = nil
                return .none

            case .retryFailedOperation:
                guard let lastOperation = state.lastFailedOperation else {
                    return .none
                }
                state.error = nil
                return .run { send in
                    await send(lastOperation)
                }

            // Session Management
            case .startMediaSession:
                state.isSessionActive = true
                return .none

            case .endMediaSession:
                state.isSessionActive = false
                state.mediaSession = nil
                return .none

            case let .sessionUpdate(session):
                state.mediaSession = session
                return .none
            }
        }
    }
}

// MARK: - Supporting Types

public enum ScreenshotType: Sendable, Equatable {
    case fullScreen
    case area(CGRect)
    case window(String)
}

public enum MediaFileType: String, Sendable, CaseIterable {
    case image = "public.image"
    case video = "public.movie"
    case document = "public.data"
    case pdf = "com.adobe.pdf"

    public var displayName: String {
        switch self {
        case .image: "Images"
        case .video: "Videos"
        case .document: "Documents"
        case .pdf: "PDF Files"
        }
    }
}

public enum MediaFilter: Sendable, Equatable {
    case none
    case type(MediaType)
    case dateRange(Date, Date)
    case size(Int64, Int64)
}

public enum MediaSortOrder: Sendable, CaseIterable {
    case dateAscending
    case dateDescending
    case nameAscending
    case nameDescending
    case sizeAscending
    case sizeDescending

    public var displayName: String {
        switch self {
        case .dateAscending: "Date (Oldest First)"
        case .dateDescending: "Date (Newest First)"
        case .nameAscending: "Name (A-Z)"
        case .nameDescending: "Name (Z-A)"
        case .sizeAscending: "Size (Smallest First)"
        case .sizeDescending: "Size (Largest First)"
        }
    }
}

// <!-- /dev scaffold ready -->
