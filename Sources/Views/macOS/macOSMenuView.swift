#if os(macOS)
    import AppCore
    import AppKit
    import ComposableArchitecture
    import SwiftUI

    /// macOS-specific implementation of MenuView
    public struct MacOSMenuView: View {
        let store: StoreOf<AppFeature>
        @Binding var isShowing: Bool
        @Binding var selectedMenuItem: AppFeature.MenuItem?

        @State private var profileImage: NSImage?
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
        }

        // MARK: - Menu Content

        @ViewBuilder
        private var menuContent: some View {
            VStack(alignment: .leading, spacing: 0) {
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
            Button(action: { showingImageSourceDialog = true }, label: {
                ZStack {
                    profileImageView
                    cameraIconOverlay
                }
            })
            .buttonStyle(.plain)
            .popover(isPresented: $showingImageSourceDialog) {
                VStack(spacing: 12) {
                    Text("Profile Photo")
                        .font(.headline)
                        .padding(.top, 8)

                    Button("Select Photo") {
                        selectProfileImage()
                        showingImageSourceDialog = false
                    }
                    .buttonStyle(.borderedProminent)

                    if profileImage != nil {
                        Button("Remove Photo") {
                            profileImage = nil
                            showingImageSourceDialog = false
                        }
                        .foregroundColor(.red)
                    }

                    Button("Cancel") {
                        showingImageSourceDialog = false
                    }
                    .keyboardShortcut(.escape)
                }
                .padding()
                .frame(width: 200)
            }
        }

        @ViewBuilder
        private var profileImageView: some View {
            if let image = profileImage {
                Image(nsImage: image)
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

        private func selectProfileImage() {
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = true
            openPanel.canChooseDirectories = false
            openPanel.allowsMultipleSelection = false
            openPanel.allowedContentTypes = [.image]

            openPanel.begin { response in
                if response == .OK, let url = openPanel.url {
                    if let image = NSImage(contentsOf: url) {
                        profileImage = image
                    }
                }
            }
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
            }, label: {
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
            })
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
            }, label: {
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
            })
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
#endif
