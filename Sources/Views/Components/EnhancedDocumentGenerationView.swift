import AppCore
import ComposableArchitecture
import SwiftUI

// MARK: - Enhanced Document Generation View

struct EnhancedDocumentGenerationView: View {
    let store: StoreOf<DocumentGenerationFeature>
    let isChatMode: Bool
    let loadedAcquisition: AppCore.Acquisition?
    let loadedAcquisitionDisplayName: String?

    @State private var scrollOffset: CGFloat = 0
    @Environment(\.sizeCategory) private var sizeCategory
    @Dependency(\.hapticManager) var hapticManager

    init(
        store: StoreOf<DocumentGenerationFeature>,
        isChatMode: Bool,
        loadedAcquisition: AppCore.Acquisition?,
        loadedAcquisitionDisplayName: String?
    ) {
        self.store = store
        self.isChatMode = isChatMode
        self.loadedAcquisition = loadedAcquisition
        self.loadedAcquisitionDisplayName = loadedAcquisitionDisplayName
    }

    struct ViewState: Equatable {
        let analysisConversationHistory: [String]
        let analysisIsAnalyzingRequirements: Bool
        let analysisUploadedDocuments: [UploadedDocument]
        let analysisIsRecording: Bool
        let requirements: String
        let isGenerating: Bool
        let selectedDocumentTypes: Set<DocumentType>
        let selectedDFDocumentTypes: Set<DFDocumentType>
        let documentReadinessStatus: [DocumentType: DocumentStatusFeature.DocumentStatus]

        init(state: DocumentGenerationFeature.State) {
            analysisConversationHistory = state.analysis.conversationHistory
            analysisIsAnalyzingRequirements = state.analysis.isAnalyzingRequirements
            analysisUploadedDocuments = state.analysis.uploadedDocuments
            analysisIsRecording = state.analysis.isRecording
            requirements = state.requirements
            isGenerating = state.isGenerating
            selectedDocumentTypes = state.selectedDocumentTypes
            selectedDFDocumentTypes = state.status.selectedDFDocumentTypes
            documentReadinessStatus = state.status.documentReadinessStatus
        }
    }

    var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            VStack(spacing: 0) {
                // Main Content Area with parallax effect
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.extraLarge) {
                        // Content sections with enhanced animations
                        Group {
                            if isChatMode, loadedAcquisition != nil, !viewStore.analysisConversationHistory.isEmpty {
                                EnhancedChatHistoryView(
                                    messages: viewStore.analysisConversationHistory,
                                    isLoading: viewStore.analysisIsAnalyzingRequirements
                                )
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                                    removal: .scale(scale: 1.1).combined(with: .opacity)
                                ))
                            }

                            // Enhanced document selection
                            EnhancedDocumentTypesSection(
                                documentTypes: DocumentType.allCases,
                                selectedTypes: viewStore.selectedDocumentTypes,
                                selectedDFTypes: viewStore.selectedDFDocumentTypes,
                                documentStatus: viewStore.documentReadinessStatus,
                                hasAcquisition: loadedAcquisition != nil,
                                onTypeToggled: { documentType in
                                    hapticManager.selection()
                                    viewStore.send(.documentTypeToggled(documentType))
                                },
                                onDFTypeToggled: { dfDocumentType in
                                    hapticManager.selection()
                                    viewStore.send(.status(.dfDocumentTypeToggled(dfDocumentType)))
                                },
                                onExecuteCategory: { category in
                                    hapticManager.notification(.success)
                                    viewStore.send(.executeCategory(category))
                                }
                            )
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(Theme.Spacing.large)
                    .background(GeometryReader { geometry in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("scroll")).minY
                        )
                    })
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
                .background(Theme.Colors.aikoBackground)

                // Enhanced Input Area
                InputArea(
                    requirements: viewStore.requirements,
                    isGenerating: viewStore.isGenerating,
                    uploadedDocuments: viewStore.analysisUploadedDocuments,
                    isChatMode: isChatMode,
                    isRecording: viewStore.analysisIsRecording,
                    onRequirementsChanged: { requirements in
                        viewStore.send(.requirementsChanged(requirements))
                    },
                    onAnalyzeRequirements: {
                        hapticManager.impact(.medium)
                        viewStore.send(.analyzeRequirements)
                    },
                    onEnhancePrompt: {
                        hapticManager.impact(.light)
                        viewStore.send(.analysis(.enhancePrompt))
                    },
                    onStartRecording: {
                        hapticManager.impact(.medium)
                        viewStore.send(.analysis(.startVoiceRecording))
                    },
                    onStopRecording: {
                        hapticManager.impact(.light)
                        viewStore.send(.analysis(.stopVoiceRecording))
                    },
                    onShowDocumentPicker: {
                        hapticManager.selection()
                        viewStore.send(.analysis(.showDocumentPicker(true)))
                    },
                    onShowImagePicker: {
                        hapticManager.selection()
                        viewStore.send(.analysis(.showImagePicker(true)))
                    },
                    onRemoveDocument: { documentId in
                        hapticManager.impact(.light)
                        viewStore.send(.analysis(.removeUploadedDocument(documentId)))
                    }
                )
            }
            // Add sheet presentations with transitions...
        }
    }
}
