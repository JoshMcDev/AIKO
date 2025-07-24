import AppCore
import ComposableArchitecture
import SwiftUI

/// Shared AppView implementation containing all platform-agnostic logic
public struct SharedAppView<Services: AppViewPlatformServices>: View {
    let store: StoreOf<AppFeature>
    let services: Services

    public init(store: StoreOf<AppFeature>, services: Services) {
        self.store = store
        self.services = services
    }

    public var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            if !viewStore.isOnboardingCompleted {
                onboardingView
            } else if !viewStore.isAuthenticated {
                authenticationView(viewStore: viewStore)
            } else {
                mainContentView(viewStore: viewStore)
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .alert(
            store: store.scope(state: \.$errorAlert, action: \.errorAlert)
        )
    }

    // MARK: - Onboarding View

    private var onboardingView: some View {
        OnboardingView(
            store: store.scope(
                state: \.onboarding,
                action: \.onboarding
            )
        )
        .transition(.opacity)
    }

    // MARK: - Authentication View

    private func authenticationView(viewStore: ViewStore<AppFeature.State, AppFeature.Action>) -> some View {
        FaceIDAuthenticationView(
            isAuthenticating: viewStore.isAuthenticating,
            error: viewStore.authenticationError,
            onRetry: { viewStore.send(.authenticateWithFaceID) }
        )
        .transition(.opacity)
    }

    // MARK: - Main Content View

    @ViewBuilder
    private func mainContentView(viewStore: ViewStore<AppFeature.State, AppFeature.Action>) -> some View {
        ZStack(alignment: .trailing) {
            // Background that extends to safe area
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                SharedHeaderView(
                    showMenu: .init(
                        get: { viewStore.showingMenu },
                        set: { viewStore.send(.toggleMenu($0)) }
                    ),
                    loadedAcquisition: viewStore.loadedAcquisition,
                    loadedAcquisitionDisplayName: viewStore.loadedAcquisitionDisplayName,
                    hasSelectedDocuments: viewStore.hasSelectedDocuments,
                    services: services,
                    onNewAcquisition: {
                        viewStore.send(.startNewAcquisition)
                    },
                    onSAMGovLookup: {
                        viewStore.send(.showSAMGovLookup(true))
                    },
                    onQuickScan: {
                        viewStore.send(.startQuickScan)
                    },
                    onExecuteAll: {
                        viewStore.send(.executeAllDocuments)
                    }
                )

                // Main Content
                EnhancedDocumentGenerationView(
                    store: store.scope(
                        state: \.documentGeneration,
                        action: \.documentGeneration
                    ),
                    isChatMode: viewStore.isChatMode,
                    loadedAcquisition: viewStore.loadedAcquisition,
                    loadedAcquisitionDisplayName: viewStore.loadedAcquisitionDisplayName
                )
            }
            .modifier(NavigationBarHiddenModifier())
            .preferredColorScheme(.dark)
            .ignoresSafeArea(.keyboard) // Allow keyboard to overlay content
            .floatingActionButton(
                store: store.scope(
                    state: \.globalScan,
                    action: \.globalScan
                )
            )

            // Menu overlay
            if viewStore.showingMenu {
                MenuView(
                    store: store,
                    isShowing: .init(
                        get: { viewStore.showingMenu },
                        set: { viewStore.send(.toggleMenu($0)) }
                    ),
                    selectedMenuItem: .init(
                        get: { viewStore.selectedMenuItem },
                        set: { viewStore.send(.selectMenuItem($0)) }
                    )
                )
                .transition(.move(edge: .trailing))
                .zIndex(1)
                .allowsHitTesting(true) // Ensure menu is interactive
            }
        }
        .onAppear {
            viewStore.send(.onAppear)
        }
        .modifier(AppSheetPresentation(store: store, services: services))
    }
}

/// Shared header view that works across platforms
struct SharedHeaderView<Services: AppViewPlatformServices>: View {
    @Binding var showMenu: Bool
    let loadedAcquisition: AppCore.Acquisition?
    let loadedAcquisitionDisplayName: String?
    let hasSelectedDocuments: Bool
    let services: Services
    let onNewAcquisition: () -> Void
    let onSAMGovLookup: () -> Void
    let onQuickScan: () -> Void
    let onExecuteAll: () -> Void

    private func loadSAMIcon() -> Image? {
        // For Swift Package, load from module bundle
        guard Bundle.module.url(forResource: "SAMIcon", withExtension: "png") != nil else {
            return nil
        }

        return nil // TODO: Services doesn't have loadImage(from: URL)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.large) {
            // App Icon on the left
            SharedAppIconView(services: services)
                .frame(width: 50, height: 50)

            Spacer()

            // Icon buttons evenly spaced
            HStack(spacing: Theme.Spacing.large) {
                // SAM.gov lookup button (moved to left)
                Button(action: onSAMGovLookup) {
                    if let samIcon = loadSAMIcon() {
                        samIcon
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                            .frame(width: 40, height: 40)
                            .background(Color.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                    .stroke(Theme.Colors.aikoPrimary, lineWidth: 2)
                            )
                    } else {
                        Image(systemName: "text.badge.checkmark")
                            .font(.title3)
                            .foregroundColor(Theme.Colors.aikoPrimary)
                            .frame(width: 40, height: 40)
                            .background(Color.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                    .stroke(Theme.Colors.aikoPrimary, lineWidth: 2)
                            )
                    }
                }

                // Quick Document Scanner button
                Button(action: onQuickScan) {
                    Image(systemName: "camera.fill")
                        .font(.title3)
                        .foregroundColor(Theme.Colors.aikoPrimary)
                        .frame(width: 40, height: 40)
                        .background(Color.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                .stroke(Theme.Colors.aikoPrimary, lineWidth: 2)
                        )
                }

                // Execute all button
                Button(action: onExecuteAll) {
                    Image(systemName: hasSelectedDocuments ? "play.fill" : "play")
                        .font(.title3)
                        .foregroundColor(Theme.Colors.aikoPrimary)
                        .frame(width: 40, height: 40)
                        .background(Color.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                .stroke(Theme.Colors.aikoPrimary, lineWidth: 2)
                        )
                }
                .disabled(!hasSelectedDocuments)

                // New acquisition button
                Button(action: onNewAcquisition) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(Theme.Colors.aikoPrimary)
                        .frame(width: 40, height: 40)
                        .background(Color.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                .stroke(Theme.Colors.aikoPrimary, lineWidth: 2)
                        )
                }

                // Menu button
                Button(action: { showMenu.toggle() }) {
                    Image(systemName: "line.horizontal.3")
                        .font(.title3)
                        .foregroundColor(Theme.Colors.aikoPrimary)
                        .frame(width: 40, height: 40)
                        .background(Color.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                .stroke(Theme.Colors.aikoPrimary, lineWidth: 2)
                        )
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.large)
        .padding(.vertical, Theme.Spacing.medium)
        .background(Color.black)
    }
}

/// Shared app icon view component
struct SharedAppIconView<Services: AppViewPlatformServices>: View {
    let services: Services

    var body: some View {
        if let image = services.getAppIcon() {
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        } else {
            // Show the actual design if PNG not found
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.5, blue: 0.2),
                                Color(red: 0.2, green: 0.4, blue: 0.8),
                            ]),
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                    )

                // Scroll and quill design
                ZStack {
                    Image(systemName: "scroll")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.cyan)

                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.cyan)
                        .rotationEffect(.degrees(-45))
                        .offset(x: 8, y: -8)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        }
    }
}

/// View modifier to handle all sheet presentations
struct AppSheetPresentation<Services: AppViewPlatformServices>: ViewModifier {
    let store: StoreOf<AppFeature>
    let services: Services

    @ViewBuilder
    func body(content: Content) -> some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            content
                .sheet(isPresented: .init(
                    get: { viewStore.showingProfile },
                    set: { viewStore.send(.showProfile($0)) }
                )) {
                    SwiftUI.NavigationView {
                        ProfileView(
                            store: store.scope(
                                state: \.profile,
                                action: \.profile
                            )
                        )
                    }
                    .aikoSheet()
                }
                .sheet(isPresented: .init(
                    get: { viewStore.showingAcquisitions },
                    set: { viewStore.send(.showAcquisitions($0)) }
                )) {
                    SwiftUI.NavigationView {
                        AcquisitionsListView(
                            store: store.scope(
                                state: \.acquisitionsList,
                                action: \.acquisitionsList
                            )
                        )
                    }
                    .aikoSheet()
                }
                .sheet(isPresented: .init(
                    get: { viewStore.showingUserGuide },
                    set: { viewStore.send(.showUserGuide($0)) }
                )) {
                    SwiftUI.NavigationView {
                        UserGuideView()
                    }
                    .aikoSheet()
                }
                .sheet(isPresented: .init(
                    get: { viewStore.showingSearchTemplates },
                    set: { viewStore.send(.showSearchTemplates($0)) }
                )) {
                    SearchDocumentTemplatesView()
                        .aikoSheet()
                }
                .sheet(isPresented: .init(
                    get: { viewStore.showingSettings },
                    set: { viewStore.send(.showSettings($0)) }
                )) {
                    SettingsView(
                        store: store.scope(
                            state: \.settings,
                            action: \.settings
                        )
                    )
                    .aikoSheet()
                }
                .sheet(isPresented: .init(
                    get: { viewStore.showingDownloadOptions },
                    set: { _ in viewStore.send(.hideDownloadOptions) }
                )) {
                    if let acquisition = viewStore.downloadTargetAcquisition {
                        DownloadOptionsSheet(
                            acquisition: AppCore.Acquisition(
                                id: acquisition.id,
                                title: acquisition.title,
                                requirements: acquisition.requirements,
                                projectNumber: acquisition.projectNumber,
                                status: .draft, // TODO: Map actual status
                                createdDate: acquisition.createdDate,
                                lastModifiedDate: acquisition.lastModifiedDate
                            ),
                            onDismiss: { viewStore.send(.hideDownloadOptions) }
                        )
                    }
                }
                .sheet(isPresented: .init(
                    get: { viewStore.showingAcquisitionChat },
                    set: { viewStore.send(.showAcquisitionChat($0)) }
                )) {
                    AcquisitionChatView(
                        store: store.scope(
                            state: \.acquisitionChat,
                            action: \.acquisitionChat
                        )
                    )
                    .aikoSheet()
                    .interactiveDismissDisabled()
                }
                .sheet(isPresented: .init(
                    get: { viewStore.showingSAMGovLookup },
                    set: { viewStore.send(.showSAMGovLookup($0)) }
                )) {
                    SAMGovLookupView()
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        .aikoSheet()
                }
                .sheet(isPresented: .init(
                    get: { viewStore.showingDocumentSelection },
                    set: { _ in viewStore.send(.hideDocumentSelection) }
                )) {
                    DocumentSelectionSheet(
                        acquisitionId: viewStore.shareTargetAcquisitionId,
                        selectedDocuments: viewStore.selectedDocumentsForShare,
                        onToggleDocument: { docId in
                            viewStore.send(.toggleDocumentForShare(docId))
                        },
                        onConfirm: {
                            viewStore.send(.confirmShareSelection)
                        },
                        onCancel: {
                            viewStore.send(.hideDocumentSelection)
                        }
                    )
                    .aikoSheet()
                }
        }
    }
}
