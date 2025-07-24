#if os(iOS)
    import AppCore
    import ComposableArchitecture
    import SwiftUI
    import UIKit

    /// iOS-specific implementation of MenuView
    public struct IOSMenuView: View {
        let store: StoreOf<AppFeature>
        @Binding var isShowing: Bool
        @Binding var selectedMenuItem: AppFeature.MenuItem?

        @State private var profileImage: UIImage?
        @State private var showingImagePicker = false
        @State private var showingImageSourceDialog = false

        public init(store: StoreOf<AppFeature>, isShowing: Binding<Bool>, selectedMenuItem: Binding<AppFeature.MenuItem?>) {
            self.store = store
            _isShowing = isShowing
            _selectedMenuItem = selectedMenuItem
        }

        public var body: some View {
            HStack(spacing: 0) {
                // Tap outside to close
                Color.black.opacity(0.3)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isShowing = false
                        }
                    }
                    .frame(width: 100)

                // Menu content
                menuContent
            }
            .sheet(isPresented: $showingImagePicker) {
                IOSProfileImagePicker(
                    onImageSelected: { data in
                        if let uiImage = UIImage(data: data) {
                            profileImage = uiImage
                        }
                    }
                )
            }
        }

        // MARK: - Menu Content

        @ViewBuilder
        private var menuContent: some View {
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 0) {
                    // Safe area spacer for Dynamic Island/notch
                    Color.black
                        .frame(height: geometry.safeAreaInsets.top)
                        .ignoresSafeArea(edges: .top)

                    profileSection

                    Divider()
                        .background(Color.gray.opacity(0.3))

                    menuItemsList

                    Spacer()

                    // Footer
                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        Divider()
                            .background(Color.gray.opacity(0.3))

                        Text("AIKO v1.0.0")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text("AI Contract Intelligence Officer")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(Theme.Spacing.large)
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
                }
                .frame(width: 300)
                .frame(maxHeight: .infinity)
                .background(
                    Color.black
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.05),
                                    Color.clear,
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .edgesIgnoringSafeArea(.vertical)
            }
            .frame(width: 300)
        }

        // MARK: - Profile Section

        private var profileSection: some View {
            HStack(spacing: Theme.Spacing.medium) {
                profileButton

                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("AIKO User")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(Theme.Spacing.large)
        }

        @ViewBuilder
        private var profileButton: some View {
            Button(action: { showingImageSourceDialog = true }) {
                ZStack {
                    profileImageView
                    cameraIconOverlay
                }
            }
            .confirmationDialog("Choose Photo Source", isPresented: $showingImageSourceDialog) {
                photoSourceButtons
            }
        }

        @ViewBuilder
        private var profileImageView: some View {
            if let image = profileImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Theme.Colors.aikoPrimary, lineWidth: 2)
                    )
            } else {
                Circle()
                    .fill(Theme.Colors.aikoSecondary)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            }
        }

        private var cameraIconOverlay: some View {
            Circle()
                .fill(Theme.Colors.aikoPrimary)
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: "camera.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                )
                .offset(x: 20, y: 20)
        }

        @ViewBuilder
        private var photoSourceButtons: some View {
            Button("Select Photo") {
                showingImagePicker = true
            }

            if profileImage != nil {
                Button("Remove Photo", role: .destructive) {
                    profileImage = nil
                }
            }

            Button("Cancel", role: .cancel) {}
        }

        // MARK: - Menu Items List

        @ViewBuilder
        private var menuItemsList: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    WithViewStore(store, observe: { $0 }, content: { viewStore in
                        ForEach(AppFeature.MenuItem.allCases, id: \.self) { item in
                            if item == .quickReferences {
                                quickReferencesSection(viewStore: viewStore, item: item)
                            } else {
                                regularMenuItem(item: item)
                            }
                        }
                    })
                }
                .padding(Theme.Spacing.medium)
            }
        }

        @ViewBuilder
        private func quickReferencesSection(viewStore: ViewStore<AppFeature.State, AppFeature.Action>, item: AppFeature.MenuItem) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                quickReferencesButton(viewStore: viewStore, item: item)

                if viewStore.showingQuickReferences {
                    quickReferencesSubmenu(viewStore: viewStore)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewStore.showingQuickReferences)
        }

        private func quickReferencesButton(viewStore: ViewStore<AppFeature.State, AppFeature.Action>, item: AppFeature.MenuItem) -> some View {
            Button(action: {
                viewStore.send(.toggleQuickReferences(!viewStore.showingQuickReferences))
            }) {
                HStack(spacing: Theme.Spacing.medium) {
                    Image(systemName: item.icon)
                        .font(.title3)
                        .foregroundColor(Theme.Colors.aikoPrimary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.rawValue)
                            .font(.subheadline)
                            .fontWeight(viewStore.showingQuickReferences ? .semibold : .regular)
                            .foregroundColor(.white)

                        Text(item.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: viewStore.showingQuickReferences ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.vertical, Theme.Spacing.small)
                .padding(.horizontal, Theme.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                        .fill(viewStore.showingQuickReferences ? Color.blue.opacity(0.1) : Color.clear)
                )
            }
            .buttonStyle(.plain)
        }

        private func quickReferencesSubmenu(viewStore: ViewStore<AppFeature.State, AppFeature.Action>) -> some View {
            VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                ForEach(AppFeature.QuickReference.allCases, id: \.self) { reference in
                    quickReferenceButton(reference: reference, viewStore: viewStore)
                }
            }
        }

        private func quickReferenceButton(reference: AppFeature.QuickReference, viewStore: ViewStore<AppFeature.State, AppFeature.Action>) -> some View {
            Button(action: {
                viewStore.send(.selectQuickReference(reference))
            }) {
                HStack(spacing: Theme.Spacing.medium) {
                    Image(systemName: reference.icon)
                        .font(.body)
                        .foregroundColor(.blue)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(reference.rawValue)
                            .font(.subheadline)
                            .foregroundColor(.white)

                        Text(reference.description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(.blue.opacity(0.6))
                }
                .padding(.vertical, Theme.Spacing.small)
                .padding(.leading, Theme.Spacing.extraLarge + Theme.Spacing.medium)
                .padding(.trailing, Theme.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                        .fill(Color.blue.opacity(0.05))
                )
            }
            .buttonStyle(.plain)
        }

        private func regularMenuItem(item: AppFeature.MenuItem) -> some View {
            WithViewStore(store, observe: { $0 }, content: { viewStore in
                MenuItemRow(
                    item: item,
                    isSelected: selectedMenuItem == item,
                    action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewStore.send(.selectMenuItem(item))
                            isShowing = false
                        }
                    }
                )
            })
        }
    }

    /// iOS Profile Image Picker
    struct IOSProfileImagePicker: UIViewControllerRepresentable {
        let onImageSelected: (Data) -> Void

        func makeUIViewController(context: Context) -> UIImagePickerController {
            let picker = UIImagePickerController()
            picker.delegate = context.coordinator
            picker.sourceType = .photoLibrary
            picker.allowsEditing = true
            return picker
        }

        func updateUIViewController(_: UIImagePickerController, context _: Context) {}

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
            let parent: IOSProfileImagePicker

            init(_ parent: IOSProfileImagePicker) {
                self.parent = parent
            }

            func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
                if let editedImage = info[.editedImage] as? UIImage,
                   let imageData = editedImage.jpegData(compressionQuality: 0.8) {
                    parent.onImageSelected(imageData)
                } else if let originalImage = info[.originalImage] as? UIImage,
                          let imageData = originalImage.jpegData(compressionQuality: 0.8) {
                    parent.onImageSelected(imageData)
                }

                picker.dismiss(animated: true)
            }

            func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
                picker.dismiss(animated: true)
            }
        }
    }
#endif
