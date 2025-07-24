#if os(iOS)
    import AIKOiOS
    import AppCore
    import ComposableArchitecture
    import SwiftUI
    import UIKit
    import UniformTypeIdentifiers

    /// iOS-specific implementation of AppView
    public struct IOSAppView: View {
        let store: StoreOf<AppFeature>

        public init(store: StoreOf<AppFeature>) {
            self.store = store
        }

        public var body: some View {
            WithViewStore(store, observe: { $0 }, content: { viewStore in
                IOSNavigationStack {
                    SharedAppView(
                        store: store,
                        services: IOSAppViewServices()
                    )
                }
                .preferredColorScheme(.dark)
                .tint(.white)
                .sheet(isPresented: .init(
                    get: { viewStore.showingDocumentScanner },
                    set: { viewStore.send(.showDocumentScanner($0)) }
                )) {
                    DocumentScannerView(
                        store: store.scope(
                            state: \.documentScanner,
                            action: \.documentScanner
                        )
                    )
                    .aikoSheet()
                }
                .sheet(isPresented: .init(
                    get: { viewStore.showingQuickDocumentScanner },
                    set: { viewStore.send(.showQuickDocumentScanner($0)) }
                )) {
                    DocumentScannerView(
                        store: store.scope(
                            state: \.documentScanner,
                            action: \.documentScanner
                        ),
                        mode: .quickScan
                    )
                    .aikoSheet()
                }
                .sheet(isPresented: .init(
                    get: { viewStore.showingShareSheet },
                    set: { _ in viewStore.send(.dismissShareSheet) }
                )) {
                    ShareSheetView(items: viewStore.shareItems)
                }
            })
        }
    }

    /// iOS-specific navigation stack that handles version differences
    struct IOSNavigationStack<Content: View>: View {
        @ViewBuilder let content: () -> Content

        var body: some View {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    content()
                        .navigationBarHidden(true)
                }
            } else {
                SwiftUI.NavigationView {
                    content()
                        .navigationBarHidden(true)
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
    }

    /// iOS implementation of platform services
    struct IOSAppViewServices: @preconcurrency AppViewPlatformServices {
        typealias NavigationStack = AnyView
        typealias DocumentPickerView = IOSDocumentPicker
        typealias ImagePickerView = IOSImagePicker
        typealias ShareView = ShareSheetView

        @MainActor
        func makeNavigationStack(@ViewBuilder content: @escaping () -> some View) -> AnyView {
            AnyView(IOSNavigationStack(content: content))
        }

        func makeDocumentPicker(onDocumentsPicked: @escaping ([(Data, String)]) -> Void) -> IOSDocumentPicker {
            IOSDocumentPicker(onDocumentsPicked: onDocumentsPicked)
        }

        func makeImagePicker(onImagePicked: @escaping (Data) -> Void) -> IOSImagePicker {
            IOSImagePicker(onImagePicked: onImagePicked)
        }

        @MainActor
        func makeShareSheet(items: [Any]) -> ShareSheetView? {
            ShareSheetView(items: items)
        }

        func loadImage(from data: Data) -> Image? {
            if let uiImage = UIImage(data: data) {
                return Image(uiImage: uiImage)
            }
            return nil
        }

        func getAppIcon() -> Image? {
            // Try multiple loading methods to ensure it works in previews

            // Method 1: Try loading from bundle with different approaches
            if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
               let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data) {
                return Image(uiImage: uiImage)
            }

            // Method 2: Try named image loading
            if let uiImage = UIImage(named: "AppIcon", in: Bundle.main, compatibleWith: nil) {
                return Image(uiImage: uiImage)
            }

            // Method 3: Try without specifying bundle (for previews)
            if let uiImage = UIImage(named: "AppIcon") {
                return Image(uiImage: uiImage)
            }

            // Method 4: Try from module bundle (for SPM)
            if let bundleURL = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
               let data = try? Data(contentsOf: bundleURL),
               let uiImage = UIImage(data: data) {
                return Image(uiImage: uiImage)
            }

            return nil
        }
    }

    // MARK: - iOS-specific Image Loading

    extension IOSAppViewServices: PlatformImageLoader {
        func loadImage(named name: String, in bundle: Bundle?) -> Image? {
            if let uiImage = UIImage(named: name, in: bundle ?? Bundle.main, compatibleWith: nil) {
                return Image(uiImage: uiImage)
            }
            return nil
        }

        func loadImage(from url: URL) -> Image? {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return loadImage(from: data)
        }
    }

    // MARK: - iOS Document Picker

    struct IOSDocumentPicker: UIViewControllerRepresentable {
        let onDocumentsPicked: ([(Data, String)]) -> Void

        func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
                .pdf,
                .plainText,
                .rtf,
                UTType("com.microsoft.word.doc") ?? .data,
                UTType("org.openxmlformats.wordprocessingml.document") ?? .data,
            ])
            picker.delegate = context.coordinator
            picker.allowsMultipleSelection = true
            return picker
        }

        func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        class Coordinator: NSObject, UIDocumentPickerDelegate {
            let parent: IOSDocumentPicker

            init(_ parent: IOSDocumentPicker) {
                self.parent = parent
            }

            func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
                var documents: [(Data, String)] = []

                for url in urls {
                    do {
                        // Start accessing the security-scoped resource
                        guard url.startAccessingSecurityScopedResource() else {
                            print("Failed to access security-scoped resource")
                            continue
                        }

                        defer {
                            url.stopAccessingSecurityScopedResource()
                        }

                        let data = try Data(contentsOf: url)
                        let fileName = url.lastPathComponent
                        documents.append((data, fileName))
                    } catch {
                        print("Error reading document \(url.lastPathComponent): \(error)")
                    }
                }

                if !documents.isEmpty {
                    DispatchQueue.main.async {
                        self.parent.onDocumentsPicked(documents)
                    }
                }
            }
        }
    }

    // MARK: - iOS Image Picker

    struct IOSImagePicker: View {
        let onImagePicked: (Data) -> Void

        var body: some View {
            if #available(iOS 16.0, *) {
                IOSDocumentScanner { scannedDocuments in
                    // Convert to single image data
                    if let firstDocument = scannedDocuments.first {
                        onImagePicked(firstDocument.0)
                    }
                }
            } else {
                // Fallback for older iOS versions - single image capture
                IOSCameraImagePicker { imageData in
                    onImagePicked(imageData)
                }
            }
        }
    }

    // MARK: - iOS Document Scanner

    @available(iOS 16.0, *)
    struct IOSDocumentScanner: UIViewControllerRepresentable {
        let onDocumentsScanned: ([(Data, String)]) -> Void

        func makeUIViewController(context _: Context) -> UIViewController {
            let adapter = VisionKitAdapter()

            // Set completion handler
            adapter.uiManager.setCompletion { (result: VisionKitAdapter.ScanResult) in
                switch result {
                case let .success(document):
                    var documents: [(Data, String)] = []

                    for (index, page) in document.pages.enumerated() {
                        let fileName = "Scanned_Document_\(index + 1).jpg"
                        documents.append((page.imageData, fileName))
                    }

                    if !documents.isEmpty {
                        DispatchQueue.main.async {
                            onDocumentsScanned(documents)
                        }
                    }
                case .cancelled, .failed:
                    // Handle cancellation or error - no documents to return
                    break
                }
            }

            // Return the actual UIViewController
            return adapter.createDocumentCameraViewController()
        }

        func updateUIViewController(_: UIViewController, context _: Context) {}

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        class Coordinator: NSObject {
            // Minimal coordinator for compatibility with VisionKitAdapter
        }
    }

    // MARK: - iOS Camera Image Picker (Fallback)

    struct IOSCameraImagePicker: UIViewControllerRepresentable {
        let onImagePicked: (Data) -> Void

        func makeUIViewController(context: Context) -> UIImagePickerController {
            let picker = UIImagePickerController()
            picker.delegate = context.coordinator
            picker.sourceType = .camera
            picker.allowsEditing = false
            return picker
        }

        func updateUIViewController(_: UIImagePickerController, context _: Context) {}

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
            let parent: IOSCameraImagePicker

            init(_ parent: IOSCameraImagePicker) {
                self.parent = parent
            }

            func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
                if let image = info[.originalImage] as? UIImage,
                   let imageData = image.jpegData(compressionQuality: 0.8) {
                    DispatchQueue.main.async {
                        self.parent.onImagePicked(imageData)
                    }
                }
                picker.dismiss(animated: true)
            }

            func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
                picker.dismiss(animated: true)
            }
        }
    }

    // MARK: - iOS Share Sheet

    struct ShareSheetView: UIViewControllerRepresentable {
        let items: [Any]

        func makeUIViewController(context _: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: items, applicationActivities: nil)
        }

        func updateUIViewController(_: UIActivityViewController, context _: Context) {}
    }
#endif
