import AppCore
import ComposableArchitecture
import Foundation

@Reducer
public struct DocumentGenerationFeature: @unchecked Sendable {
    @ObservableState
    public struct State: Equatable {
        // Child feature states
        public var analysis = DocumentAnalysisFeature.State()
        public var delivery = DocumentDeliveryFeature.State()
        public var status = DocumentStatusFeature.State()
        public var execution = DocumentExecutionFeature.State()

        // Core generation state
        public var isGenerating: Bool = false
        public var generationError: String?

        // Computed properties for backward compatibility
        public var requirements: String {
            get { analysis.requirements }
            set { analysis.requirements = newValue }
        }

        public var selectedDocumentTypes: Set<DocumentType> {
            get { status.selectedDocumentTypes }
            set { status.selectedDocumentTypes = newValue }
        }

        public var generatedDocuments: [GeneratedDocument] {
            get { delivery.generatedDocuments }
            set { delivery.generatedDocuments = newValue }
        }

        public var error: String? {
            analysis.error ?? delivery.deliveryError ?? generationError
        }

        public init() {}
    }

    public enum Action {
        // Child feature actions
        case analysis(DocumentAnalysisFeature.Action)
        case delivery(DocumentDeliveryFeature.Action)
        case status(DocumentStatusFeature.Action)
        case execution(DocumentExecutionFeature.Action)

        // Core generation actions
        case generateDocuments
        case documentsGenerated([GeneratedDocument])
        case generationFailed(String)
        case clearError

        // Convenience actions for backward compatibility
        case requirementsChanged(String)
        case documentTypeToggled(DocumentType)
        case analyzeRequirements
        case generateRecommendedDocuments
        case selectAllRecommendedDocuments

        // Execute category action
        case executeCategory(DocumentCategory)
        case needsMoreInfoForDocuments(Set<DocumentType>)
    }

    @Dependency(\.aiDocumentGenerator) var aiDocumentGenerator
    @Dependency(\.parallelDocumentGenerator) var parallelDocumentGenerator
    @Dependency(\.userProfileService) var userProfileService

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.analysis, action: \.analysis) {
            DocumentAnalysisFeature()
        }

        Scope(state: \.delivery, action: \.delivery) {
            DocumentDeliveryFeature()
        }

        Scope(state: \.status, action: \.status) {
            DocumentStatusFeature()
        }

        Scope(state: \.execution, action: \.execution) {
            DocumentExecutionFeature()
        }

        Reduce { state, action in
            switch action {
            // Handle child feature actions
            case let .analysis(.requirementsAnalyzed(_, recommendedDocs)):
                // Update status when analysis completes
                return .send(.status(.setRecommendedDocuments(recommendedDocs)))

            case let .analysis(.documentUploaded(response, recommendedDocs)):
                // Update status from document upload
                return .send(.status(.updateStatusFromCompletenessScore(response, recommendedDocs)))

            case .analysis:
                return .none

            case .delivery:
                return .none

            case .status:
                return .none

            // Core generation actions
            case .generateDocuments:
                guard !state.requirements.isEmpty || !state.analysis.uploadedDocuments.isEmpty else { return .none }
                guard !state.selectedDocumentTypes.isEmpty || !state.status.selectedDFDocumentTypes.isEmpty else { return .none }

                state.isGenerating = true
                state.generationError = nil

                // Build enhanced requirements including uploaded documents
                var enhancedRequirements = state.requirements
                if !state.analysis.uploadedDocuments.isEmpty {
                    enhancedRequirements += "\n\nAdditional context from uploaded documents:\n"
                    for doc in state.analysis.uploadedDocuments {
                        if let summary = doc.contentSummary {
                            enhancedRequirements += "\n- \(doc.fileName): \(summary)"
                        }
                    }
                }

                return .run { [requirements = enhancedRequirements, documentTypes = state.selectedDocumentTypes, dfDocumentTypes = state.status.selectedDFDocumentTypes, userProfileService = self.userProfileService] send in
                    do {
                        var documents: [GeneratedDocument] = []

                        // Load profile once before generation
                        let profile = try? await userProfileService.loadProfile()

                        // Generate standard and D&F documents in parallel
                        async let standardDocsTask = documentTypes.isEmpty ? [] :
                            try await parallelDocumentGenerator.generateDocumentsParallel(
                                requirements: requirements,
                                documentTypes: documentTypes,
                                profile: profile
                            )

                        async let dfDocsTask = dfDocumentTypes.isEmpty ? [] :
                            try await parallelDocumentGenerator.generateDFDocumentsParallel(
                                requirements: requirements,
                                dfDocumentTypes: dfDocumentTypes,
                                profile: profile
                            )

                        // Await both results
                        let (standardDocs, dfDocs) = try await (standardDocsTask, dfDocsTask)

                        documents.append(contentsOf: standardDocs)
                        documents.append(contentsOf: dfDocs)

                        await send(.documentsGenerated(documents))
                    } catch {
                        await send(.generationFailed(error.localizedDescription))
                    }
                }

            case let .documentsGenerated(documents):
                state.isGenerating = false
                state.delivery.generatedDocuments = documents
                state.delivery.showingDeliveryOptions = true

                // Create document chain if we have an acquisition
                if state.analysis.currentAcquisitionId != nil {
                    // Get all selected document types for the chain
                    let chainDocumentTypes = Array(state.selectedDocumentTypes)
                    if !chainDocumentTypes.isEmpty {
                        return .concatenate(
                            .send(.analysis(.createDocumentChain(chainDocumentTypes))),
                            Effect.run { send in
                                // Process generated documents through the chain
                                for document in documents {
                                    await send(.analysis(.documentGeneratedInChain(document)))
                                }
                            }
                        )
                    }
                }

                return .none

            case let .generationFailed(error):
                state.isGenerating = false
                state.generationError = error
                return .none

            case .clearError:
                state.generationError = nil
                return .concatenate(
                    .send(.analysis(.clearError)),
                    .send(.delivery(.clearError))
                )

            // Convenience actions for backward compatibility
            case let .requirementsChanged(requirements):
                return .send(.analysis(.requirementsChanged(requirements)))

            case let .documentTypeToggled(documentType):
                // Update document chain when selections change
                var effects: [Effect<Action>] = [.send(.status(.documentTypeToggled(documentType)))]

                // If we have an acquisition and chain, update it
                if state.analysis.currentAcquisitionId != nil {
                    let updatedTypes = state.status.selectedDocumentTypes.symmetricDifference([documentType])
                    if !updatedTypes.isEmpty {
                        effects.append(.send(.analysis(.createDocumentChain(Array(updatedTypes)))))
                    }
                }

                return .concatenate(effects)

            case .analyzeRequirements:
                return .send(.analysis(.analyzeRequirements))

            case .generateRecommendedDocuments:
                state.analysis.showingDocumentRecommendation = false
                return .concatenate(
                    .send(.status(.selectRecommendedDocuments)),
                    .send(.generateDocuments)
                )

            case .selectAllRecommendedDocuments:
                return .send(.status(.selectRecommendedDocuments))

            case let .executeCategory(category):
                // Gather selected documents for this category
                let selectedDocs = state.status.selectedDocumentTypes
                let selectedDFDocs = state.status.selectedDFDocumentTypes

                // Filter documents by category
                let categoryDocs: Set<DocumentType>
                let categoryDFDocs: Set<DFDocumentType>

                switch category {
                case .determinationFindings:
                    // Only pass D&F documents for D&F category
                    categoryDocs = []
                    categoryDFDocs = selectedDFDocs
                default:
                    // Only pass regular documents for their respective categories
                    categoryDocs = selectedDocs.filter { docType in
                        DocumentCategory.category(for: docType) == category
                    }
                    categoryDFDocs = []
                }

                // Check if any category documents have red status (not ready)
                let notReadyDocs = categoryDocs.filter { documentType in
                    if let status = state.status.documentReadinessStatus[documentType] {
                        return status == .notReady
                    }
                    return true // If no status, assume not ready
                }

                // If there are documents that aren't ready, trigger chat to gather info
                if !notReadyDocs.isEmpty {
                    // Store info about documents needing more data
                    state.execution.executingCategory = category
                    state.execution.executingDocumentTypes = categoryDocs
                    state.execution.executingDFDocumentTypes = categoryDFDocs

                    return .send(.needsMoreInfoForDocuments(Set(notReadyDocs)))
                }

                // All documents are ready, proceed with execution
                return .send(.execution(.executeCategory(category, categoryDocs, categoryDFDocs)))

            case .execution:
                return .none

            case .needsMoreInfoForDocuments:
                // This action should be handled by the parent (AppFeature)
                // to show the acquisition chat
                return .none
            }
        }
    }
}
