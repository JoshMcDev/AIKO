import AppCore
import ComposableArchitecture
import SwiftUI

// MARK: - Enhanced App View with UI/UX Improvements

public struct EnhancedAppView: View {
    let store: StoreOf<AppFeature>

    @Dependency(\.hapticManager) var hapticManager
    @Dependency(\.navigationService) var navigationService
    @Dependency(\.screenService) var screenService
    @Dependency(\.imageLoader) var imageLoader
    @Dependency(\.documentScanner) var documentScanner
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        navigationContent
            .preferredColorScheme(.dark)
            .modifier(NavigationBarHiddenModifier())
    }

    @ViewBuilder
    private var navigationContent: some View {
        if navigationService.supportsNavigationStack() {
            NavigationStack {
                contentView
            }
            .tint(.white)
        } else {
            SwiftUI.NavigationView {
                contentView
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            ZStack {
                // Animated background gradient
                AnimatedGradientBackground()

                if !viewStore.isOnboardingCompleted {
                    onboardingView
                        .pageTransition(isActive: true, from: .trailing)
                } else if !viewStore.isAuthenticated {
                    authenticationView(viewStore: viewStore)
                        .pageTransition(isActive: true, from: .bottom)
                } else {
                    mainContentView(viewStore: viewStore)
                        .pageTransition(isActive: true, from: .trailing)
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .alert(
            store: store.scope(state: \.$errorAlert, action: \.errorAlert)
        )
        .onVoiceOverStatusChanged { isEnabled in
            if isEnabled {
                AccessibilityAnnouncement.announce("AIKO App is ready. Swipe to navigate.", priority: .high)
            }
        }
    }

    // MARK: - View Components

    private var onboardingView: some View {
        OnboardingView(
            store: store.scope(
                state: \.onboarding,
                action: \.onboarding
            )
        )
        .transition(.asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        ))
        .accessibilityElement(
            label: "Onboarding",
            hint: "Complete the setup process"
        )
    }

    private func authenticationView(viewStore: ViewStore<AppFeature.State, AppFeature.Action>) -> some View {
        FaceIDAuthenticationView(
            isAuthenticating: viewStore.isAuthenticating,
            error: viewStore.authenticationError,
            onRetry: {
                hapticManager.impact(.medium)
                viewStore.send(.authenticateWithFaceID)
            }
        )
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .scale(scale: 0.9).combined(with: .opacity)
        ))
        .accessibilityElement(
            label: "Authentication Required",
            hint: "Use Face ID or enter passcode to continue"
        )
    }

    @ViewBuilder
    private func mainContentView(viewStore: ViewStore<AppFeature.State, AppFeature.Action>) -> some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: 0) {
                // Enhanced Header
                EnhancedHeaderView(
                    showMenu: .init(
                        get: { viewStore.showingMenu },
                        set: { viewStore.send(.toggleMenu($0)) }
                    ),
                    loadedAcquisition: viewStore.loadedAcquisition,
                    loadedAcquisitionDisplayName: viewStore.loadedAcquisitionDisplayName,
                    hasSelectedDocuments: viewStore.hasSelectedDocuments,
                    onNewAcquisition: {
                        hapticManager.successAction()
                        viewStore.send(.startNewAcquisition)
                    },
                    onSAMGovLookup: {
                        hapticManager.impact(.light)
                        viewStore.send(.showSAMGovLookup(true))
                    },
                    onExecuteAll: {
                        hapticManager.notification(.success)
                        viewStore.send(.executeAllDocuments)
                    }
                )
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Navigation Header")

                // Enhanced Document Generation View
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
            .ignoresSafeArea(.keyboard)

            // Enhanced Menu overlay with glassmorphism
            if viewStore.showingMenu {
                Rectangle()
                    .fill(SwiftUI.Color(white: 0, opacity: 0.3))
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewStore.send(.toggleMenu(false), animation: AnimationSystem.Spring.smooth)
                    }

                EnhancedMenuView(
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
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
                .zIndex(1)
            }
        }
        .animation(
            reduceMotion ? .linear(duration: 0.1) : AnimationSystem.Spring.smooth,
            value: viewStore.showingMenu
        )
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
            .accessibilityAddTraits(.isModal)
        }
        // Add remaining sheets with accessibility support...
    }
}

// MARK: - Enhanced Document Types Section

struct EnhancedDocumentTypesSection: View {
    let documentTypes: [DocumentType]
    let selectedTypes: Set<DocumentType>
    let selectedDFTypes: Set<DFDocumentType>
    let documentStatus: [DocumentType: DocumentStatusFeature.DocumentStatus]
    let hasAcquisition: Bool
    let onTypeToggled: (DocumentType) -> Void
    let onDFTypeToggled: (DFDocumentType) -> Void
    let onExecuteCategory: (DocumentCategory) -> Void

    @State private var expandedCategories: Set<DocumentCategory> = []
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            // Header
            HStack {
                Label("Document Types", systemImage: "folder")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.aikoPrimary)
                    .accessibleHeader(label: "Document Types", level: .heading2)

                Spacer()

                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, Theme.Spacing.small)
                .padding(.vertical, Theme.Spacing.extraSmall)
                .background(
                    Capsule()
                        .fill(Theme.Colors.aikoSecondary)
                )
                .frame(maxWidth: 200)
                .transition(.scale.combined(with: .opacity))
            }

            // Category cards with enhanced styling
            VStack(spacing: Theme.Spacing.medium) {
                ForEach(DocumentCategory.allCases, id: \.self) { category in
                    EnhancedDocumentCategoryCard(
                        category: category,
                        isExpanded: expandedCategories.contains(category),
                        documentTypes: filteredDocumentTypes(for: category),
                        selectedTypes: selectedTypes,
                        selectedDFTypes: selectedDFTypes,
                        documentStatus: documentStatus,
                        hasAcquisition: hasAcquisition,
                        onToggleExpanded: {
                            withAnimation(AnimationSystem.Spring.snappy) {
                                if expandedCategories.contains(category) {
                                    expandedCategories.remove(category)
                                } else {
                                    expandedCategories.insert(category)
                                }
                            }
                        },
                        onTypeToggled: onTypeToggled,
                        onDFTypeToggled: onDFTypeToggled,
                        onExecute: {
                            onExecuteCategory(category)
                        }
                    )
                }
            }
        }
    }

    func filteredDocumentTypes(for category: DocumentCategory) -> [DocumentType] {
        let types = category.documentTypes
        if searchText.isEmpty {
            return types
        }
        return types.filter { type in
            type.shortName.localizedCaseInsensitiveContains(searchText) ||
                type.description.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Enhanced Document Category Card

struct EnhancedDocumentCategoryCard: View {
    let category: DocumentCategory
    let isExpanded: Bool
    let documentTypes: [DocumentType]
    let selectedTypes: Set<DocumentType>
    let selectedDFTypes: Set<DFDocumentType>
    let documentStatus: [DocumentType: DocumentStatusFeature.DocumentStatus]
    let hasAcquisition: Bool
    let onToggleExpanded: () -> Void
    let onTypeToggled: (DocumentType) -> Void
    let onDFTypeToggled: (DFDocumentType) -> Void
    let onExecute: () -> Void

    @State private var isHovered = false
    @Dependency(\.hapticManager) var hapticManager

    var selectedCount: Int {
        if category == .determinationFindings {
            selectedDFTypes.count
        } else {
            documentTypes.count(where: { selectedTypes.contains($0) })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Enhanced folder header
            Button(action: {
                hapticManager.selection()
                onToggleExpanded()
            }) {
                HStack(spacing: Theme.Spacing.large) {
                    // Animated category icon
                    ZStack {
                        Circle()
                            .fill(
                                category.color.opacity(0.2)
                            )
                            .frame(width: 48, height: 48)

                        Image(systemName: category.icon)
                            .font(.title2)
                            .foregroundColor(Theme.Colors.aikoPrimary)
                            .rotationEffect(.degrees(isExpanded ? 15 : 0))
                    }
                    .scaleEffect(isHovered ? 1.1 : 1.0)

                    // Category info with dynamic type
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            ResponsiveText(content: category.rawValue, style: .headline)
                                .foregroundColor(.white)

                            Spacer()

                            // Enhanced status badges
                            if selectedCount > 0 {
                                EnhancedStatusBadge(
                                    text: "\(selectedCount) selected",
                                    color: .blue,
                                    icon: "checkmark.circle.fill"
                                )
                                .transition(.scale.combined(with: .opacity))
                            }

                            // Execute button with animation
                            if selectedCount > 0 {
                                AnimatedButton(action: onExecute) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                        .scaleEffect(1.0)
                                }
                                .transition(.scale.combined(with: .opacity))
                            }

                            // Animated chevron
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        }

                        ResponsiveText(content: category.description, style: .caption)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                .padding(Theme.Spacing.large)
                .background(
                    EnhancedCard(
                        content: {
                            Color.clear
                        },
                        style: selectedCount > 0 ? .gradient : .elevated,
                        isInteractive: true
                    )
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(AnimationSystem.microScale) {
                    isHovered = hovering
                }
            }
            .accessibilityElement(
                label: "\(category.rawValue). \(selectedCount) documents selected",
                hint: isExpanded ? "Tap to collapse" : "Tap to expand",
                traits: .isButton
            )

            // Expanded document list with staggered animation
            if isExpanded {
                if category == .determinationFindings {
                    VStack(spacing: Theme.Spacing.small) {
                        ForEach(Array(DFDocumentType.allCases.enumerated()), id: \.element) { index, dfType in
                            EnhancedDFDocumentCard(
                                dfDocumentType: dfType,
                                isSelected: selectedDFTypes.contains(dfType),
                                hasAcquisition: hasAcquisition,
                                onToggle: {
                                    onDFTypeToggled(dfType)
                                }
                            )
                            .transition(
                                .asymmetric(
                                    insertion: .scale(scale: 0.8)
                                        .combined(with: .opacity)
                                        .animation(AnimationSystem.Spring.bouncy.delay(Double(index) * 0.05)),
                                    removal: .scale(scale: 0.8)
                                        .combined(with: .opacity)
                                )
                            )
                        }
                    }
                    .padding(.top, Theme.Spacing.small)
                } else {
                    VStack(spacing: Theme.Spacing.small) {
                        ForEach(Array(documentTypes.enumerated()), id: \.element) { index, docType in
                            EnhancedDocumentTypeCard(
                                documentType: docType,
                                isSelected: selectedTypes.contains(docType),
                                isAvailable: true,
                                status: documentStatus[docType] ?? .notReady,
                                onToggle: { onTypeToggled(docType) }
                            )
                            .transition(
                                .asymmetric(
                                    insertion: .scale(scale: 0.8)
                                        .combined(with: .opacity)
                                        .animation(AnimationSystem.Spring.bouncy.delay(Double(index) * 0.05)),
                                    removal: .scale(scale: 0.8)
                                        .combined(with: .opacity)
                                )
                            )
                        }
                    }
                    .padding(.top, Theme.Spacing.small)
                }
            }
        }
    }
}

// MARK: - Enhanced Status Badge Component

struct EnhancedStatusBadge: View {
    let text: String
    let color: Color
    let icon: String?

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption2)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color)
                .shadow(color: color.opacity(0.3), radius: 4, y: 2)
        )
    }
}

// MARK: - Enhanced Document Cards

struct EnhancedDocumentTypeCard: View {
    let documentType: DocumentType
    let isSelected: Bool
    let isAvailable: Bool
    let status: DocumentStatusFeature.DocumentStatus
    let onToggle: () -> Void

    @State private var isPressed = false

    var body: some View {
        AnimatedButton(action: onToggle) {
            HStack(spacing: Theme.Spacing.medium) {
                // Animated status indicator
                StatusIndicator(status: status)
                    .accessibilityLabel("Status: \(status.accessibilityLabel)")

                // Document icon with subtle animation
                Image(systemName: documentType.icon)
                    .font(.body)
                    .foregroundColor(isAvailable ? .blue : .secondary)
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(isSelected ? 360 : 0))
                    .animation(AnimationSystem.Spring.bouncy, value: isSelected)

                // Document info
                VStack(alignment: .leading, spacing: 2) {
                    ResponsiveText(content: documentType.shortName, style: .subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    ResponsiveText(content: documentType.farReference, style: .caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Animated checkmark
                if isSelected {
                    AnimatedCheckmark(size: 20, color: .green)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.body)
                        .frame(width: 20, height: 20)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Theme.Spacing.medium)
            .padding(.vertical, Theme.Spacing.small)
            .background(
                EnhancedCard(
                    content: {
                        Color.clear
                    },
                    style: isSelected ? .gradient : .elevated,
                    isInteractive: true
                )
            )
            .opacity(isAvailable ? 1.0 : 0.6)
        }
        .accessibilityElement(
            label: "\(documentType.shortName). \(documentType.farReference)",
            hint: isSelected ? "Selected. Tap to deselect" : "Tap to select",
            traits: [.isButton, isSelected ? .isSelected : []].reduce([]) { $0.union($1) }
        )
    }
}

struct EnhancedDFDocumentCard: View {
    let dfDocumentType: DFDocumentType
    let isSelected: Bool
    let hasAcquisition: Bool
    let onToggle: () -> Void

    var body: some View {
        AnimatedButton(action: onToggle) {
            HStack(spacing: Theme.Spacing.medium) {
                // Status with pulse animation when no acquisition
                StatusIndicator(
                    status: hasAcquisition ? .ready : .notReady,
                    pulse: !hasAcquisition
                )

                // Icon
                Image(systemName: dfDocumentType.icon)
                    .font(.body)
                    .foregroundColor(.blue)
                    .frame(width: 20, height: 20)

                // Document info
                VStack(alignment: .leading, spacing: 2) {
                    ResponsiveText(content: dfDocumentType.shortName, style: .subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    ResponsiveText(content: dfDocumentType.farReference, style: .caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    AnimatedCheckmark(size: 20, color: .green)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.body)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, Theme.Spacing.medium)
            .padding(.vertical, Theme.Spacing.small)
            .background(
                EnhancedCard(
                    content: {
                        Color.clear
                    },
                    style: isSelected ? .gradient : .elevated,
                    isInteractive: true
                )
            )
        }
        .accessibilityElement(
            label: "\(dfDocumentType.shortName). \(dfDocumentType.farReference)",
            hint: hasAcquisition ?
                (isSelected ? "Selected. Tap to deselect" : "Tap to select") :
                "Acquisition required to select this document",
            traits: [.isButton, isSelected ? .isSelected : []].reduce([]) { $0.union($1) }
        )
    }
}

// MARK: - Status Indicator

struct StatusIndicator: View {
    let status: DocumentStatusFeature.DocumentStatus
    var pulse: Bool = false

    var statusColor: Color {
        switch status {
        case .notReady: .red
        case .needsMoreInfo: .yellow
        case .ready: .green
        }
    }

    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .shadow(color: statusColor.opacity(0.5), radius: 4)
            .pulse(duration: 1.5, scale: 1.5)
            .opacity(pulse ? 1.0 : 0.8)
    }
}

// MARK: - Enhanced Input Area

struct AppEnhancedInputArea: View {
    let requirements: String
    let isGenerating: Bool
    let uploadedDocuments: [UploadedDocument]
    let isChatMode: Bool
    let isRecording: Bool
    let onRequirementsChanged: @Sendable (String) -> Void
    let onAnalyzeRequirements: () -> Void
    let onEnhancePrompt: () -> Void
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onShowDocumentPicker: () -> Void
    let onShowImagePicker: () -> Void
    let onRemoveDocument: (UploadedDocument.ID) -> Void

    @State private var showingUploadOptions = false
    @State private var inputFieldHeight: CGFloat = 44
    @FocusState private var isInputFocused: Bool
    @Dependency(\.documentScanner) var documentScanner

    private var hasContent: Bool {
        !requirements.isEmpty || !uploadedDocuments.isEmpty
    }

    private var canAnalyze: Bool {
        hasContent && !isGenerating
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.gray.opacity(0.3 as Double))

            VStack(spacing: Theme.Spacing.medium) {
                // Uploaded documents carousel
                if !uploadedDocuments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.small) {
                            ForEach(uploadedDocuments) { document in
                                EnhancedUploadedDocumentCard(
                                    document: document,
                                    onRemove: { onRemoveDocument(document.id) }
                                )
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.large)
                    }
                    .frame(height: 60)
                    .animation(AnimationSystem.Spring.smooth, value: uploadedDocuments)
                }

                // Enhanced input container
                HStack(spacing: 0) {
                    // Animated text input
                    ZStack(alignment: .leading) {
                        if requirements.isEmpty {
                            ResponsiveText(
                                content: isChatMode ?
                                    "How may I assist you with this acquisition?" :
                                    "Describe your project requirements...",
                                style: .body
                            )
                            .foregroundColor(.gray)
                            .padding(.leading, Theme.Spacing.large)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                        }

                        TextField("", text: .init(
                            get: { requirements },
                            set: onRequirementsChanged
                        ), axis: .vertical)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                            .padding(.leading, Theme.Spacing.large)
                            .padding(.vertical, Theme.Spacing.medium)
                            .padding(.trailing, Theme.Spacing.small)
                            .lineLimit(1 ... 4)
                            .focused($isInputFocused)
                            .background(
                                GeometryReader { geometry in
                                    Color.clear.preference(
                                        key: HeightPreferenceKey.self,
                                        value: geometry.size.height
                                    )
                                }
                            )
                    }

                    // Enhanced action buttons
                    HStack(spacing: Theme.Spacing.small) {
                        // Enhance prompt with sparkle animation
                        AnimatedButton(action: {
                            if !requirements.isEmpty {
                                onEnhancePrompt()
                            }
                        }) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .foregroundColor(!requirements.isEmpty ? .yellow : .secondary)
                                .frame(width: 32, height: 32)
                                .shimmer(duration: 1.5, bounce: true)
                                .opacity(!requirements.isEmpty ? 1.0 : 0.6)
                        }
                        .disabled(requirements.isEmpty || isGenerating)
                        .accessibleButton(
                            label: "Enhance prompt",
                            hint: requirements.isEmpty ? "Enter text first" : "Improve your prompt with AI"
                        )

                        // Upload options with animation
                        AnimatedButton(action: { showingUploadOptions.toggle() }) {
                            Image(systemName: "plus")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .frame(width: 32, height: 32)
                                .rotationEffect(.degrees(showingUploadOptions ? 45 : 0))
                        }
                        .confirmationDialog("Add Content", isPresented: $showingUploadOptions) {
                            Button(" Upload Documents") {
                                onShowDocumentPicker()
                            }
                            if documentScanner.isScanningAvailable() {
                                Button("📷 Scan Document") {
                                    onShowImagePicker()
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                        .accessibleButton(
                            label: "Add content",
                            hint: "Upload documents or scan"
                        )

                        // Voice input with pulse animation
                        AnimatedButton(action: {
                            if isRecording {
                                onStopRecording()
                            } else {
                                onStartRecording()
                            }
                        }) {
                            Image(systemName: isRecording ? "mic.fill" : "mic")
                                .font(.title3)
                                .foregroundColor(isRecording ? .red : .secondary)
                                .frame(width: 32, height: 32)
                                .pulse(duration: 1.0, scale: 1.2)
                                .opacity(isRecording ? 1.0 : 0.8)
                        }
                        .disabled(isGenerating && !isRecording)
                        .accessibleButton(
                            label: isRecording ? "Stop recording" : "Start voice input",
                            hint: "Dictate your requirements"
                        )

                        // Analyze button with loading animation
                        AnimatedButton(action: onAnalyzeRequirements) {
                            ZStack {
                                if isGenerating {
                                    LoadingDotsView(dotSize: 6, color: .white)
                                        .frame(width: 32, height: 32)
                                } else {
                                    Image(systemName: requirements.isEmpty ? "arrow.up.circle" : "arrow.up.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(requirements.isEmpty ? .secondary : .white)
                                        .frame(width: 32, height: 32)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(
                                    canAnalyze ?
                                        Theme.Colors.aikoPrimary :
                                        Color.clear
                                )
                                .shadow(
                                    color: Theme.Colors.aikoPrimary.opacity(0.3),
                                    radius: canAnalyze ? 8 : 0
                                )
                        )
                        .disabled(!canAnalyze)
                        .accessibleButton(
                            label: "Analyze",
                            hint: hasContent ?
                                "Submit for AI analysis" :
                                "Enter requirements or upload documents first"
                        )
                    }
                    .padding(.trailing, Theme.Spacing.medium)
                    .padding(.vertical, Theme.Spacing.small)
                }
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Theme.Colors.aikoSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    isInputFocused ?
                                        Theme.Colors.aikoPrimary :
                                        Color.gray.opacity(0.3),
                                    lineWidth: isInputFocused ? 2 : 1
                                )
                        )
                        .shadow(
                            color: isInputFocused ?
                                Theme.Colors.aikoPrimary.opacity(0.2) :
                                Color.clear,
                            radius: 8
                        )
                )
                .onPreferenceChange(HeightPreferenceKey.self) { height in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        inputFieldHeight = height
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.large)
            .padding(.vertical, Theme.Spacing.large)
            .background(
                GlassmorphicView {
                    Color.black
                }
            )
        }
        .animation(AnimationSystem.Spring.smooth, value: isInputFocused)
    }
}

// MARK: - Enhanced Uploaded Document Card

struct EnhancedUploadedDocumentCard: View {
    let document: UploadedDocument
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Theme.Spacing.small) {
            // Animated file icon
            Image(systemName: fileIcon(for: document.fileName))
                .font(.title3)
                .foregroundColor(.blue)
                .rotationEffect(.degrees(isHovered ? 10 : 0))

            VStack(alignment: .leading, spacing: 2) {
                ResponsiveText(content: document.fileName, style: .caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)

                ResponsiveText(
                    content: formattedFileSize(document.data.count),
                    style: .caption2
                )
                .foregroundColor(.secondary)
            }

            // Remove button with animation
            AnimatedButton(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.scale)
            }
        }
        .padding(.horizontal, Theme.Spacing.medium)
        .padding(.vertical, Theme.Spacing.small)
        .background(
            EnhancedCard(content: {
                Color.clear
            }, style: .elevated)
        )
        .onHover { hovering in
            withAnimation(AnimationSystem.microScale) {
                isHovered = hovering
            }
        }
        .accessibilityElement(
            label: "Uploaded file: \(document.fileName), size: \(formattedFileSize(document.data.count))",
            hint: "Swipe to remove"
        )
        .accessibilityCustomActions([
            AccessibilityActionModifier.AccessibilityAction(
                name: "Remove",
                action: onRemove
            ),
        ])
    }

    func fileIcon(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.fill"
        case "doc", "docx": return "doc.text.fill"
        case "jpg", "jpeg", "png": return "photo.fill"
        default: return "doc.fill"
        }
    }

    func formattedFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Helper Views and Extensions

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false

    var body: some View {
        Color.black.opacity(0.95)
            .ignoresSafeArea()
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 10.0)
                        .repeatForever(autoreverses: true)
                ) {
                    animateGradient.toggle()
                }
            }
    }
}

// Preference Keys
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct HeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 44
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension DocumentCategory {
    var color: Color {
        switch self {
        case .requirements: .blue
        case .marketIntelligence: .orange
        case .planning: .purple
        case .determinationFindings: .yellow
        case .solicitation: .green
        case .award: .red
        case .analytics: .indigo
        case .resourcesTools: .gray
        }
    }
}

extension DocumentStatusFeature.DocumentStatus {
    var accessibilityLabel: String {
        switch self {
        case .notReady: "Not ready"
        case .needsMoreInfo: "Needs more information"
        case .ready: "Ready to generate"
        }
    }
}
