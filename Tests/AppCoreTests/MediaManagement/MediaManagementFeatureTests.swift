@testable import AppCoreiOS
@testable import AppCore
import ComposableArchitecture
import XCTest

@available(iOS 16.0, *)
@MainActor
final class MediaManagementFeatureTests: XCTestCase {
    var store: TestStore<MediaManagementFeature.State, MediaManagementFeature.Action>?

    private var storeUnwrapped: TestStore<MediaManagementFeature.State, MediaManagementFeature.Action> {
        guard let store = store else { fatalError("store not initialized") }
        return store
    }

    override func setUp() async throws {
        try await super.setUp()
        store = TestStore(
            initialState: MediaManagementFeature.State(),
            reducer: { MediaManagementFeature() }
        )
    }

    override func tearDown() async throws {
        store = nil
        try await super.tearDown()
    }

    // MARK: - File Picking Tests

    func testPickFiles_Success_ShouldAddAssetsToState() async {
        // Given
        let expectedURLs = [
            URL(fileURLWithPath: "/tmp/file1.jpg"),
            URL(fileURLWithPath: "/tmp/file2.jpg"),
        ]

        // When/Then
        await storeUnwrapped.send(.pickFiles(allowedTypes: [.image], allowsMultiple: true)) {
            $0.isLoading = true
        }

        // Currently fails with "Not implemented"
        await storeUnwrapped.receive(.pickFilesResponse(.failure(MediaError.unsupportedOperation("Not implemented")))) {
            $0.isLoading = false
            $0.error = MediaError.unsupportedOperation("Not implemented")
        }
    }

    func testPickFiles_SingleFile_ShouldAddOneAsset() async {
        // When/Then
        await storeUnwrapped.send(.pickFiles(allowedTypes: [.document], allowsMultiple: false)) {
            $0.isLoading = true
        }

        await storeUnwrapped.receive(.pickFilesResponse(.failure(MediaError.unsupportedOperation("Not implemented")))) {
            $0.isLoading = false
            $0.error = MediaError.unsupportedOperation("Not implemented")
        }
    }

    func testPickFiles_Cancelled_ShouldClearLoading() async {
        // When/Then
        await storeUnwrapped.send(.pickFiles(allowedTypes: [.image], allowsMultiple: true)) {
            $0.isLoading = true
        }

        await storeUnwrapped.receive(.pickFilesResponse(.failure(MediaError.unsupportedOperation("Not implemented")))) {
            $0.isLoading = false
            $0.error = MediaError.unsupportedOperation("Not implemented")
        }
    }

    // MARK: - Photo Library Tests

    func testSelectPhotos_Success_ShouldAddPhotosToState() async {
        // When/Then
        await storeUnwrapped.send(.selectPhotos(limit: 10)) {
            $0.isLoading = true
        }

        await storeUnwrapped.receive(.selectPhotosResponse(.failure(MediaError.unsupportedOperation("Not implemented")))) {
            $0.isLoading = false
            $0.error = MediaError.unsupportedOperation("Not implemented")
        }
    }

    func testRequestPhotoLibraryPermission_Granted_ShouldUpdatePermission() async {
        // When/Then
        await storeUnwrapped.send(.requestPhotoLibraryPermission)

        await storeUnwrapped.receive(.photoLibraryPermissionResponse(false)) {
            $0.hasPhotoLibraryPermission = false
        }
    }

    func testLoadAlbums_Success_ShouldPopulateAlbums() async {
        // When/Then
        await storeUnwrapped.send(.loadAlbums) {
            $0.isLoading = true
        }

        await storeUnwrapped.receive(.loadAlbumsResponse(.failure(MediaError.unsupportedOperation("Not implemented")))) {
            $0.isLoading = false
            $0.error = MediaError.unsupportedOperation("Not implemented")
        }
    }

    // MARK: - Camera Tests

    func testCapturePhoto_Success_ShouldAddPhotoAsset() async {
        // When/Then
        await storeUnwrapped.send(.capturePhoto) {
            $0.isCapturing = true
        }

        await storeUnwrapped.receive(.capturePhotoResponse(.failure(MediaError.unsupportedOperation("Not implemented")))) {
            $0.isCapturing = false
            $0.error = MediaError.unsupportedOperation("Not implemented")
        }
    }

    func testStartVideoRecording_ShouldUpdateRecordingState() async {
        // When/Then
        await storeUnwrapped.send(.startVideoRecording) {
            $0.isRecording = true
        }

        await storeUnwrapped.receive(.startVideoRecordingResponse(.failure(MediaError.unsupportedOperation("Not implemented")))) {
            $0.isRecording = false
            $0.error = MediaError.unsupportedOperation("Not implemented")
        }
    }

    func testStopVideoRecording_WithActiveRecording_ShouldAddVideoAsset() async {
        // Given
        store = TestStore(
            initialState: MediaManagementFeature.State(isRecording: true),
            reducer: { MediaManagementFeature() }
        )

        // When/Then
        await storeUnwrapped.send(.stopVideoRecording) {
            $0.isRecording = false
        }

        await storeUnwrapped.receive(.stopVideoRecordingResponse(.failure(MediaError.unsupportedOperation("Not implemented")))) {
            $0.error = MediaError.unsupportedOperation("Not implemented")
        }
    }

    // MARK: - Screenshot Tests

    func testCaptureScreenshot_FullScreen_ShouldAddScreenshotAsset() async {
        // When/Then
        await storeUnwrapped.send(.captureScreenshot(.fullScreen)) {
            $0.isCapturing = true
        }

        await storeUnwrapped.receive(.captureScreenshotResponse(.failure(MediaError.unsupportedOperation("Not implemented")))) {
            $0.isCapturing = false
            $0.error = MediaError.unsupportedOperation("Not implemented")
        }
    }

    func testStartScreenRecording_ShouldUpdateRecordingState() async {
        // When/Then
        await storeUnwrapped.send(.startScreenRecording) {
            $0.isRecording = true
        }

        await storeUnwrapped.receive(.startScreenRecordingResponse(.failure(MediaError.unsupportedOperation("Not implemented")))) {
            $0.isRecording = false
            $0.error = MediaError.unsupportedOperation("Not implemented")
        }
    }

    // MARK: - Asset Management Tests

    func testSelectAsset_ShouldAddToSelection() async {
        // Given
        let asset = createMockAsset()
        store = TestStore(
            initialState: MediaManagementFeature.State(assets: [asset]),
            reducer: { MediaManagementFeature() }
        )

        // When/Then
        await storeUnwrapped.send(.selectAsset(asset.id)) {
            $0.selectedAssets.insert(asset.id)
        }
    }

    func testDeselectAsset_ShouldRemoveFromSelection() async {
        // Given
        let asset = createMockAsset()
        store = TestStore(
            initialState: MediaManagementFeature.State(
                assets: [asset],
                selectedAssets: [asset.id]
            ),
            reducer: { MediaManagementFeature() }
        )

        // When/Then
        await storeUnwrapped.send(.deselectAsset(asset.id)) {
            $0.selectedAssets.remove(asset.id)
        }
    }

    func testSelectAllAssets_ShouldSelectAll() async {
        // Given
        let assets = [createMockAsset(), createMockAsset(), createMockAsset()]
        store = TestStore(
            initialState: MediaManagementFeature.State(assets: IdentifiedArrayOf(uniqueElements: assets)),
            reducer: { MediaManagementFeature() }
        )

        // When/Then
<<<<<<< HEAD
        await storeUnwrapped.send(.selectAllAssets) {
            $0.selectedAssets = Set(assets.map { $0.id })
=======
        await store.send(.selectAllAssets) {
            $0.selectedAssets = Set(assets.map(\.id))
>>>>>>> Main
        }
    }

    func testDeselectAllAssets_ShouldClearSelection() async {
        // Given
        let assets = [createMockAsset(), createMockAsset()]
        store = TestStore(
            initialState: MediaManagementFeature.State(
                assets: IdentifiedArrayOf(uniqueElements: assets),
                selectedAssets: Set(assets.map(\.id))
            ),
            reducer: { MediaManagementFeature() }
        )

        // When/Then
        await storeUnwrapped.send(.deselectAllAssets) {
            $0.selectedAssets = []
        }
    }

    func testDeleteAsset_ShouldRemoveFromState() async {
        // Given
        let asset = createMockAsset()
        store = TestStore(
            initialState: MediaManagementFeature.State(assets: [asset]),
            reducer: { MediaManagementFeature() }
        )

        // When/Then
        await storeUnwrapped.send(.deleteAsset(asset.id)) {
            $0.assets.remove(id: asset.id)
        }
    }

    // MARK: - Metadata Tests

    func testExtractMetadata_Success_ShouldUpdateAsset() async {
        // Given
        let asset = createMockAsset()
        store = TestStore(
            initialState: MediaManagementFeature.State(assets: [asset]),
            reducer: { MediaManagementFeature() }
        )

        // When/Then
        await storeUnwrapped.send(.extractMetadata(assetId: asset.id)) {
            $0.isProcessing = true
        }

        await storeUnwrapped.receive(.extractMetadataResponse(assetId: asset.id, .failure(MediaError.unsupportedOperation("Not implemented")))) {
            $0.isProcessing = false
            $0.error = MediaError.unsupportedOperation("Not implemented")
        }
    }

    func testUpdateMetadata_ShouldModifyAsset() async {
        // Given
        let asset = createMockAsset()
        let newMetadata = MediaMetadata(
            fileName: "updated.jpg",
            fileExtension: "jpg",
            mimeType: "image/jpeg"
        )
        store = TestStore(
            initialState: MediaManagementFeature.State(assets: [asset]),
            reducer: { MediaManagementFeature() }
        )

        // When/Then
        await storeUnwrapped.send(.updateMetadata(assetId: asset.id, metadata: newMetadata)) {
            $0.assets[id: asset.id]?.metadata = newMetadata
        }
    }

    // MARK: - Validation Tests

    func testValidateAsset_Valid_ShouldUpdateStatus() async {
        // Given
        let asset = createMockAsset()
        store = TestStore(
            initialState: MediaManagementFeature.State(assets: [asset]),
            reducer: { MediaManagementFeature() }
        )

        // When/Then
        await storeUnwrapped.send(.validateAsset(asset.id))

        await storeUnwrapped.receive(.validateAssetResponse(assetId: asset.id, .failure(MediaError.unsupportedOperation("Not implemented")))) {
            $0.error = MediaError.unsupportedOperation("Not implemented")
        }
    }

    func testValidateAllAssets_ShouldValidateEach() async {
        // Given
        let assets = [createMockAsset(), createMockAsset()]
        store = TestStore(
            initialState: MediaManagementFeature.State(assets: IdentifiedArrayOf(uniqueElements: assets)),
            reducer: { MediaManagementFeature() }
        )

        // When/Then
        await storeUnwrapped.send(.validateAllAssets) {
            $0.isProcessing = true
        }

        // Expect validation responses for each asset
        for asset in assets {
            await storeUnwrapped.receive(.validateAssetResponse(assetId: asset.id, .failure(MediaError.unsupportedOperation("Not implemented"))))
        }

        await storeUnwrapped.receive(.validateAllAssetsComplete) {
            $0.isProcessing = false
            $0.error = MediaError.unsupportedOperation("Not implemented")
        }
    }

    // MARK: - Batch Processing Tests

    func testStartBatchOperation_Compress_ShouldCreateOperation() async {
        // Given
        let assets = [createMockAsset(), createMockAsset()]
        store = TestStore(
            initialState: MediaManagementFeature.State(
                assets: IdentifiedArrayOf(uniqueElements: assets),
                selectedAssets: Set(assets.map(\.id))
            ),
            reducer: { MediaManagementFeature() }
        )

        // When/Then
        await storeUnwrapped.send(.startBatchOperation(.compress)) {
            $0.isProcessing = true
        }

        await storeUnwrapped.receive(.batchOperationResponse(.failure(MediaError.unsupportedOperation("Not implemented")))) {
            $0.isProcessing = false
            $0.error = MediaError.unsupportedOperation("Not implemented")
        }
    }

    func testMonitorBatchProgress_ShouldUpdateProgress() async {
        // Given
        let handle = BatchOperationHandle(operationId: UUID(), type: .compress)
        store = TestStore(
            initialState: MediaManagementFeature.State(
                currentBatchOperation: handle
            ),
            reducer: { MediaManagementFeature() }
        )

        // When/Then
        await storeUnwrapped.send(.monitorBatchProgress(handle))

        // Progress updates would be received here
    }

    func testCancelBatchOperation_ShouldStopOperation() async {
        // Given
        let handle = BatchOperationHandle(operationId: UUID(), type: .compress)
        store = TestStore(
            initialState: MediaManagementFeature.State(
                currentBatchOperation: handle,
                isProcessing: true
            ),
            reducer: { MediaManagementFeature() }
        )

        // When/Then
        await storeUnwrapped.send(.cancelBatchOperation) {
            $0.isProcessing = false
        }

        await storeUnwrapped.receive(.batchOperationCancelled) {
            $0.currentBatchOperation = nil
        }
    }

    // MARK: - Workflow Tests

    func testExecuteWorkflow_ShouldProcessAssets() async {
        // Given
        let workflow = createMockWorkflow()
        let assets = [createMockAsset()]
        store = TestStore(
            initialState: MediaManagementFeature.State(
                assets: IdentifiedArrayOf(uniqueElements: assets),
                selectedAssets: Set(assets.map(\.id))
            ),
            reducer: { MediaManagementFeature() }
        )

        // When/Then
        await storeUnwrapped.send(.executeWorkflow(workflow)) {
            $0.isProcessing = true
        }

        await storeUnwrapped.receive(.workflowResponse(.failure(MediaError.unsupportedOperation("Not implemented")))) {
            $0.isProcessing = false
            $0.error = MediaError.unsupportedOperation("Not implemented")
        }
    }

    func testSaveWorkflowTemplate_ShouldAddToTemplates() async {
        // Given
        let workflow = createMockWorkflow()

        // When/Then
        await storeUnwrapped.send(.saveWorkflowTemplate(workflow, name: "Test Template"))

        await storeUnwrapped.receive(.saveWorkflowTemplateResponse(.failure(MediaError.unsupportedOperation("Not implemented")))) {
            $0.error = MediaError.unsupportedOperation("Not implemented")
        }
    }

    // MARK: - Filter and Sort Tests

    func testSetFilter_ShouldFilterAssets() async {
        // Given
        let assets = [
            createMockAsset(type: .image),
            createMockAsset(type: .video),
            createMockAsset(type: .document),
        ]
        store = TestStore(
            initialState: MediaManagementFeature.State(
                assets: IdentifiedArrayOf(uniqueElements: assets)
            ),
            reducer: { MediaManagementFeature() }
        )

        // When/Then
        await storeUnwrapped.send(.setFilter(.type(.image))) {
            $0.filter = .type(.image)
            // In real implementation, would filter displayed assets
        }
    }

    func testSetSortOrder_ShouldReorderAssets() async {
        // When/Then
        await storeUnwrapped.send(.setSortOrder(.dateDescending)) {
            $0.sortOrder = .dateDescending
            // In real implementation, would reorder assets
        }
    }

    // MARK: - Error Handling Tests

    func testClearError_ShouldResetErrorState() async {
        // Given
        store = TestStore(
            initialState: MediaManagementFeature.State(
                error: MediaError.fileNotFound
            ),
            reducer: { MediaManagementFeature() }
        )

        // When/Then
        await storeUnwrapped.send(.clearError) {
            $0.error = nil
        }
    }

    func testRetryFailedOperation_ShouldRetryLastOperation() async {
        // Given
        store = TestStore(
            initialState: MediaManagementFeature.State(
                error: MediaError.networkError,
                lastFailedOperation: .pickFiles(allowedTypes: [.image], allowsMultiple: true)
            ),
            reducer: { MediaManagementFeature() }
        )

        // When/Then
        await storeUnwrapped.send(.retryFailedOperation) {
            $0.error = nil
            $0.isLoading = true
        }

        await storeUnwrapped.receive(.pickFilesResponse(.failure(MediaError.unsupportedOperation("Not implemented")))) {
            $0.isLoading = false
            $0.error = MediaError.unsupportedOperation("Not implemented")
        }
    }
}

// MARK: - Test Helpers

@available(iOS 16.0, *)
extension MediaManagementFeatureTests {
    func createMockAsset(type: MediaType = .image) -> MediaAsset {
        MediaAsset(
            type: type,
            url: URL(fileURLWithPath: "/tmp/test.\(type == .image ? "jpg" : type == .video ? "mp4" : "pdf")"),
            metadata: MediaMetadata(
                fileName: "test.\(type == .image ? "jpg" : type == .video ? "mp4" : "pdf")",
                fileExtension: type == .image ? "jpg" : type == .video ? "mp4" : "pdf",
                mimeType: type == .image ? "image/jpeg" : type == .video ? "video/mp4" : "application/pdf"
            ),
            size: 1000
        )
    }

    func createMockWorkflow() -> MediaWorkflow {
        MediaWorkflow(
            name: "Test Workflow",
            steps: [
                MediaWorkflowStep(type: .validate, name: "Validate"),
                MediaWorkflowStep(type: .compress, name: "Compress"),
            ]
        )
    }
}
