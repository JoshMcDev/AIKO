import AppCore
import ComposableArchitecture
import SwiftUI

// MARK: - LLM Provider Settings View

struct LLMProviderSettingsView: View {
    let store: StoreOf<LLMProviderSettingsFeature>
    @Dependency(\.navigationService) var navigationService

    var body: some View {
        WithViewStore(store, observe: { $0 }, content: { store in
            List {
                // Active Provider Section
                Section {
                    if let activeProvider = store.activeProvider {
                        ProviderRow(
                            provider: activeProvider,
                            isActive: true,
                            isConfigured: true,
                            onTap: {}
                        )
                    } else {
                        Text("No active provider")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Active Provider")
                }

                // Available Providers Section
                Section {
                    ForEach(store.availableProviders) { providerState in
                        ProviderRow(
                            provider: providerState.provider,
                            isActive: providerState.isActive,
                            isConfigured: providerState.isConfigured,
                            onTap: {
                                store.send(.selectProvider(providerState.provider.id))
                            }
                        )
                    }
                } header: {
                    Text("Available Providers")
                } footer: {
                    Text("Configure providers to enable AI features. API keys are stored securely in the system keychain.")
                        .font(.caption)
                }

                // Provider Capabilities Section
                if let selectedProvider = store.selectedProvider {
                    Section {
                        ProviderCapabilitiesView(provider: selectedProvider)
                    } header: {
                        Text("\(selectedProvider.name) Capabilities")
                    }
                }
            }
            .navigationTitle("LLM Providers")
            .navigationConfiguration(
                displayMode: .large,
                supportsNavigationBarDisplayMode: navigationService.supportsNavigationBarDisplayMode()
            )
            .sheet(
                store: self.store.scope(
                    state: \.$configurationSheet,
                    action: \.configurationSheet
                )
            ) { configStore in
                NavigationStack {
                    LLMProviderConfigurationView(store: configStore)
                }
            }
            .alert(
                store: self.store.scope(
                    state: \.$alert,
                    action: \.alert
                )
            )
            .onAppear {
                store.send(.onAppear)
            }
        })
    }
}

// MARK: - Provider Row

struct ProviderRow: View {
    let provider: any LLMProviderProtocol
    let isActive: Bool
    let isConfigured: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(provider.name)
                            .font(.headline)

                        if isActive {
                            Label("Active", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }

                    Text(provider.id)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isConfigured {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.orange)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Provider Capabilities View

struct ProviderCapabilitiesView: View {
    let provider: any LLMProviderProtocol

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Features
            VStack(alignment: .leading, spacing: 8) {
                Text("Features")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    CapabilityBadge(
                        title: "Streaming",
                        isSupported: provider.capabilities.supportsStreaming
                    )

                    CapabilityBadge(
                        title: "Vision",
                        isSupported: provider.capabilities.supportsVision
                    )

                    CapabilityBadge(
                        title: "Functions",
                        isSupported: provider.capabilities.supportsFunctionCalling
                    )

                    CapabilityBadge(
                        title: "Embeddings",
                        isSupported: provider.capabilities.supportsEmbeddings
                    )
                }
            }

            // Context Limits
            VStack(alignment: .leading, spacing: 8) {
                Text("Limits")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 20) {
                    Label("\(provider.capabilities.maxContextLength / 1000)K context", systemImage: "doc.text")
                        .font(.caption)

                    Label("\(provider.capabilities.maxTokens) max output", systemImage: "text.cursor")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            // Available Models
            if !provider.capabilities.supportedModels.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Models")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(provider.capabilities.supportedModels) { model in
                        ModelRow(model: model)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Capability Badge

struct CapabilityBadge: View {
    let title: String
    let isSupported: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isSupported ? "checkmark.circle.fill" : "xmark.circle")
                .font(.caption2)

            Text(title)
                .font(.caption)
        }
        .foregroundColor(isSupported ? .green : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSupported ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Model Row

struct ModelRow: View {
    let model: LLMModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(model.name)
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                if let pricing = model.pricing {
                    Text("$\(String(format: "%.2f", NSDecimalNumber(decimal: pricing.inputPricePerMillion).doubleValue))/$\(String(format: "%.2f", NSDecimalNumber(decimal: pricing.outputPricePerMillion).doubleValue))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Text(model.description)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Configuration View

struct LLMProviderConfigurationView: View {
    let store: StoreOf<LLMProviderConfigurationFeature>
    @FocusState private var focusedField: Field?
    @Dependency(\.navigationService) var navigationService
    @Dependency(\.textFieldService) var textFieldService

    enum Field: Hashable {
        case apiKey
        case organizationId
        case customEndpoint
        case deploymentName
    }

    var body: some View {
        WithViewStore(store, observe: { $0 }, content: { viewStore in
            Form {
                Section {
                    HStack {
                        Text("Provider")
                        Spacer()
                        Text(viewStore.provider.name)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Provider Information")
                }

                Section {
                    SecureField("API Key", text: viewStore.binding(
                        get: \.apiKey,
                        send: { .updateAPIKey($0) }
                    ))
                    .focused($focusedField, equals: .apiKey)
                    .textFieldConfiguration(
                        disableAutocapitalization: true,
                        supportsAutocapitalization: textFieldService.supportsAutocapitalization(),
                        supportsKeyboardTypes: textFieldService.supportsKeyboardTypes()
                    )
                    .disableAutocorrection(true)

                    if viewStore.provider.id == "openai" || viewStore.provider.id == "azure-openai" {
                        TextField("Organization ID (Optional)", text: viewStore.binding(
                            get: \.organizationId,
                            send: { .updateOrganizationId($0) }
                        ))
                        .focused($focusedField, equals: .organizationId)
                        .textFieldConfiguration(
                            disableAutocapitalization: true,
                            supportsAutocapitalization: textFieldService.supportsAutocapitalization(),
                            supportsKeyboardTypes: textFieldService.supportsKeyboardTypes()
                        )
                        .disableAutocorrection(true)
                    }

                    if viewStore.provider.id == "azure-openai" {
                        TextField("Azure Endpoint URL", text: viewStore.binding(
                            get: \.customEndpoint,
                            send: { .updateCustomEndpoint($0) }
                        ))
                        .focused($focusedField, equals: .customEndpoint)
                        .textFieldConfiguration(
                            disableAutocapitalization: true,
                            keyboardType: .url,
                            supportsAutocapitalization: textFieldService.supportsAutocapitalization(),
                            supportsKeyboardTypes: textFieldService.supportsKeyboardTypes()
                        )
                        .disableAutocorrection(true)

                        TextField("Deployment Name", text: viewStore.binding(
                            get: \.deploymentName,
                            send: { .updateDeploymentName($0) }
                        ))
                        .focused($focusedField, equals: .deploymentName)
                        .textFieldConfiguration(
                            disableAutocapitalization: true,
                            supportsAutocapitalization: textFieldService.supportsAutocapitalization(),
                            supportsKeyboardTypes: textFieldService.supportsKeyboardTypes()
                        )
                        .disableAutocorrection(true)
                    }

                    if viewStore.provider.id == "local" {
                        TextField("Server URL", text: viewStore.binding(
                            get: \.customEndpoint,
                            send: { .updateCustomEndpoint($0) }
                        ))
                        .focused($focusedField, equals: .customEndpoint)
                        .textFieldConfiguration(
                            disableAutocapitalization: true,
                            keyboardType: .url,
                            supportsAutocapitalization: textFieldService.supportsAutocapitalization(),
                            supportsKeyboardTypes: textFieldService.supportsKeyboardTypes()
                        )
                        .disableAutocorrection(true)
                    }
                } header: {
                    Text("Configuration")
                } footer: {
                    if viewStore.provider.id == "azure-openai" {
                        Text("Enter your Azure OpenAI endpoint URL and deployment name")
                    } else if viewStore.provider.id == "local" {
                        Text("Enter the URL of your local model server (e.g., http://localhost:8080)")
                    } else {
                        Text("Your API key will be stored securely in the system keychain")
                    }
                }

                if viewStore.isValidating {
                    Section {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Validating credentials...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Configure \(viewStore.provider.name)")
            .navigationConfiguration(
                displayMode: .inline,
                supportsNavigationBarDisplayMode: navigationService.supportsNavigationBarDisplayMode()
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewStore.send(.cancelTapped)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewStore.send(.saveTapped)
                    }
                    .disabled(!viewStore.canSave || viewStore.isValidating)
                }
            }
        })
    }
}
