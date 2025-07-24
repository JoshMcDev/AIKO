import AppCore
import ComposableArchitecture
import SwiftUI

struct AcquisitionChatView: View {
    let store: StoreOf<AcquisitionChatFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }, content: { viewStore in
            ZStack {
                // Background that extends to safe area
                Color.black
                    .ignoresSafeArea()

                chatContent(viewStore: viewStore)
            }
            .preferredColorScheme(.dark)
            .alert(
                "Save Acquisition?",
                isPresented: .init(
                    get: { viewStore.showingCloseConfirmation },
                    set: { viewStore.send(.confirmClose($0)) }
                )
            ) {
                Button("Save & Close") {
                    viewStore.send(.closeChat)
                }
                Button("Continue Chatting", role: .cancel) {
                    viewStore.send(.confirmClose(false))
                }
            } message: {
                Text("You've provided enough information to start generating documents. Would you like to save this acquisition and return to the main view?")
            }
        })
    }

    @ViewBuilder
    private func chatContent(viewStore: ViewStore<AcquisitionChatFeature.State, AcquisitionChatFeature.Action>) -> some View {
        VStack(spacing: 0) {
            // Ambient status bar like AgenticChatView
            HStack(spacing: 12) {
                if !viewStore.activeTasks.isEmpty {
                    StatusPill(
                        text: "\(viewStore.activeTasks.count) Active",
                        color: .green
                    )
                }

                if viewStore.agentState == .executing {
                    StatusPill(
                        text: "Working...",
                        color: .blue,
                        isAnimating: true
                    )
                }

                Spacer()

                // Share chat history button
                ShareButton(
                    content: generateChatHistoryContent(viewStore: viewStore),
                    fileName: "Chat_History_\(Date().formatted(.dateTime.year().month().day()))",
                    buttonStyle: .icon
                )
                .padding(.trailing, 8)

                // Removed Agent State Indicator animation

                // Close button
                Button(action: {
                    if viewStore.gatheredRequirements.hasMinimumInfo {
                        viewStore.send(.confirmClose(true))
                    } else {
                        viewStore.send(.closeChat)
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Theme.Colors.aikoSecondary)

            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewStore.messages) { message in
                            HStack(alignment: .top, spacing: 12) {
                                if message.role == .user {
                                    Spacer(minLength: 60)
                                }

                                VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                                    // Message content
                                    Text(message.content)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            message.role == .user
                                                ? Color.blue
                                                : Theme.Colors.aikoCard
                                        )
                                        .foregroundColor(
                                            message.role == .user
                                                ? .white
                                                : .white
                                        )
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 18)
                                        )

                                    // Approval buttons if needed
                                    if let approval = viewStore.approvalRequests[message.id] {
                                        ApprovalRequestView(
                                            request: approval,
                                            onApprove: {
                                                viewStore.send(.approveAction(approval.id))
                                            },
                                            onReject: {
                                                viewStore.send(.rejectAction(approval.id))
                                            }
                                        )
                                        .padding(.top, 4)
                                    }

                                    // Message cards
                                    if let card = viewStore.messageCards[message.id] {
                                        MessageCardView(card: card)
                                            .padding(.top, 8)
                                    }

                                    // Timestamp
                                    Text(message.timestamp, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                if message.role == .assistant {
                                    Spacer(minLength: 60)
                                }
                            }
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewStore.messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo(viewStore.messages.last?.id)
                    }
                }
            }

            // Input Area - using same component as main app
            VStack(spacing: 0) {
                // Suggestions
                if !viewStore.suggestions.isEmpty, viewStore.currentInput.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewStore.suggestions, id: \.self) { suggestion in
                                Button(action: {
                                    viewStore.send(.inputChanged(suggestion))
                                }) {
                                    Text(suggestion)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Theme.Colors.aikoCard)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }

                // Reuse InputArea component with chat mode
                InputArea(
                    requirements: viewStore.currentInput,
                    isGenerating: viewStore.agentState == .executing,
                    uploadedDocuments: viewStore.uploadedDocuments.map { doc in
                        UploadedDocument(
                            fileName: doc.fileName,
                            data: doc.data
                        )
                    },
                    isChatMode: true,
                    isRecording: viewStore.isRecording,
                    onRequirementsChanged: { text in
                        viewStore.send(.inputChanged(text))
                    },
                    onAnalyzeRequirements: {
                        viewStore.send(.sendMessage)
                    },
                    onEnhancePrompt: {
                        viewStore.send(.enhancePrompt)
                    },
                    onStartRecording: {
                        viewStore.send(.startRecording)
                    },
                    onStopRecording: {
                        viewStore.send(.stopRecording)
                    },
                    onShowDocumentPicker: {
                        viewStore.send(.showDocumentPicker)
                    },
                    onShowImagePicker: {
                        viewStore.send(.showImagePicker)
                    },
                    onRemoveDocument: { documentId in
                        viewStore.send(.removeDocument(documentId))
                    }
                )
            }
        }
        .background(Theme.Colors.aikoBackground)
    }
}

@MainActor
private func generateChatHistoryContent(viewStore: ViewStore<AcquisitionChatFeature.State, AcquisitionChatFeature.Action>) -> String {
    var content = """
    Acquisition Chat History
    Generated: \(Date().formatted())

    """

    // Add gathered requirements if any
    if viewStore.gatheredRequirements.hasMinimumInfo {
        content += """
        GATHERED REQUIREMENTS:
        Basic information has been collected for this acquisition.

        """
    }

    content += "CHAT MESSAGES:\n\n"

    // Add all messages
    for message in viewStore.messages {
        let role = message.role == .user ? "User": "Assistant"
        content += "\(role): \(message.content)\n\n"
    }

    return content
}

// StatusPill is already defined in AgenticChatFeature.swift
// Import it from AgenticChatFeature module

struct ChatHeaderView: View {
    let onClose: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("New Acquisition")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("AIKO Assistant")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
        .background(Theme.Colors.aikoSecondary)
    }
}

struct RequirementsProgressView: View {
    let completionPercentage: Double
    let documentReadiness: [DocumentType: Bool]

    var readyDocuments: Int {
        documentReadiness.values.count(where: { $0 })
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.small) {
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .green]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * completionPercentage, height: 6)
                        .animation(.easeInOut, value: completionPercentage)
                }
            }
            .frame(height: 6)

            // Status Text
            HStack {
                Label("\(Int(completionPercentage * 100))% Complete", systemImage: "chart.bar.fill")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                if readyDocuments > 0 {
                    Label("\(readyDocuments) Documents Ready", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Theme.Colors.aikoSecondary.opacity(0.5))
    }
}

struct AcquisitionChatBubble: View {
    let message: AcquisitionChatFeature.ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.small) {
            VStack(alignment: message.role == .user ? .trailing: .leading, spacing: 4) {
                Text(message.role == .user ? "You": "AIKO")
                    .font(.caption)
                    .foregroundColor(.secondary)

                DocumentRichTextView(content: message.content)
                    .padding(Theme.Spacing.medium)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                            .fill(message.role == .user ? Theme.Colors.aikoAccent: Theme.Colors.aikoSecondary)
                    )
                    .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing: .leading)
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing: .leading)

            if message.role == .user {
                Image(systemName: "person.circle.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(width: 24, height: 24)
            }
        }
    }
}

struct TypingIndicator: View {
    @State private var animationPhase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 3) { index in
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationPhase == index ? 1.3: 1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animationPhase
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .fill(Theme.Colors.aikoSecondary)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            animationPhase = 1
        }
    }
}

struct QuickActionsBar: View {
    let onGenerateAll: () -> Void
    let onSelectSpecific: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            Button(action: onGenerateAll) {
                Label("Generate All", systemImage: "wand.and.stars")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.small)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(Theme.CornerRadius.medium)
            }

            Button(action: onSelectSpecific) {
                Label("Select Documents", systemImage: "list.bullet")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.small)
                    .background(Theme.Colors.aikoSecondary)
                    .cornerRadius(Theme.CornerRadius.medium)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, Theme.Spacing.small)
        .background(Theme.Colors.aikoBackground.opacity(0.9))
    }
}

struct ChatInputArea: View {
    @Binding var text: String
    let isProcessing: Bool
    let isRecording: Bool
    let onSend: () -> Void
    let onEnhancePrompt: () -> Void
    let onUploadDocument: () -> Void
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onAddReference: (String) -> Void

    @State private var showingUploadOptions = false
    @State private var showingReferenceInput = false
    @State private var referenceInput = ""

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.1))

            HStack(spacing: 0) {
                // Text input field
                ZStack(alignment: .leading) {
                    // Custom placeholder
                    if text.isEmpty {
                        Text("...")
                            .font(.body)
                            .foregroundColor(.gray)
                            .padding(.leading, Theme.Spacing.large)
                            .padding(.vertical, Theme.Spacing.medium)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $text, axis: .vertical)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.white)
                        .padding(.leading, Theme.Spacing.large)
                        .padding(.vertical, Theme.Spacing.medium)
                        .padding(.trailing, Theme.Spacing.small)
                        .lineLimit(1 ... 4)
                        .disabled(isProcessing)
                        .onSubmit {
                            if !text.isEmpty, !isProcessing {
                                onSend()
                            }
                        }
                }

                // Action buttons
                HStack(spacing: Theme.Spacing.small) {
                    // Enhance prompt button
                    Button(action: {
                        if !text.isEmpty {
                            onEnhancePrompt()
                        }
                    }) {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundColor(!text.isEmpty ? .yellow: .secondary)
                            .frame(width: 32, height: 32)
                            .scaleEffect(!text.isEmpty ? 1.0: 0.9)
                            .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
                    }
                    .disabled(text.isEmpty || isProcessing)

                    // Upload options (+ icon)
                    Button(action: { showingUploadOptions.toggle() }) {
                        Image(systemName: "plus")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                    }
                    .confirmationDialog("Add Content", isPresented: $showingUploadOptions) {
                        Button(" Upload Documents") {
                            onUploadDocument()
                        }
                        #if os(iOS)
                            Button("📷 Scan Document") {
                                onUploadDocument() // For now, use same action
                            }
                        #endif
                        Button(" Add Reference") {
                            showingReferenceInput = true
                        }
                        Button("Cancel", role: .cancel) {}
                    }

                    // Voice input (microphone)
                    Button(action: {
                        if isRecording {
                            onStopRecording()
                        } else {
                            onStartRecording()
                        }
                    }) {
                        Image(systemName: isRecording ? "mic.fill": "mic")
                            .font(.title3)
                            .foregroundColor(isRecording ? .red: .secondary)
                            .frame(width: 32, height: 32)
                            .scaleEffect(isRecording ? 1.2: 1.0)
                            .animation(.easeInOut(duration: 0.2), value: isRecording)
                    }
                    .disabled(isProcessing && !isRecording)

                    // Send button
                    Button(action: onSend) {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: text.isEmpty ? "arrow.up.circle": "arrow.up.circle.fill")
                                .font(.title3)
                                .foregroundColor(text.isEmpty ? .secondary: .white)
                                .frame(width: 32, height: 32)
                        }
                    }
                    .background(
                        Group {
                            if !text.isEmpty, !isProcessing {
                                Circle()
                                    .fill(Theme.Colors.aikoPrimary)
                            } else {
                                Circle()
                                    .fill(Color.clear)
                            }
                        }
                    )
                    .disabled(text.isEmpty || isProcessing)
                    .scaleEffect(text.isEmpty ? 1.0: 1.1)
                    .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
                }
                .padding(.trailing, Theme.Spacing.medium)
                .padding(.vertical, Theme.Spacing.small)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Theme.Colors.aikoSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, Theme.Spacing.large)
            .padding(.vertical, Theme.Spacing.large)
            .background(Theme.Colors.aikoBackground)
        }
        .alert("Add Reference", isPresented: $showingReferenceInput) {
            TextField("Enter URL or reference", text: $referenceInput)
            Button("Add") {
                if !referenceInput.isEmpty {
                    onAddReference(referenceInput)
                    referenceInput = ""
                }
            }
            Button("Cancel", role: .cancel) {
                referenceInput = ""
            }
        } message: {
            Text("Enter a URL or reference to add to your requirements")
        }
    }
}
