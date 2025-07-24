import AppCore
import ComposableArchitecture
import SwiftUI

// MARK: - LLM Confirmation Dialog

public struct LLMConfirmationDialog: View {
    let store: StoreOf<DocumentGenerationFeature>

    public init(store: StoreOf<DocumentGenerationFeature>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(store, observe: { $0 }, content: { viewStore in
            SwiftUI.NavigationView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: Theme.Spacing.medium) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)

                        Text("AIKO Analysis")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("AI Contract Intelligence Officer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, Theme.Spacing.large)
                    .padding(.horizontal, Theme.Spacing.large)

                    if viewStore.analysis.isAnalyzingRequirements {
                        // Loading state
                        VStack(spacing: Theme.Spacing.large) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(1.5)

                            Text("Analyzing your requirements...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Main Content
                        ScrollView {
                            VStack(alignment: .leading, spacing: Theme.Spacing.extraLarge) {
                                // LLM Response
                                VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                                    Text("Analysis")
                                        .font(.headline)
                                        .fontWeight(.semibold)

                                    Text(viewStore.analysis.llmResponse)
                                        .font(.body)
                                        .padding(Theme.Spacing.large)
                                        .background(Theme.Colors.aikoSecondary)
                                        .cornerRadius(Theme.CornerRadius.medium)
                                }

                                // Document Status Summary with grouping
                                VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                                    Text("Document Status")
                                        .font(.headline)
                                        .fontWeight(.semibold)

                                    let groupedStatuses = Dictionary(grouping: viewStore.status.documentReadinessStatus.keys) { documentType in
                                        viewStore.status.documentReadinessStatus[documentType] ?? .notReady
                                    }

                                    // Ready documents
                                    if let readyDocs = groupedStatuses[.ready]?.sorted(by: { $0.rawValue < $1.rawValue }), !readyDocs.isEmpty {
                                        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                                            Label("Ready to Generate", systemImage: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.green)

                                            ForEach(readyDocs, id: \.self) { documentType in
                                                HStack {
                                                    Image(systemName: documentType.icon)
                                                        .foregroundColor(.green)
                                                        .frame(width: 20)
                                                    Text(documentType.shortName)
                                                        .font(.subheadline)
                                                    Spacer()
                                                }
                                            }
                                        }
                                        .padding(.bottom, Theme.Spacing.small)
                                    }

                                    // Needs more info documents
                                    if let needsInfoDocs = groupedStatuses[.needsMoreInfo]?.sorted(by: { $0.rawValue < $1.rawValue }), !needsInfoDocs.isEmpty {
                                        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                                            Label("Needs More Information", systemImage: "exclamationmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.yellow)

                                            ForEach(needsInfoDocs, id: \.self) { documentType in
                                                HStack {
                                                    Image(systemName: documentType.icon)
                                                        .foregroundColor(.yellow)
                                                        .frame(width: 20)
                                                    Text(documentType.shortName)
                                                        .font(.subheadline)
                                                    Spacer()
                                                }
                                            }
                                        }
                                        .padding(.bottom, Theme.Spacing.small)
                                    }

                                    // Not ready documents
                                    if let notReadyDocs = groupedStatuses[.notReady]?.sorted(by: { $0.rawValue < $1.rawValue }), !notReadyDocs.isEmpty {
                                        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                                            Label("Not Ready", systemImage: "xmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.red)

                                            ForEach(notReadyDocs, id: \.self) { documentType in
                                                HStack {
                                                    Image(systemName: documentType.icon)
                                                        .foregroundColor(.red.opacity(0.6))
                                                        .frame(width: 20)
                                                    Text(documentType.shortName)
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                    Spacer()
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(Theme.Spacing.large)
                                .background(Theme.Colors.aikoSecondary)
                                .cornerRadius(Theme.CornerRadius.medium)

                                Spacer(minLength: 100)
                            }
                            .padding(.horizontal, Theme.Spacing.large)
                        }

                        // Confirm Button
                        if hasReadyDocuments(viewStore.status.documentReadinessStatus) {
                            VStack(spacing: 0) {
                                Divider()

                                Button(action: {
                                    viewStore.send(.analysis(.confirmRequirements(true)))
                                }, label: {
                                    HStack(spacing: Theme.Spacing.medium) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)

                                        Text("Confirm Requirements")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .foregroundColor(.white)
                                    .background(
                                        LinearGradient(
                                            colors: [.green, .blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(Theme.CornerRadius.large)
                                    .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                                })
                                .padding(.horizontal, Theme.Spacing.large)
                                .padding(.vertical, Theme.Spacing.large)
                                .background(Color.black)
                            }
                        }
                    }
                }
                .background(Color.black)
                .modifier(NavigationBarHiddenModifier())
                .preferredColorScheme(.dark)
            }
        })
    }

    private func statusColor(for status: DocumentStatusFeature.DocumentStatus) -> Color {
        switch status {
        case .notReady: .red
        case .needsMoreInfo: .yellow
        case .ready: .green
        }
    }

    private func statusText(for status: DocumentStatusFeature.DocumentStatus) -> String {
        switch status {
        case .ready: "Ready"
        case .needsMoreInfo: "Needs Info"
        case .notReady: "Not Ready"
        }
    }

    private func hasReadyDocuments(_ status: [DocumentType: DocumentStatusFeature.DocumentStatus]) -> Bool {
        status.values.contains { $0 == .ready }
    }
}

// MARK: - Document Recommendation Dialog

public struct DocumentRecommendationDialog: View {
    let store: StoreOf<DocumentGenerationFeature>

    public init(store: StoreOf<DocumentGenerationFeature>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(store, observe: { $0 }, content: { viewStore in
            SwiftUI.NavigationView {
                VStack(spacing: Theme.Spacing.extraLarge) {
                    // Header
                    VStack(spacing: Theme.Spacing.medium) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)

                        Text("Document Recommendations")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Based on your requirements, I recommend these documents:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Theme.Spacing.large)

                    // Recommended Documents with categories
                    ScrollView {
                        VStack(spacing: Theme.Spacing.medium) {
                            let documentsByCategory = Dictionary(grouping: viewStore.analysis.recommendedDocuments) { documentType in
                                if [.sow, .soo, .pws, .qasp, .rrd].contains(documentType) {
                                    "Requirements & Planning"
                                } else if [.marketResearch, .codes, .competitionAnalysis, .procurementSourcing].contains(documentType) {
                                    "Procurement & Analysis"
                                } else if [.fiscalLawReview, .opsecReview, .justificationApproval].contains(documentType) {
                                    "Compliance & Review"
                                } else {
                                    "Advanced Documents"
                                }
                            }

                            ForEach(documentsByCategory.keys.sorted(), id: \.self) { category in
                                if let documents = documentsByCategory[category] {
                                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                                        Text(category)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)
                                            .padding(.leading, Theme.Spacing.small)

                                        ForEach(documents.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { documentType in
                                            HStack(spacing: Theme.Spacing.large) {
                                                Image(systemName: documentType.icon)
                                                    .font(.title2)
                                                    .foregroundColor(.blue)
                                                    .frame(width: 32, height: 32)

                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack {
                                                        Text(documentType.rawValue)
                                                            .font(.subheadline)
                                                            .fontWeight(.semibold)

                                                        if documentType.isProFeature {
                                                            Text("PRO")
                                                                .font(.caption2)
                                                                .fontWeight(.bold)
                                                                .foregroundColor(.white)
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 2)
                                                                .background(Color.orange)
                                                                .cornerRadius(6)
                                                        }
                                                    }

                                                    Text(documentType.description)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(2)
                                                }

                                                Spacer()

                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                                    .font(.title3)
                                            }
                                            .aikoCard()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Spacer()

                    // Action Buttons
                    VStack(spacing: Theme.Spacing.medium) {
                        Button(action: {
                            viewStore.send(.generateRecommendedDocuments)
                        }, label: {
                            Text("Auto-Generate Recommended Documents")
                        })
                        .aikoButton(variant: .primary, size: .large)

                        Button(action: {
                            viewStore.send(.analysis(.showDocumentRecommendation(false)))
                        }, label: {
                            Text("Let Me Select Manually")
                        })
                        .aikoButton(variant: .secondary, size: .medium)
                    }
                    .padding(.horizontal, Theme.Spacing.large)
                    .padding(.bottom, Theme.Spacing.large)
                }
                .padding(.horizontal, Theme.Spacing.large)
                .background(Theme.Colors.aikoBackground)
                .modifier(NavigationBarHiddenModifier())
            }
        })
    }
}

// MARK: - Delivery Options Dialog

public struct DeliveryOptionsDialog: View {
    let store: StoreOf<DocumentGenerationFeature>

    public init(store: StoreOf<DocumentGenerationFeature>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(store, observe: { $0 }, content: { viewStore in
            SwiftUI.NavigationView {
                VStack(spacing: Theme.Spacing.extraLarge) {
                    // Header
                    VStack(spacing: Theme.Spacing.medium) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)

                        Text("Delivery Options")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("How would you like to receive your documents?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Theme.Spacing.large)

                    // Generated Documents Summary
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        let documents = viewStore.generatedDocuments
                        let documentCount = documents.count
                        Text("Generated Documents (\(documentCount))")
                            .font(.headline)
                            .fontWeight(.semibold)

                        ForEach(documents.prefix(3), id: \.id) { document in
                            HStack {
                                Image(systemName: document.documentCategory.icon)
                                    .foregroundColor(.blue)
                                Text(document.title)
                                    .font(.subheadline)
                                Spacer()
                            }
                        }

                        if documents.count > 3 {
                            let moreCount = documents.count - 3
                            Text("+ \(moreCount) more documents")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .aikoCard()

                    Spacer()

                    // Delivery Options
                    VStack(spacing: Theme.Spacing.medium) {
                        ForEach(DocumentDeliveryFeature.DeliveryOption.allCases, id: \.self) { option in
                            Button(action: {
                                viewStore.send(.delivery(.deliverDocuments(option)))
                            }, label: {
                                HStack(spacing: Theme.Spacing.large) {
                                    Image(systemName: option.icon)
                                        .font(.title2)
                                        .frame(width: 32, height: 32)

                                    Text(option.title)
                                        .font(.headline)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(Theme.Spacing.large)
                                .background(Theme.Colors.aikoCard)
                                .cornerRadius(Theme.CornerRadius.large)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                            })
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.large)
                    .padding(.bottom, Theme.Spacing.large)
                }
                .padding(.horizontal, Theme.Spacing.large)
                .background(Theme.Colors.aikoBackground)
                .modifier(NavigationBarHiddenModifier())
            }
        })
    }
}

// MARK: - Email Confirmation Dialog

public struct EmailConfirmationDialog: View {
    let store: StoreOf<DocumentGenerationFeature>
    @Dependency(\.textFieldService) var textFieldService

    public init(store: StoreOf<DocumentGenerationFeature>) {
        self.store = store
    }

    public var body: some View {
        SwiftUI.NavigationView {
            WithViewStore(store, observe: \.delivery, content: { viewStore in
                VStack(spacing: Theme.Spacing.extraLarge) {
                    // Header
                    VStack(spacing: Theme.Spacing.medium) {
                        Image(systemName: "envelope.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)

                        Text("Email Confirmation")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Choose an email address to send your documents")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Theme.Spacing.large)

                    // Email Options
                    VStack(spacing: Theme.Spacing.medium) {
                        // Profile Email Option (if available)
                        if !viewStore.userProfileEmail.isEmpty {
                            EmailOptionButton(
                                title: "Use Profile Email",
                                subtitle: viewStore.userProfileEmail,
                                isSelected: viewStore.selectedEmailOption == .profile,
                                action: { viewStore.send(.delivery(.updateEmailOption(.profile))) }
                            )
                        }

                        // Different Email Option
                        EmailOptionButton(
                            title: viewStore.userProfileEmail.isEmpty ? "Enter Email Address" : "Different Email Address",
                            subtitle: "Specify a different email address",
                            isSelected: viewStore.selectedEmailOption == (viewStore.userProfileEmail.isEmpty ? .noProfile : .different),
                            action: {
                                viewStore.send(.delivery(.updateEmailOption(viewStore.userProfileEmail.isEmpty ? .noProfile : .different)))
                            }
                        )

                        // Custom Email Input
                        if viewStore.selectedEmailOption == .different || viewStore.selectedEmailOption == .noProfile {
                            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                                Text("Email Address")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                TextField("Enter email address", text: .init(
                                    get: { viewStore.customEmailAddress },
                                    set: { viewStore.send(.delivery(.updateCustomEmail($0))) }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .textFieldConfiguration(
                                    disableAutocapitalization: true,
                                    keyboardType: .emailAddress,
                                    supportsAutocapitalization: textFieldService.supportsAutocapitalization(),
                                    supportsKeyboardTypes: textFieldService.supportsKeyboardTypes()
                                )
                            }
                            .aikoCard()
                        }
                    }

                    Spacer()

                    // Action Buttons
                    VStack(spacing: Theme.Spacing.medium) {
                        Button(action: {
                            viewStore.send(.delivery(.sendDocumentsViaEmail))
                        }, label: {
                            Text("Send Documents")
                        })
                        .aikoButton(variant: .primary, size: .large)
                        .disabled(!canSendEmail(viewStore))

                        Button(action: {
                            viewStore.send(.delivery(.showEmailConfirmation(false)))
                        }, label: {
                            Text("Cancel")
                        })
                        .aikoButton(variant: .ghost, size: .medium)
                    }
                    .padding(.horizontal, Theme.Spacing.large)
                    .padding(.bottom, Theme.Spacing.large)
                }
                .padding(.horizontal, Theme.Spacing.large)
                .background(Theme.Colors.aikoBackground)
                .modifier(NavigationBarHiddenModifier())
            })
        }
    }

    private func canSendEmail(_ viewStore: ViewStore<DocumentDeliveryFeature.State, DocumentGenerationFeature.Action>) -> Bool {
        switch viewStore.selectedEmailOption {
        case .profile:
            !viewStore.userProfileEmail.isEmpty
        case .different, .noProfile:
            !viewStore.customEmailAddress.isEmpty && viewStore.customEmailAddress.contains("@")
        }
    }
}

struct EmailOptionButton: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.large) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .font(.title3)
            }
            .padding(Theme.Spacing.large)
            .background(Theme.Colors.aikoCard)
            .cornerRadius(Theme.CornerRadius.large)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
