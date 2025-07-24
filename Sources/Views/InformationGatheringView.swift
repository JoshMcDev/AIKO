import ComposableArchitecture
import SwiftUI

struct InformationGatheringView: View {
    let store: StoreOf<DocumentExecutionFeature>
    @State private var currentAnswer: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        WithViewStore(store, observe: { $0 }, content: { viewStore in
            SwiftUI.NavigationView {
                ZStack {
                    Theme.Colors.aikoBackground
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        // Header
                        InformationHeaderView(onClose: {
                            viewStore.send(.showInformationGathering(false))
                        })

                        // Progress indicator
                        if !viewStore.informationQuestions.isEmpty {
                            ProgressIndicatorView(
                                currentIndex: viewStore.currentQuestionIndex,
                                total: viewStore.informationQuestions.count
                            )
                        }

                        // Main content
                        QuestionContentView(
                            viewStore: viewStore,
                            currentAnswer: $currentAnswer,
                            isTextFieldFocused: _isTextFieldFocused
                        )
                    }
                }
                #if os(iOS)
                .navigationBarHidden(true)
                #endif
            }
        })
    }
}

// Header Component
struct InformationHeaderView: View {
    let onClose: () -> Void

    var body: some View {
        HStack {
            Text("Additional Information Needed")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
    }
}

// Question Content Component
struct QuestionContentView: View {
    let viewStore: ViewStore<DocumentExecutionFeature.State, DocumentExecutionFeature.Action>
    @Binding var currentAnswer: String
    @FocusState var isTextFieldFocused: Bool

    var body: some View {
        if viewStore.currentQuestionIndex < viewStore.informationQuestions.count {
            let question = viewStore.informationQuestions[viewStore.currentQuestionIndex]

            ScrollView {
                VStack(spacing: Theme.Spacing.extraLarge) {
                    // Question
                    QuestionView(
                        question: question,
                        index: viewStore.currentQuestionIndex,
                        total: viewStore.informationQuestions.count
                    )

                    // Answer field
                    AnswerFieldView(
                        question: question,
                        answer: $currentAnswer,
                        isTextFieldFocused: _isTextFieldFocused
                    )

                    // Action buttons
                    ActionButtonsView(
                        viewStore: viewStore,
                        question: question,
                        currentAnswer: $currentAnswer
                    )

                    Spacer()
                }
                .padding()
            }
        }
    }
}

// Action Buttons Component
struct ActionButtonsView: View {
    let viewStore: ViewStore<DocumentExecutionFeature.State, DocumentExecutionFeature.Action>
    let question: DocumentExecutionFeature.InformationQuestion
    @Binding var currentAnswer: String

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            if viewStore.currentQuestionIndex > 0 {
                Button(action: {
                    // Go back to previous question
                    // This would need a new action in the reducer
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                            .fill(Color.white.opacity(0.2))
                    )
                }
            }

            Spacer()

            Button(action: {
                if !currentAnswer.isEmpty || !question.isRequired {
                    viewStore.send(.answerQuestion(question.id.uuidString, currentAnswer))
                    currentAnswer = ""
                }
            }) {
                HStack {
                    Text(viewStore.currentQuestionIndex < viewStore.informationQuestions.count - 1 ? "Next" : "Submit")
                    Image(systemName: viewStore.currentQuestionIndex < viewStore.informationQuestions.count - 1 ? "chevron.right" : "checkmark.circle.fill")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .fill((currentAnswer.isEmpty && question.isRequired) ? Color.gray : Color.blue)
                )
            }
            .disabled(currentAnswer.isEmpty && question.isRequired)
        }
    }
}

// Custom text field style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .fill(Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .foregroundColor(.white)
            .accentColor(.blue)
    }
}

// View modifier helper
extension View {
    @ViewBuilder
    func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
