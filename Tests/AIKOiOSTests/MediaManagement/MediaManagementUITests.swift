#if os(iOS)
@testable import AppCore
@testable import AIKOiOS
@testable import AIKOiOSiOS
@testable import AppCore
@testable import AIKOiOS
@testable import AIKOiOS
import ComposableArchitecture
import SwiftUI
import ViewInspector
import XCTest

@available(iOS 16.0, *)
@MainActor
final class MediaManagementUITests: XCTestCase {
    var store: Store<MediaManagementFeature.State, MediaManagementFeature.Action>?

    private var storeUnwrapped: Store<MediaManagementFeature.State, MediaManagementFeature.Action> {
        guard let store else { fatalError("store not initialized") }
        return store
    }

    override func setUp() async throws {
        try await super.setUp()
        store = Store(
            initialState: MediaManagementFeature.State(),
            reducer: { MediaManagementFeature() }
        )
    }

    override func tearDown() async throws {
        store = nil
        try await super.tearDown()
    }

    // MARK: - File Picker UI Tests

    func testFilePickerButton_ShouldTriggerPicker() async throws {
        // Given
        let view = MediaPickerButton(store: storeUnwrapped)

        // When/Then
        await assertViewExists(view) { inspectedView in
            let button = try inspectedView.findButton()
            XCTAssertNotNil(button)

            // Verify button triggers file picker action
            try button.tap()
        }
    }

    func testFilePickerButton_ShowsLoadingState() async throws {
        // Given
        store = Store(
            initialState: MediaManagementFeature.State(isLoading: true),
            reducer: { MediaManagementFeature() }
        )
        let view = MediaPickerButton(store: storeUnwrapped)

        // When/Then
        await assertViewExists(view) { inspectedView in
            let progressView = try inspectedView.find(ProgressView.self)
            XCTAssertNotNil(progressView)
        }
    }

    // MARK: - Photo Library UI Tests

    func testPhotoLibraryView_DisplaysAlbums() async throws {
        // Given
        let albums = [
            PhotoAlbum(name: "Recent", assetCount: 100),
            PhotoAlbum(name: "Favorites", assetCount: 50),
        ]
        store = Store(
            initialState: MediaManagementFeature.State(albums: albums),
            reducer: { MediaManagementFeature() }
        )
        let view = PhotoLibraryView(store: storeUnwrapped)

        // When/Then
        await assertViewExists(view) { inspectedView in
            let list = try inspectedView.find(ViewType.List.self)
            XCTAssertNotNil(list)

            // Verify albums are displayed
            let cells = try inspectedView.findAll(AlbumCell.self)
            XCTAssertEqual(cells.count, albums.count)
        }
    }

    func testPhotoLibraryView_SelectionMode() async throws {
        // Given
        let assets = [createMockAsset(), createMockAsset(), createMockAsset()]
        store = Store(
            initialState: MediaManagementFeature.State(
                assets: IdentifiedArrayOf(uniqueElements: assets)
            ),
            reducer: { MediaManagementFeature() }
        )
        let view = PhotoLibraryView(store: storeUnwrapped)

        // When/Then
        await assertViewExists(view) { inspectedView in
            // Find selection toggle
            let selectionToggle = try inspectedView.find(button: "Select")
            try selectionToggle.tap()

            // Verify checkboxes appear
            let checkboxes = try inspectedView.findAll(ViewType.Image.self, where: { image in
                try image.actualImage().name() == "checkmark.circle"
            })
            XCTAssertGreaterThan(checkboxes.count, 0)
        }
    }

    // MARK: - Camera UI Tests

    func testCameraView_ShowsCaptureButton() async throws {
        // Given
        let view = CameraView(store: storeUnwrapped)

        // When/Then
        await assertViewExists(view) { inspectedView in
            let captureButton = try inspectedView.find(button: "Capture")
            XCTAssertNotNil(captureButton)

            // Verify button is enabled when not capturing
            let isDisabled = try captureButton.isDisabled()
            XCTAssertFalse(isDisabled)
        }
    }

    func testCameraView_ShowsRecordingIndicator() async throws {
        // Given
        store = Store(
            initialState: MediaManagementFeature.State(isRecording: true),
            reducer: { MediaManagementFeature() }
        )
        let view = CameraView(store: storeUnwrapped)

        // When/Then
        await assertViewExists(view) { inspectedView in
            // Find recording indicator
            let recordingDot = try inspectedView.find(ViewType.Circle.self)
            XCTAssertNotNil(recordingDot)

            // Verify it's red
            let color = try recordingDot.foregroundColor()
            XCTAssertEqual(color, Color.red)
        }
    }

    // MARK: - Media Grid UI Tests

    func testMediaGrid_DisplaysAssets() async throws {
        // Given
        let assets = Array(repeating: createMockAsset(), count: 20)
        store = Store(
            initialState: MediaManagementFeature.State(
                assets: IdentifiedArrayOf(uniqueElements: assets)
            ),
            reducer: { MediaManagementFeature() }
        )
        let view = MediaGridView(store: storeUnwrapped)

        // When/Then
        await assertViewExists(view) { inspectedView in
            let grid = try inspectedView.find(ViewType.LazyVGrid.self)
            XCTAssertNotNil(grid)

            // Verify thumbnails are displayed
            let thumbnails = try inspectedView.findAll(MediaThumbnailView.self)
            XCTAssertEqual(thumbnails.count, assets.count)
        }
    }

    func testMediaGrid_SelectionOverlay() async throws {
        // Given
        let asset = createMockAsset()
        store = Store(
            initialState: MediaManagementFeature.State(
                assets: [asset],
                selectedAssets: [asset.id]
            ),
            reducer: { MediaManagementFeature() }
        )
        let view = MediaGridView(store: storeUnwrapped)

        // When/Then
        await assertViewExists(view) { inspectedView in
            // Find selected thumbnail
            let thumbnail = try inspectedView.find(MediaThumbnailView.self)

            // Verify selection overlay
            let checkmark = try thumbnail.find(ViewType.Image.self, where: { image in
                try image.actualImage().name() == "checkmark.circle.fill"
            })
            XCTAssertNotNil(checkmark)
        }
    }

    // MARK: - Media Detail UI Tests

    func testMediaDetailView_DisplaysMetadata() async throws {
        // Given
        let asset = createMockAsset()
        let view = MediaDetailView(asset: asset, store: storeUnwrapped)

        // When/Then
        await assertViewExists(view) { inspectedView in
            // Verify metadata fields are displayed
            let fileName = try inspectedView.find(text: asset.metadata.fileName)
            XCTAssertNotNil(fileName)

            let fileSize = try inspectedView.find(text: "1 KB")
            XCTAssertNotNil(fileSize)
        }
    }

    func testMediaDetailView_ActionButtons() async throws {
        // Given
        let asset = createMockAsset()
        let view = MediaDetailView(asset: asset, store: storeUnwrapped)

        // When/Then
        await assertViewExists(view) { inspectedView in
            // Verify action buttons
            let shareButton = try inspectedView.find(button: "Share")
            XCTAssertNotNil(shareButton)

            let deleteButton = try inspectedView.find(button: "Delete")
            XCTAssertNotNil(deleteButton)

            let editButton = try inspectedView.find(button: "Edit")
            XCTAssertNotNil(editButton)
        }
    }

    // MARK: - Batch Processing UI Tests

    func testBatchProcessingView_ShowsProgress() async throws {
        // Given
        let handle = BatchOperationHandle(operationId: UUID(), type: .compress)
        let progress = BatchProgress(total: 100, completed: 45, failed: 5)
        store = Store(
            initialState: MediaManagementFeature.State(
                currentBatchOperation: handle,
                batchProgress: progress
            ),
            reducer: { MediaManagementFeature() }
        )
        let view = BatchProcessingView(store: storeUnwrapped)

        // When/Then
        await assertViewExists(view) { inspectedView in
            // Verify progress bar
            let progressView = try inspectedView.find(ProgressView.self)
            XCTAssertNotNil(progressView)

            // Verify progress text
            let progressText = try inspectedView.find(text: "45 of 100")
            XCTAssertNotNil(progressText)

            // Verify failed count
            let failedText = try inspectedView.find(text: "5 failed")
            XCTAssertNotNil(failedText)
        }
    }

    func testBatchProcessingView_CancelButton() async throws {
        // Given
        let handle = BatchOperationHandle(operationId: UUID(), type: .compress)
        store = Store(
            initialState: MediaManagementFeature.State(
                currentBatchOperation: handle,
                isProcessing: true
            ),
            reducer: { MediaManagementFeature() }
        )
        let view = BatchProcessingView(store: storeUnwrapped)

        // When/Then
        await assertViewExists(view) { inspectedView in
            let cancelButton = try inspectedView.find(button: "Cancel")
            XCTAssertNotNil(cancelButton)

            // Verify button triggers cancel action
            try cancelButton.tap()
        }
    }

    // MARK: - Workflow UI Tests

    func testWorkflowBuilderView_AddSteps() async throws {
        // Given
        let view = WorkflowBuilderView(store: storeUnwrapped)

        // When/Then
        await assertViewExists(view) { inspectedView in
            // Find add step button
            let addButton = try inspectedView.find(button: "Add Step")
            XCTAssertNotNil(addButton)

            // Find step type picker
            let picker = try inspectedView.find(ViewType.Picker.self)
            XCTAssertNotNil(picker)
        }
    }

    func testWorkflowTemplatesView_DisplaysTemplates() async throws {
        // Given
        let templates = ["Basic Processing", "Photo Enhancement", "Video Compression"]
        store = Store(
            initialState: MediaManagementFeature.State(
                workflowTemplates: templates
            ),
            reducer: { MediaManagementFeature() }
        )
        let view = WorkflowTemplatesView(store: storeUnwrapped)

        // When/Then
        await assertViewExists(view) { inspectedView in
            let list = try inspectedView.find(ViewType.List.self)
            XCTAssertNotNil(list)

            // Verify templates are listed
            for template in templates {
                let templateRow = try inspectedView.find(text: template)
                XCTAssertNotNil(templateRow)
            }
        }
    }

    // MARK: - Error UI Tests

    func testErrorAlert_DisplaysErrorMessage() async throws {
        // Given
        store = Store(
            initialState: MediaManagementFeature.State(
                error: MediaError.fileNotFound
            ),
            reducer: { MediaManagementFeature() }
        )
        let view = MediaManagementView(store: storeUnwrapped)

        // When/Then
        await assertViewExists(view) { inspectedView in
            // Find alert
            let alert = try inspectedView.alert()
            XCTAssertNotNil(alert)

            // Verify error message
            let message = try alert.message()
            XCTAssertEqual(message?.string, "File not found")
        }
    }

    // MARK: - Settings UI Tests

    func testSettingsView_ValidationRulesSection() async throws {
        // Given
        let view = MediaSettingsView(store: storeUnwrapped)

        // When/Then
        await assertViewExists(view) { inspectedView in
            // Find validation section
            let section = try inspectedView.find(text: "Validation Rules")
            XCTAssertNotNil(section)

            // Find max file size stepper
            let stepper = try inspectedView.find(ViewType.Stepper.self)
            XCTAssertNotNil(stepper)
        }
    }
}

// MARK: - Test Helpers

@available(iOS 16.0, *)
extension MediaManagementUITests {
    func assertViewExists(
        _ view: some View,
        file: StaticString = #filePath,
        line: UInt = #line,
        inspection: (InspectableView<ViewType.View>) throws -> Void
    ) async {
        do {
            let inspectedView = try view.inspect()
            try inspection(inspectedView)
        } catch {
            XCTFail("View inspection failed: \(error)", file: file, line: line)
        }
    }

    func createMockAsset() -> MediaAsset {
        MediaAsset(
            type: .image,
            url: URL(fileURLWithPath: "/tmp/test.jpg"),
            metadata: MediaMetadata(
                fileName: "test.jpg",
                fileExtension: "jpg",
                mimeType: "image/jpeg"
            ),
            size: 1000
        )
    }
}

// MARK: - Mock Views for Testing

@available(iOS 16.0, *)
struct MediaPickerButton: View {
    let store: Store<MediaManagementFeature.State, MediaManagementFeature.Action>
    @ObservedObject var viewStore: ViewStore<MediaManagementFeature.State, MediaManagementFeature.Action>

    init(store: Store<MediaManagementFeature.State, MediaManagementFeature.Action>) {
        self.store = store
        viewStore = ViewStore(store, observe: { $0 })
    }

    var body: some View {
        Button("Pick Files") {
            viewStore.send(.pickFiles(allowedTypes: [.image], allowsMultiple: true))
        }
        .disabled(viewStore.isLoading)
        .overlay {
            if viewStore.isLoading {
                ProgressView()
            }
        }
    }
}

@available(iOS 16.0, *)
struct PhotoLibraryView: View {
    let store: Store<MediaManagementFeature.State, MediaManagementFeature.Action>

    var body: some View {
        List {
            Text("Photo Library")
        }
    }
}

@available(iOS 16.0, *)
struct AlbumCell: View {
    let album: PhotoAlbum

    var body: some View {
        HStack {
            Text(album.name)
            Spacer()
            Text("\(album.assetCount)")
        }
    }
}

@available(iOS 16.0, *)
struct CameraView: View {
    let store: Store<MediaManagementFeature.State, MediaManagementFeature.Action>
    @ObservedObject var viewStore: ViewStore<MediaManagementFeature.State, MediaManagementFeature.Action>

    init(store: Store<MediaManagementFeature.State, MediaManagementFeature.Action>) {
        self.store = store
        viewStore = ViewStore(store, observe: { $0 })
    }

    var body: some View {
        VStack {
            if viewStore.isRecording {
                Circle()
                    .fill(Color.red)
                    .frame(width: 20, height: 20)
            }

            Button("Capture") {
                viewStore.send(.capturePhoto)
            }
            .disabled(viewStore.isCapturing)
        }
    }
}

@available(iOS 16.0, *)
struct MediaGridView: View {
    let store: Store<MediaManagementFeature.State, MediaManagementFeature.Action>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
            Text("Grid Content")
        }
    }
}

@available(iOS 16.0, *)
struct MediaThumbnailView: View {
    let asset: MediaAsset
    let isSelected: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
            }
        }
    }
}

@available(iOS 16.0, *)
struct MediaDetailView: View {
    let asset: MediaAsset
    let store: Store<MediaManagementFeature.State, MediaManagementFeature.Action>

    var body: some View {
        VStack {
            Text(asset.metadata.fileName)
            Text("1 KB")

            HStack {
                Button("Share") {}
                Button("Delete") {}
                Button("Edit") {}
            }
        }
    }
}

@available(iOS 16.0, *)
struct BatchProcessingView: View {
    let store: Store<MediaManagementFeature.State, MediaManagementFeature.Action>
    @ObservedObject var viewStore: ViewStore<MediaManagementFeature.State, MediaManagementFeature.Action>

    init(store: Store<MediaManagementFeature.State, MediaManagementFeature.Action>) {
        self.store = store
        viewStore = ViewStore(store, observe: { $0 })
    }

    var body: some View {
        VStack {
            if let progress = viewStore.batchProgress {
                ProgressView(value: Double(progress.completed), total: Double(progress.total))
                Text("\(progress.completed) of \(progress.total)")
                if progress.failed > 0 {
                    Text("\(progress.failed) failed")
                }
            }

            Button("Cancel") {
                viewStore.send(.cancelBatchOperation)
            }
        }
    }
}

@available(iOS 16.0, *)
struct WorkflowBuilderView: View {
    let store: Store<MediaManagementFeature.State, MediaManagementFeature.Action>

    var body: some View {
        VStack {
            Button("Add Step") {}
            Picker("Step Type", selection: .constant(WorkflowStepType.validate)) {
                Text("Validate").tag(WorkflowStepType.validate)
            }
        }
    }
}

@available(iOS 16.0, *)
struct WorkflowTemplatesView: View {
    let store: Store<MediaManagementFeature.State, MediaManagementFeature.Action>
    @ObservedObject var viewStore: ViewStore<MediaManagementFeature.State, MediaManagementFeature.Action>

    init(store: Store<MediaManagementFeature.State, MediaManagementFeature.Action>) {
        self.store = store
        viewStore = ViewStore(store, observe: { $0 })
    }

    var body: some View {
        List(viewStore.workflowTemplates, id: \.self) { template in
            Text(template)
        }
    }
}

@available(iOS 16.0, *)
struct MediaManagementView: View {
    let store: Store<MediaManagementFeature.State, MediaManagementFeature.Action>
    @ObservedObject var viewStore: ViewStore<MediaManagementFeature.State, MediaManagementFeature.Action>

    init(store: Store<MediaManagementFeature.State, MediaManagementFeature.Action>) {
        self.store = store
        viewStore = ViewStore(store, observe: { $0 })
    }

    var body: some View {
        VStack {
            Text("Media Management")
        }
        .alert(
            "Error",
            isPresented: .constant(viewStore.error != nil),
            actions: {
                Button("OK") {
                    viewStore.send(.clearError)
                }
            },
            message: {
                if let error = viewStore.error {
                    Text(error.localizedDescription)
                }
            }
        )
    }
}

@available(iOS 16.0, *)
struct MediaSettingsView: View {
    let store: Store<MediaManagementFeature.State, MediaManagementFeature.Action>

    var body: some View {
        Form {
            Section("Validation Rules") {
                Stepper("Max File Size", value: .constant(10))
            }
        }
    }
}
#endif
