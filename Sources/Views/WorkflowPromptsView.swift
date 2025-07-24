import ComposableArchitecture
import SwiftUI

struct WorkflowPromptsView: View {
    let store: StoreOf<DocumentAnalysisFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }, content: { viewStore in
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                // Workflow State Header
                if let context = viewStore.workflowContext {
                    WorkflowStateHeader(
                        currentState: context.currentState,
                        automationEnabled: context.automationSettings.enabled
                    )
                }

                // Pending Approvals
                if !viewStore.pendingApprovals.isEmpty {
                    PendingApprovalsSection(
                        approvals: viewStore.pendingApprovals,
                        onApprove: { stepId in
                            viewStore.send(.approveWorkflowStep(stepId, .approved))
                        },
                        onReject: { stepId in
                            viewStore.send(.approveWorkflowStep(stepId, .rejected))
                        }
                    )
                }

                // Suggested Prompts
                if !viewStore.suggestedPrompts.isEmpty {
                    SuggestedPromptsSection(
                        prompts: viewStore.suggestedPrompts,
                        onSelectPrompt: { prompt in
                            viewStore.send(.selectPrompt(prompt))
                        }
                    )
                }

                // Automation Controls
                AutomationControlsSection(
                    settings: viewStore.automationSettings,
                    onToggleAutomation: { enabled in
                        Task { @MainActor in
                            var settings = viewStore.automationSettings
                            settings.enabled = enabled
                            viewStore.send(.updateAutomationSettings(settings))
                        }
                    },
                    onShowSettings: {
                        viewStore.send(.toggleAutomationSettings(true))
                    }
                )
            }
            .padding(Theme.Spacing.large)
            .background(Theme.Colors.aikoSecondary)
            .cornerRadius(Theme.CornerRadius.large)
        })
    }
}

// MARK: - Workflow State Header

struct WorkflowStateHeader: View {
    let currentState: WorkflowState
    let automationEnabled: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Workflow Status")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(currentState.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(automationEnabled ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)

                Text(automationEnabled ? "Automated" : "Manual")
                    .font(.caption)
                    .foregroundColor(automationEnabled ? .green : .orange)
            }
            .padding(.horizontal, Theme.Spacing.small)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                    .fill((automationEnabled ? Color.green : Color.orange).opacity(0.2))
            )
        }
    }
}

// MARK: - Pending Approvals Section

struct PendingApprovalsSection: View {
    let approvals: [WorkflowStep]
    let onApprove: (WorkflowStep.ID) -> Void
    let onReject: (WorkflowStep.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text("Pending Approvals")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            ForEach(approvals) { step in
                ApprovalCard(
                    step: step,
                    onApprove: { onApprove(step.id) },
                    onReject: { onReject(step.id) }
                )
            }
        }
    }
}

// MARK: - Approval Card

struct ApprovalCard: View {
    let step: WorkflowStep
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text(step.action)
                .font(.subheadline)
                .foregroundColor(.white)

            if let prompt = step.llmPrompt {
                Text(prompt)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Button(action: onReject) {
                    Label("Reject", systemImage: "xmark.circle")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(BorderlessButtonStyle())

                Spacer()

                Button(action: onApprove) {
                    Label("Approve", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(Theme.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Suggested Prompts Section

struct SuggestedPromptsSection: View {
    let prompts: [SuggestedPrompt]
    let onSelectPrompt: (SuggestedPrompt) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text("Suggested Next Steps")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            ForEach(prompts.sorted(by: { $0.priority.rawValue > $1.priority.rawValue })) { prompt in
                PromptCard(
                    prompt: prompt,
                    onSelect: { onSelectPrompt(prompt) }
                )
            }
        }
    }
}

// MARK: - Prompt Card

struct PromptCard: View {
    let prompt: SuggestedPrompt
    let onSelect: () -> Void

    var priorityColor: Color {
        switch prompt.priority {
        case .critical: .red
        case .high: .orange
        case .medium: .blue
        case .low: .gray
        }
    }

    var categoryIcon: String {
        switch prompt.category {
        case .dataCollection: "doc.text"
        case .clarification: "questionmark.circle"
        case .documentSelection: "doc.badge.plus"
        case .approval: "checkmark.shield"
        case .nextStep: "arrow.right.circle"
        }
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Theme.Spacing.medium) {
                Image(systemName: categoryIcon)
                    .font(.body)
                    .foregroundColor(priorityColor)
                    .frame(width: 24)

                Text(prompt.prompt)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(Theme.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                    .fill(Theme.Colors.aikoTertiary)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Automation Controls Section

struct AutomationControlsSection: View {
    let settings: AutomationSettings
    let onToggleAutomation: @Sendable (Bool) -> Void
    let onShowSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            HStack {
                Text("Automation")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()

                Toggle("", isOn: .init(
                    get: { settings.enabled },
                    set: onToggleAutomation
                ))
                .labelsHidden()
                .tint(Color(red: 0.6, green: 0.4, blue: 1.0))
            }

            if settings.enabled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: settings.requireApprovalForDocumentGeneration ? "checkmark.square" : "square")
                            .font(.caption2)
                        Text("Require approval for documents")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: settings.autoSuggestNextSteps ? "checkmark.square" : "square")
                            .font(.caption2)
                        Text("Auto-suggest next steps")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                Button(action: onShowSettings) {
                    Text("Configure Automation")
                        .font(.caption)
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 1.0))
                }
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Automation Settings Sheet

struct AutomationSettingsSheet: View {
    @Binding var settings: AutomationSettings
    let onDismiss: () -> Void

    var body: some View {
        SwiftUI.NavigationView {
            Form {
                Section("Approval Requirements") {
                    Toggle("Document Generation", isOn: $settings.requireApprovalForDocumentGeneration)
                    Toggle("Data Collection", isOn: $settings.requireApprovalForDataCollection)
                    Toggle("Workflow Transitions", isOn: $settings.requireApprovalForWorkflowTransitions)
                }

                Section("Automation Features") {
                    Toggle("Auto-suggest Next Steps", isOn: $settings.autoSuggestNextSteps)
                    Toggle("Auto-fill from Profile", isOn: $settings.autoFillFromProfile)
                    Toggle("Auto-fill from Previous Documents", isOn: $settings.autoFillFromPreviousDocuments)
                }
            }
            .navigationTitle("Automation Settings")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    #if os(iOS)
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done", action: onDismiss)
                        }
                    #else
                        ToolbarItem(placement: .automatic) {
                            Button("Done", action: onDismiss)
                        }
                    #endif
                }
        }
    }
}
