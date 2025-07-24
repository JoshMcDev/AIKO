import ComposableArchitecture
import SwiftUI
#if os(iOS)
    import UIKit
#else
    import AppKit
#endif

// MARK: - Platform-specific Colors

private extension Color {
    static var windowBackground: Color {
        #if os(macOS)
            return Color(NSColor.windowBackgroundColor)
        #else
            return Color(UIColor.secondarySystemBackground)
        #endif
    }
}

// MARK: - Smart Defaults Demo View

struct SmartDefaultsDemoView: View {
    let store: StoreOf<SmartDefaultsDemoFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }, content: { viewStore in
            ScrollView {
                VStack(spacing: 20) {
                    headerSection

                    if viewStore.isLoading {
                        ProgressView("Analyzing context...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        contextSection(viewStore)
                        formFieldsSection(viewStore)
                        confidenceMetricsSection(viewStore)
                        actionButtonsSection(viewStore)
                    }
                }
                .padding()
            }
            .navigationTitle("Smart Defaults Demo")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.large)
            #endif
                .onAppear {
                    viewStore.send(.onAppear)
                }
        })
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Intelligent Form Auto-Fill", systemImage: "wand.and.stars")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Smart Defaults learns from your patterns and context to minimize data entry")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Context Section

    private func contextSection(_ viewStore: ViewStoreOf<SmartDefaultsDemoFeature>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Context")
                .font(.headline)

            VStack(spacing: 12) {
                contextRow("User", viewStore.context.userId)
                contextRow("Organization", viewStore.context.organizationUnit)
                contextRow("Fiscal Year", viewStore.context.fiscalYear)
                contextRow("Document Type", viewStore.context.documentType?.rawValue ?? "None")
                if viewStore.context.isEndOfFiscalYear {
                    contextRow("Status", "End of Fiscal Year", .orange)
                }
            }
        }
        .padding()
        .background(Color.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2)
    }

    // MARK: - Form Fields Section

    private func formFieldsSection(_ viewStore: ViewStoreOf<SmartDefaultsDemoFeature>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Form Fields with Smart Defaults")
                .font(.headline)

            ForEach(viewStore.formFields) { field in
                SmartDefaultFieldRow(
                    field: field,
                    onAccept: { viewStore.send(.acceptDefault(field)) },
                    onReject: { viewStore.send(.rejectDefault(field)) },
                    onEdit: { newValue in viewStore.send(.editField(field, newValue)) }
                )
            }
        }
        .padding()
        .background(Color.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2)
    }

    // MARK: - Confidence Metrics Section

    private func confidenceMetricsSection(_ viewStore: ViewStoreOf<SmartDefaultsDemoFeature>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Confidence Metrics")
                .font(.headline)

            HStack(spacing: 20) {
                SmartDefaultsMetricCard(
                    title: "Auto-Fill",
                    value: "\(viewStore.metrics.autoFillCount)",
                    subtitle: "High confidence",
                    color: .green
                )

                SmartDefaultsMetricCard(
                    title: "Suggested",
                    value: "\(viewStore.metrics.suggestedCount)",
                    subtitle: "Medium confidence",
                    color: .orange
                )

                SmartDefaultsMetricCard(
                    title: "Manual",
                    value: "\(viewStore.metrics.manualCount)",
                    subtitle: "User input needed",
                    color: .blue
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Learning Progress")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ProgressView(value: viewStore.metrics.learningProgress)
                    .tint(.purple)

                Text("\(Int(viewStore.metrics.learningProgress * 100))% pattern confidence")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2)
    }

    // MARK: - Action Buttons Section

    private func actionButtonsSection(_ viewStore: ViewStoreOf<SmartDefaultsDemoFeature>) -> some View {
        VStack(spacing: 12) {
            Button(action: { viewStore.send(.generateNewDefaults) }) {
                Label("Generate New Defaults", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            HStack(spacing: 12) {
                Button(action: { viewStore.send(.acceptAllDefaults) }) {
                    Label("Accept All", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.green)

                Button(action: { viewStore.send(.clearAllDefaults) }) {
                    Label("Clear All", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

            Button(action: { viewStore.send(.showLearningDetails) }) {
                Label("View Learning Details", systemImage: "brain")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.top)
    }

    // MARK: - Helper Views

    private func contextRow(_ label: String, _ value: String, _ color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

// MARK: - Smart Default Field Row

struct SmartDefaultFieldRow: View {
    let field: SmartDefaultField
    let onAccept: () -> Void
    let onReject: () -> Void
    let onEdit: (String) -> Void

    @State private var isEditing = false
    @State private var editedValue = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(field.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if let reasoning = field.reasoning {
                        Text(reasoning)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                SmartDefaultsConfidenceIndicator(confidence: field.confidence)
            }

            HStack(spacing: 8) {
                if isEditing {
                    TextField("Enter value", text: $editedValue)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            onEdit(editedValue)
                            isEditing = false
                        }
                } else {
                    Text(field.value)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(backgroundColorForStatus(field.status))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onTapGesture {
                            editedValue = field.value
                            isEditing = true
                        }
                }

                if field.status == .suggested {
                    Button(action: onAccept) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)

                    Button(action: onReject) {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !field.alternatives.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(field.alternatives, id: \.self) { alternative in
                            Button(action: { onEdit(alternative) }) {
                                Text(alternative)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.gray.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func backgroundColorForStatus(_ status: SmartDefaultField.Status) -> Color {
        switch status {
        case .autoFilled:
            Color.green.opacity(0.1)
        case .suggested:
            Color.orange.opacity(0.1)
        case .manual:
            Color.blue.opacity(0.1)
        case .userEdited:
            Color.purple.opacity(0.1)
        }
    }
}

// MARK: - Confidence Indicator

struct SmartDefaultsConfidenceIndicator: View {
    let confidence: Float

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 5) { index in
                Circle()
                    .fill(index < Int(confidence * 5) ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }

            Text("\(Int(confidence * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Metric Card

struct SmartDefaultsMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

struct SmartDefaultsDemoView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SmartDefaultsDemoView(
                store: Store(
                    initialState: SmartDefaultsDemoFeature.State(),
                    reducer: { SmartDefaultsDemoFeature() }
                )
            )
        }
    }
}
