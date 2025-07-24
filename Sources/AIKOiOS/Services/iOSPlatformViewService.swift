#if os(iOS)
    import AppCore
    import SwiftUI

    public final class IOSPlatformViewService: PlatformViewServiceProtocol {
        public init() {}

        public func createNavigationStack(@ViewBuilder content: @escaping () -> some View) -> AnyView {
            AnyView(
                IOSNavigationStack(content: content)
            )
        }

        public func createDocumentPicker(onDocumentsPicked: @escaping ([(Data, String)]) -> Void) -> AnyView {
            AnyView(
                IOSDocumentPickerView(onDocumentsPicked: onDocumentsPicked)
            )
        }

        public func createImagePicker(onImagePicked: @escaping (Data) -> Void) -> AnyView {
            AnyView(
                IOSImagePickerView(onImagePicked: onImagePicked)
            )
        }

        public func createShareSheet(items: [Any]) -> AnyView {
            AnyView(
                IOSShareButton(items: items)
            )
        }

        public func createSidebarNavigation(
            @ViewBuilder sidebar: @escaping () -> some View,
            @ViewBuilder detail: @escaping () -> some View
        ) -> AnyView {
            // iOS doesn't have true sidebar navigation, fall back to detail view
            AnyView(detail())
        }

        public func applyWindowStyle(to view: AnyView) -> AnyView {
            AnyView(
                view
                    .navigationViewStyle(.automatic)
                    .modifier(IOSNavigationBarStyleModifier())
            )
        }

        public func applyToolbarStyle(to view: AnyView) -> AnyView {
            AnyView(
                view
                    .toolbar(.automatic, for: .navigationBar)
            )
        }

        public func createDropZone(
            @ViewBuilder content: @escaping () -> some View,
            onItemsDropped _: @escaping ([Any]) -> Void
        ) -> AnyView {
            // iOS doesn't support drag and drop in the same way as macOS
            AnyView(content())
        }
    }
#endif
