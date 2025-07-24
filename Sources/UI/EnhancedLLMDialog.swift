import AppCore
import ComposableArchitecture
import SwiftUI

// MARK: - Enhanced LLM Decision Dialog

public struct EnhancedLLMDialog: View {
    let store: StoreOf<DocumentGenerationFeature>
    @Dependency(\.navigationService) var navigationService

    public init(store: StoreOf<DocumentGenerationFeature>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            SwiftUI.NavigationView {
                VStack(spacing: 0) {
                    headerView
                    analysisSummaryView(viewStore: viewStore)
                    decisionButtonsView(viewStore: viewStore)
                }
            }
            .background(Color.black)
            .modifier(NavigationBarHiddenModifier())
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: Theme.Spacing.medium) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("AIKO Analysis Complete")
                .font(.title2)
                .fontWeight(.bold)

            Text("How would you like to proceed?")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, Theme.Spacing.large)
        .padding(.horizontal, Theme.Spacing.large)
    }

    // MARK: - Analysis Summary View

    private func analysisSummaryView(viewStore: ViewStore<DocumentGenerationFeature.State, DocumentGenerationFeature.Action>) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.extraLarge) {
                analysisSection(viewStore: viewStore)
                confidenceSection(viewStore: viewStore)
                recommendedDocumentsSection(viewStore: viewStore)
            }
            .padding(.horizontal, Theme.Spacing.large)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Analysis Section

    private func analysisSection(viewStore: ViewStore<DocumentGenerationFeature.State, DocumentGenerationFeature.Action>) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Label("Initial Analysis", systemImage: "doc.text.magnifyingglass")
                .font(.headline)
                .fontWeight(.semibold)

            Text(viewStore.analysis.llmResponse)
                .font(.body)
                .padding(Theme.Spacing.large)
                .background(Theme.Colors.aikoSecondary)
                .cornerRadius(Theme.CornerRadius.medium)
        }
    }

    // MARK: - Confidence Section

    @ViewBuilder
    private func confidenceSection(viewStore: ViewStore<DocumentGenerationFeature.State, DocumentGenerationFeature.Action>) -> some View {
        if let confidence = calculateConfidence(viewStore) {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Label("Confidence Level", systemImage: "gauge")
                    .font(.headline)
                    .fontWeight(.semibold)

                HStack {
                    ProgressView(value: confidence)
                        .progressViewStyle(LinearProgressViewStyle(tint: confidenceColor(confidence)))

                    Text("\(Int(confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(confidenceMessage(confidence))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(Theme.Spacing.large)
            .background(Theme.Colors.aikoSecondary)
            .cornerRadius(Theme.CornerRadius.medium)
        }
    }

    // MARK: - Recommended Documents Section

    @ViewBuilder
    private func recommendedDocumentsSection(viewStore: ViewStore<DocumentGenerationFeature.State, DocumentGenerationFeature.Action>) -> some View {
        if !viewStore.analysis.recommendedDocuments.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                Label("Recommended Documents (\(viewStore.analysis.recommendedDocuments.count))",
                      systemImage: "doc.badge.checkmark")
                    .font(.headline)
                    .fontWeight(.semibold)

                ForEach(viewStore.analysis.recommendedDocuments.prefix(3), id: \.self) { doc in
                    HStack {
                        Image(systemName: doc.icon)
                            .foregroundColor(.green)
                            .frame(width: 20)
                        Text(doc.shortName)
                            .font(.subheadline)
                        Spacer()
                    }
                }

                if viewStore.analysis.recommendedDocuments.count > 3 {
                    Text("+ \(viewStore.analysis.recommendedDocuments.count - 3) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(Theme.Spacing.large)
            .background(Theme.Colors.aikoSecondary)
            .cornerRadius(Theme.CornerRadius.medium)
        }
    }

    // MARK: - Decision Buttons View

    private func decisionButtonsView(viewStore: ViewStore<DocumentGenerationFeature.State, DocumentGenerationFeature.Action>) -> some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: Theme.Spacing.medium) {
                refineRequirementsButton(viewStore: viewStore)
                manualSelectionButton(viewStore: viewStore)

                if !viewStore.analysis.recommendedDocuments.isEmpty {
                    aiRecommendationsButton(viewStore: viewStore)
                }

                cancelButton(viewStore: viewStore)
            }
            .padding(.horizontal, Theme.Spacing.large)
            .padding(.vertical, Theme.Spacing.large)
            .background(Color.black)
        }
    }

    // MARK: - Individual Button Views

    private func refineRequirementsButton(viewStore: ViewStore<DocumentGenerationFeature.State, DocumentGenerationFeature.Action>) -> some View {
        Button(action: {
            viewStore.send(.analysis(.confirmRequirements(true)))
            // TODO: Handle refinement mode transition
        }, label: {
            VStack(spacing: Theme.Spacing.small) {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.title3)
                    Text("Refine Requirements")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }

                Text("Let AIKO help gather more details for better documents")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Spacing.large)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(Theme.CornerRadius.large)
        })
    }

    private func manualSelectionButton(viewStore: ViewStore<DocumentGenerationFeature.State, DocumentGenerationFeature.Action>) -> some View {
        Button(action: {
            viewStore.send(.analysis(.confirmRequirements(false)))
            viewStore.send(.analysis(.showDocumentPicker(true)))
        }, label: {
            VStack(spacing: Theme.Spacing.small) {
                HStack {
                    Image(systemName: "hand.tap.fill")
                        .font(.title3)
                    Text("Select Documents Manually")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }

                Text("I know what I need - let me choose documents")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Spacing.large)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.aikoCard)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(Theme.CornerRadius.large)
        })
    }

    private func aiRecommendationsButton(viewStore: ViewStore<DocumentGenerationFeature.State, DocumentGenerationFeature.Action>) -> some View {
        Button(action: {
            viewStore.send(.generateRecommendedDocuments)
        }, label: {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title3)
                Text("Use AI Recommendations")
                    .fontWeight(.medium)
                Spacer()
                Text("\(viewStore.analysis.recommendedDocuments.count) docs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(Theme.Spacing.medium)
            .frame(maxWidth: .infinity)
            .foregroundColor(.blue)
        })
    }

    private func cancelButton(viewStore: ViewStore<DocumentGenerationFeature.State, DocumentGenerationFeature.Action>) -> some View {
        Button(action: {
            viewStore.send(.analysis(.confirmRequirements(false)))
        }, label: {
            Text("Cancel")
                .font(.subheadline)
                .foregroundColor(.secondary)
        })
        .padding(.top, Theme.Spacing.small)
    }

    // MARK: - Helper Functions

    private func calculateConfidence(_ viewStore: ViewStore<DocumentGenerationFeature.State, DocumentGenerationFeature.Action>) -> Double? {
        let readyCount = viewStore.status.documentReadinessStatus.values.count(where: { $0 == .ready })
        let totalCount = viewStore.status.documentReadinessStatus.count

        guard totalCount > 0 else { return nil }
        return Double(readyCount) / Double(totalCount)
    }

    private func confidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case 0.8 ... 1.0:
            .green
        case 0.5 ..< 0.8:
            .yellow
        default:
            .orange
        }
    }

    private func confidenceMessage(_ confidence: Double) -> String {
        switch confidence {
        case 0.8 ... 1.0:
            "I have enough information to generate high-quality documents"
        case 0.5 ..< 0.8:
            "I can generate documents, but more details would improve quality"
        default:
            "I recommend refining requirements for better results"
        }
    }
}

// MARK: - Requirements Refinement Dialog

public struct RequirementsRefinementDialog: View {
    let store: StoreOf<DocumentGenerationFeature>
    @State private var currentQuestion = 0
    @State private var answers: [String] = []

    // Dynamic questions based on requirements
    private let refinementQuestions = [
        RefinementQuestion(
            id: "budget",
            question: "What is your estimated budget for this acquisition?",
            helpText: "This helps determine the appropriate acquisition procedures",
            inputType: .currency
        ),
        RefinementQuestion(
            id: "timeline",
            question: "When do you need this acquisition completed?",
            helpText: "Include any critical milestones or deadlines",
            inputType: .date
        ),
        RefinementQuestion(
            id: "compliance",
            question: "Are there any special compliance requirements?",
            helpText: "E.g., CMMC, FedRAMP, Section 508, Buy American",
            inputType: .multipleChoice(["None", "CMMC Level 1", "CMMC Level 2", "CMMC Level 3", "FedRAMP", "Section 508", "Buy American", "Other"])
        ),
        RefinementQuestion(
            id: "competition",
            question: "Do you have any vendors in mind, or should we conduct full competition?",
            helpText: "This affects market research and solicitation approach",
            inputType: .text
        ),
        RefinementQuestion(
            id: "performance",
            question: "What are the key performance metrics or success criteria?",
            helpText: "How will you measure successful delivery?",
            inputType: .text
        ),
    ]

    public var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            SwiftUI.NavigationView {
                VStack(spacing: 0) {
                    progressBar
                    questionContent(viewStore: viewStore)
                }
            }
            .background(Theme.Colors.aikoBackground)
            .navigationTitle("Refine Requirements")
            .navigationConfiguration(
                displayMode: .inline,
                supportsNavigationBarDisplayMode: true
            )
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Skip") {
                        // TODO: Handle skip refinement
                        viewStore.send(.analysis(.showDocumentPicker(true)))
                    }
                }
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        ProgressView(value: Double(currentQuestion + 1), total: Double(refinementQuestions.count))
            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            .padding(.horizontal)
            .padding(.top)
    }

    // MARK: - Question Content

    @ViewBuilder
    private func questionContent(viewStore: ViewStore<DocumentGenerationFeature.State, DocumentGenerationFeature.Action>) -> some View {
        if currentQuestion < refinementQuestions.count {
            let question = refinementQuestions[currentQuestion]

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.extraLarge) {
                        questionHeader(question: question)

                        QuestionInputView(
                            question: question,
                            answer: Binding(
                                get: { answers[safe: currentQuestion] ?? "" },
                                set: { answers[safe: currentQuestion] = $0 }
                            )
                        )
                        .padding(.top)
                    }
                    .padding()
                }

                navigationButtons(viewStore: viewStore)
            }
        }
    }

    // MARK: - Question Header

    private func questionHeader(question: RefinementQuestion) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text("Question \(currentQuestion + 1) of \(refinementQuestions.count)")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(question.question)
                .font(.title3)
                .fontWeight(.bold)

            Text(question.helpText)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Navigation Buttons

    private func navigationButtons(viewStore: ViewStore<DocumentGenerationFeature.State, DocumentGenerationFeature.Action>) -> some View {
        HStack(spacing: Theme.Spacing.medium) {
            if currentQuestion > 0 {
                Button("Previous") {
                    withAnimation {
                        currentQuestion -= 1
                    }
                }
                .aikoButton(variant: .secondary, size: .medium)
            }

            Spacer()

            nextOrCompleteButton(viewStore: viewStore)
        }
        .padding()
    }

    // MARK: - Next/Complete Button

    private func nextOrCompleteButton(viewStore: ViewStore<DocumentGenerationFeature.State, DocumentGenerationFeature.Action>) -> some View {
        Button(currentQuestion < refinementQuestions.count - 1 ? "Next" : "Complete") {
            if currentQuestion < refinementQuestions.count - 1 {
                withAnimation {
                    currentQuestion += 1
                }
            } else {
                completeRefinement(viewStore: viewStore)
            }
        }
        .aikoButton(variant: .primary, size: .medium)
        .disabled((answers[safe: currentQuestion] ?? "").isEmpty)
    }

    // MARK: - Complete Refinement

    private func completeRefinement(viewStore: ViewStore<DocumentGenerationFeature.State, DocumentGenerationFeature.Action>) {
        let refinedRequirements = compileRefinedRequirements(
            original: viewStore.analysis.requirements,
            answers: answers,
            questions: refinementQuestions
        )
        // Update requirements and generate documents
        viewStore.send(.analysis(.requirementsChanged(refinedRequirements)))
        viewStore.send(.generateDocuments)
    }

    private func compileRefinedRequirements(original: String, answers: [String], questions: [RefinementQuestion]) -> String {
        var refined = original + "\n\n--- Additional Requirements ---\n"

        for (index, question) in questions.enumerated() {
            if let answer = answers[safe: index], !answer.isEmpty {
                refined += "\n\(question.question)\n→ \(answer)\n"
            }
        }

        return refined
    }
}

// MARK: - Supporting Types

struct RefinementQuestion: Sendable {
    let id: String
    let question: String
    let helpText: String
    let inputType: InputType

    enum InputType: Sendable {
        case text
        case currency
        case date
        case multipleChoice([String])
    }
}

struct QuestionInputView: View {
    let question: RefinementQuestion
    @Binding var answer: String
    @Dependency(\.keyboardService) var keyboardService

    var body: some View {
        switch question.inputType {
        case .text:
            TextEditor(text: $answer)
                .frame(minHeight: 100)
                .padding(8)
                .background(Theme.Colors.aikoSecondary)
                .cornerRadius(Theme.CornerRadius.medium)

        case .currency:
            HStack {
                Text("$")
                    .font(.title3)
                TextField("0", text: $answer)
                    .keyboardConfiguration(.numberPad, supportsTypes: keyboardService.supportsKeyboardTypes())
                    .font(.title3)
            }
            .padding()
            .background(Theme.Colors.aikoSecondary)
            .cornerRadius(Theme.CornerRadius.medium)

        case .date:
            DatePicker("Select date", selection: .constant(Date()), displayedComponents: .date)
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
                .background(Theme.Colors.aikoSecondary)
                .cornerRadius(Theme.CornerRadius.medium)

        case let .multipleChoice(options):
            VStack(spacing: Theme.Spacing.small) {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        if answer.contains(option) {
                            answer = answer.replacingOccurrences(of: option, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        } else {
                            answer = answer.isEmpty ? option : "\(answer), \(option)"
                        }
                    }, label: {
                        HStack {
                            Text(option)
                                .foregroundColor(.primary)
                            Spacer()
                            if answer.contains(option) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Theme.Colors.aikoSecondary)
                        .cornerRadius(Theme.CornerRadius.medium)
                    })
                }
            }
        }
    }
}

// MARK: - Safe Array Subscript Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        get {
            guard index >= 0, index < count else { return nil }
            return self[index]
        }
        set {
            guard index >= 0, index < count else { return }
            if let newValue {
                self[index] = newValue
            }
        }
    }
}
