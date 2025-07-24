#if os(macOS)
    import AppCore
    import AppKit
    import ComposableArchitecture
    import SwiftUI

    /// macOS-specific implementation of AppView
    public struct MacOSAppView: View {
        let store: StoreOf<AppFeature>

        public init(store: StoreOf<AppFeature>) {
            self.store = store
        }

        public var body: some View {
            WithViewStore(store, observe: { $0 }, content: { viewStore in
                SharedAppView(
                    store: store,
                    services: MacOSAppViewServices()
                )
                .preferredColorScheme(.dark)
                .sheet(isPresented: .init(
                    get: { viewStore.showingDocumentScanner },
                    set: { viewStore.send(.showDocumentScanner($0)) }
                )) {
                    Text("Document scanning is not available on macOS")
                        .font(.title)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .aikoSheet()
                }
            })
        }
    }

    /// macOS implementation of platform services
    struct MacOSAppViewServices: AppViewPlatformServices {
        typealias NavigationStack = AnyView
        typealias DocumentPickerView = MacOSDocumentPicker
        typealias ImagePickerView = MacOSImagePicker
        typealias ShareView = EmptyView

        func makeNavigationStack(@ViewBuilder content: @escaping () -> some View) -> AnyView {
            AnyView(SwiftUI.NavigationView {
                content()
            })
        }

        @MainActor
        func makeDocumentPicker(onDocumentsPicked: @escaping ([(Data, String)]) -> Void) -> MacOSDocumentPicker {
            MacOSDocumentPicker(onDocumentsPicked: onDocumentsPicked)
        }

        @MainActor
        func makeImagePicker(onImagePicked: @escaping (Data) -> Void) -> MacOSImagePicker {
            MacOSImagePicker(onImagePicked: onImagePicked)
        }

        func makeShareSheet(items _: [Any]) -> EmptyView? {
            // macOS doesn't use share sheets in the same way as iOS
            // Would implement NSSharingServicePicker if needed
            nil
        }

        func loadImage(from data: Data) -> Image? {
            if let nsImage = NSImage(data: data) {
                return Image(nsImage: nsImage)
            }
            return nil
        }

        func getAppIcon() -> Image? {
            // Try multiple loading methods to ensure it works in previews

            // Method 1: Try loading from bundle with different approaches
            if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
               let data = try? Data(contentsOf: url),
               let nsImage = NSImage(data: data) {
                return Image(nsImage: nsImage)
            }

            // Method 2: Try named image loading
            if let nsImage = NSImage(named: "AppIcon") {
                return Image(nsImage: nsImage)
            }

            // Method 3: Try from module bundle (for SPM)
            if let bundleURL = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
               let data = try? Data(contentsOf: bundleURL),
               let nsImage = NSImage(data: data) {
                return Image(nsImage: nsImage)
            }

            return nil
        }
    }

    // MARK: - macOS-specific Image Loading

    extension MacOSAppViewServices: PlatformImageLoader {
        func loadImage(named name: String, in _: Bundle?) -> Image? {
            if let nsImage = NSImage(named: name) {
                return Image(nsImage: nsImage)
            }
            return nil
        }

        func loadImage(from url: URL) -> Image? {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return loadImage(from: data)
        }
    }

    // MARK: - macOS Document Picker

    struct MacOSDocumentPicker: View {
        let onDocumentsPicked: ([(Data, String)]) -> Void

        var body: some View {
            Button("Select Documents") {
                selectDocuments()
            }
            .padding()
        }

        private func selectDocuments() {
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = true
            openPanel.canChooseDirectories = false
            openPanel.allowsMultipleSelection = true
            openPanel.allowedContentTypes = [
                .pdf,
                .plainText,
                .rtf,
                .data, // For Word documents
            ]

            openPanel.begin { response in
                if response == .OK {
                    var documents: [(Data, String)] = []

                    for url in openPanel.urls {
                        do {
                            let data = try Data(contentsOf: url)
                            let fileName = url.lastPathComponent
                            documents.append((data, fileName))
                        } catch {
                            print("Error reading document \(url.lastPathComponent): \(error)")
                        }
                    }

                    if !documents.isEmpty {
                        DispatchQueue.main.async {
                            onDocumentsPicked(documents)
                        }
                    }
                }
            }
        }
    }

    // MARK: - macOS Image Picker

    struct MacOSImagePicker: View {
        let onImagePicked: (Data) -> Void

        var body: some View {
            Button("Select Image") {
                selectImage()
            }
            .padding()
        }

        private func selectImage() {
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = true
            openPanel.canChooseDirectories = false
            openPanel.allowsMultipleSelection = false
            openPanel.allowedContentTypes = [
                .image,
                .jpeg,
                .png,
                .tiff,
            ]

            openPanel.begin { response in
                if response == .OK, let url = openPanel.url {
                    do {
                        let data = try Data(contentsOf: url)
                        DispatchQueue.main.async {
                            onImagePicked(data)
                        }
                    } catch {
                        print("Error reading image: \(error)")
                    }
                }
            }
        }
    }
#endif
