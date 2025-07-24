import ComposableArchitecture
import SwiftUI

struct SettingsView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }, content: { viewStore in
            Group {
                #if os(iOS)
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        // iPhone: Use NavigationView with single column
                        SwiftUI.NavigationView {
                            List {
                                ForEach(SettingsFeature.SettingsSection.allCases, id: \.self) { section in
                                    NavigationLink(destination: SettingsDetailView(store: store, section: section)) {
                                        HStack {
                                            Image(systemName: section.icon)
                                                .frame(width: 20)
                                                .foregroundColor(.accentColor)
                                            Text(section.rawValue)
                                        }
                                    }
                                }
                            }
                            .navigationTitle("Settings")
                            .listStyle(InsetGroupedListStyle())
                        }
                        .navigationViewStyle(StackNavigationViewStyle())
                    } else {
                        // iPad: Use split view
                        SwiftUI.NavigationView {
                            SettingsSidebar(store: store)
                            SettingsDetailView(store: store, section: viewStore.selectedSection)
                        }
                        .navigationViewStyle(DoubleColumnNavigationViewStyle())
                    }
                #else
                    // macOS: Use split view
                    SwiftUI.NavigationView {
                        SettingsSidebar(store: store)
                        SettingsDetailView(store: store, section: viewStore.selectedSection)
                    }
                    .navigationViewStyle(DoubleColumnNavigationViewStyle())
                #endif
            }
            .sheet(isPresented: viewStore.binding(
                get: \.showingExportData,
                send: { _ in .exportData }
            )) {
                ExportProgressView(progress: viewStore.exportProgress)
            }
            .alert(
                "Reset Settings",
                isPresented: viewStore.binding(
                    get: \.showingResetConfirmation,
                    send: { _ in .confirmReset(false) }
                )
            ) {
                Button("Cancel", role: .cancel) {
                    viewStore.send(.confirmReset(false))
                }
                Button("Reset", role: .destructive) {
                    viewStore.send(.confirmReset(true))
                }
            } message: {
                Text("Are you sure you want to reset all settings to their default values? This action cannot be undone.")
            }
            .alert(
                "Error",
                isPresented: .init(
                    get: { viewStore.error != nil },
                    set: { _ in viewStore.send(.clearError) }
                )
            ) {
                Button("OK") {
                    viewStore.send(.clearError)
                }
            } message: {
                if let error = viewStore.error {
                    Text(error)
                }
            }
        })
    }
}

struct SettingsSidebar: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }, content: { viewStore in
            List {
                ForEach(SettingsFeature.SettingsSection.allCases, id: \.self) { section in
                    Button(action: {
                        viewStore.send(.selectSection(section))
                    }, label: {
                        HStack {
                            Image(systemName: section.icon)
                                .frame(width: 20)
                            Text(section.rawValue)
                            Spacer()
                            if viewStore.selectedSection == section {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    })
                    .buttonStyle(PlainButtonStyle())
                    .padding(.vertical, 4)
                    .background(
                        viewStore.selectedSection == section ?
                            Color.accentColor.opacity(0.1) : Color.clear
                    )
                    .cornerRadius(6)
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Settings")
            .frame(minWidth: 200)
        })
    }
}

struct SettingsDetailView: View {
    let store: StoreOf<SettingsFeature>
    let section: SettingsFeature.SettingsSection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.extraLarge) {
                switch section {
                case .general:
                    GeneralSettingsView(store: store)
                case .api:
                    APISettingsView(store: store)
                case .documents:
                    DocumentSettingsView(store: store)
                case .notifications:
                    NotificationSettingsView(store: store)
                case .dataPrivacy:
                    DataPrivacySettingsView(store: store)
                case .advanced:
                    AdvancedSettingsView(store: store)
                case .performance:
                    PerformanceMonitorView()
                }
            }
            .padding()
        }
        .navigationTitle(section.rawValue)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }, content: { viewStore in
            VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                SettingsSection(title: "Appearance") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        // Theme
                        HStack {
                            Text("Theme")
                            Spacer()
                            Picker("Theme", selection: viewStore.binding(
                                get: { $0.appSettings.theme },
                                send: { .updateTheme($0) }
                            )) {
                                ForEach(SettingsFeature.AppTheme.allCases, id: \.self) { theme in
                                    Text(theme.rawValue).tag(theme)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 250)
                        }

                        // Accent Color
                        HStack {
                            Text("Accent Color")
                            Spacer()
                            HStack(spacing: Theme.Spacing.small) {
                                ForEach(SettingsFeature.AccentColor.allCases, id: \.self) { color in
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    viewStore.appSettings.accentColor == color ?
                                                        Color.primary : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                        .onTapGesture {
                                            viewStore.send(.updateAccentColor(color))
                                        }
                                }
                            }
                        }

                        // Font Size
                        HStack {
                            Text("Font Size")
                            Spacer()
                            Picker("Font Size", selection: viewStore.binding(
                                get: { $0.appSettings.fontSize },
                                send: { .updateFontSize($0) }
                            )) {
                                ForEach(SettingsFeature.FontSize.allCases, id: \.self) { size in
                                    Text(size.rawValue).tag(size)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 150)
                        }
                    }
                }

                SettingsSection(title: "Security") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        HStack {
                            Image(systemName: "faceid")
                                .font(.title3)
                                .foregroundColor(Theme.Colors.aikoAccent)
                            Toggle("Enable Face ID", isOn: viewStore.binding(
                                get: { $0.appSettings.faceIDEnabled },
                                send: { .toggleFaceID($0) }
                            ))
                        }

                        Text("Use Face ID to quickly and securely access AIKO")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                SettingsSection(title: "Behavior") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        Toggle("Enable Auto-save", isOn: viewStore.binding(
                            get: { $0.appSettings.autoSaveEnabled },
                            send: { .toggleAutoSave($0) }
                        ))

                        if viewStore.appSettings.autoSaveEnabled {
                            HStack {
                                Text("Auto-save interval")
                                Spacer()
                                Stepper(
                                    "\(viewStore.appSettings.autoSaveInterval) seconds",
                                    value: viewStore.binding(
                                        get: { $0.appSettings.autoSaveInterval },
                                        send: { .updateAutoSaveInterval($0) }
                                    ),
                                    in: 10 ... 300,
                                    step: 10
                                )
                                .frame(width: 200)
                            }
                        }

                        Toggle("Confirm before deleting", isOn: viewStore.binding(
                            get: { $0.appSettings.confirmBeforeDelete },
                            send: { .toggleConfirmDelete($0) }
                        ))
                    }
                }

                SettingsSection(title: "File Handling") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        HStack {
                            Text("Default file format")
                            Spacer()
                            Picker("File Format", selection: viewStore.binding(
                                get: { $0.appSettings.defaultFileFormat },
                                send: { .updateDefaultFileFormat($0) }
                            )) {
                                ForEach(SettingsFeature.FileFormat.allCases, id: \.self) { format in
                                    Text(format.rawValue).tag(format)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 200)
                        }
                    }
                }

                SettingsSection(title: "Backup & Restore") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        // Backup settings
                        Toggle("Enable automatic backup", isOn: viewStore.binding(
                            get: { $0.appSettings.backupEnabled },
                            send: { .toggleBackup($0) }
                        ))

                        if viewStore.appSettings.backupEnabled {
                            HStack {
                                Text("Backup schedule")
                                Spacer()
                                Picker("Schedule", selection: viewStore.binding(
                                    get: { $0.appSettings.backupSchedule },
                                    send: { .updateBackupSchedule($0) }
                                )) {
                                    ForEach(SettingsFeature.BackupSchedule.allCases, id: \.self) { schedule in
                                        Text(schedule.rawValue).tag(schedule)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(width: 150)
                            }

                            if let nextBackup = viewStore.appSettings.nextScheduledBackup {
                                HStack {
                                    Text("Next backup")
                                    Spacer()
                                    Text(nextBackup, style: .relative)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        if let lastBackup = viewStore.appSettings.lastBackupDate {
                            HStack {
                                Text("Last backup")
                                Spacer()
                                Text(lastBackup, style: .relative)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Button("Backup Now") {
                                viewStore.send(.backupNow)
                            }
                            .buttonStyle(.borderedProminent)

                            Spacer()
                        }

                        Divider()
                            .padding(.vertical, Theme.Spacing.small)

                        // Restore button
                        HStack {
                            Button(role: .destructive) {
                                viewStore.send(.restoreDefaults)
                            } label: {
                                Label("Restore to Factory Settings", systemImage: "arrow.counterclockwise")
                            }

                            Spacer()
                        }

                        Text("This will reset the app to its initial state and clear all data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(isPresented: viewStore.binding(
                get: \.showingBackupProgress,
                send: { _ in .backupNow }
            )) {
                BackupProgressView(progress: viewStore.backupProgress)
            }
            .alert(
                "Restore to Factory Settings",
                isPresented: viewStore.binding(
                    get: \.showingRestoreConfirmation,
                    send: { _ in .confirmRestore(false) }
                )
            ) {
                Button("Cancel", role: .cancel) {
                    viewStore.send(.confirmRestore(false))
                }
                Button("Restore", role: .destructive) {
                    viewStore.send(.confirmRestore(true))
                }
            } message: {
                Text("Are you sure you want to restore the app to factory settings? This will:\n\n• Clear all settings\n• Remove all saved data\n• Delete your API key\n• Clear all caches\n\nThis action cannot be undone.")
            }
        })
    }
}

// MARK: - API Settings

struct APISettingsView: View {
    let store: StoreOf<SettingsFeature>
    @State private var apiKeyInput: String = ""
    @State private var apiKeyName: String = ""
    @State private var showingAddKey = false

    var body: some View {
        WithViewStore(store, observe: { $0 }, content: { viewStore in
            VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                // Model Information
                SettingsSection(title: "AI Model") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundColor(Theme.Colors.aikoAccent)
                            Text("Active Model")
                                .font(.headline)
                            Spacer()
                            Text("Claude 4 Sonnet")
                                .font(.headline)
                                .foregroundColor(.blue)
        }

                        Text("The latest Claude model is used for all document generation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // SAM.gov API Key
                SettingsSection(title: "SAM.gov API") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        HStack {
                            Text("SAM.gov API Key")
                            Spacer()
                            SecureField("", text: viewStore.binding(
                                get: { $0.apiSettings.samGovAPIKey },
                                send: { .updateSAMGovAPIKey($0) }
                            ), prompt: Text("...").foregroundColor(.gray))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 300)
                        }

                        Text("Required for entity verification and CAGE code lookups")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let url = URL(string: "https://open.gsa.gov/api/entity-api/") {
                            Link("Get a free API key at SAM.gov", destination: url)
                                .font(.caption)
                        }
                    }
                }

                // API Keys Management
                SettingsSection(title: "Anthropic API Keys") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        // Header with Add button
                        HStack {
                            Text("Manage Anthropic API Keys")
                                .font(.headline)
                            Spacer()
                            Button(action: { showingAddKey = true }, label: {
                                Label("Add Key", systemImage: "plus.circle.fill")
                                    .font(.subheadline)
                            })
                            .buttonStyle(.borderedProminent)
                        }

                        // List of API keys
                        if viewStore.apiSettings.apiKeys.isEmpty {
                            HStack {
                                Image(systemName: "key.slash")
                                    .foregroundColor(.secondary)
                                Text("No API keys configured")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else {
                            ForEach(viewStore.apiSettings.apiKeys) { key in
                                APIKeyRow(
                                    key: key,
                                    isSelected: key.id == viewStore.apiSettings.selectedAPIKeyId,
                                    onSelect: { viewStore.send(.selectAPIKey(key.id)) },
                                    onDelete: { viewStore.send(.removeAPIKey(key.id)) }
                                )
                            }
                        }

                        Text("API keys are stored securely in the system keychain")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showingAddKey) {
                AddAPIKeyView(
                    keyName: $apiKeyName,
                    keyValue: $apiKeyInput,
                    showingAPIKey: viewStore.showingAPIKey,
                    onToggleShow: { viewStore.send(.toggleShowAPIKey(!viewStore.showingAPIKey)) },
                    onCancel: {
                        showingAddKey = false
                        apiKeyName = ""
                        apiKeyInput = ""
                    },
                    onSave: {
                        viewStore.send(.addAPIKey(name: apiKeyName, key: apiKeyInput))
                        showingAddKey = false
                        apiKeyName = ""
                        apiKeyInput = ""
                    }
                )
            }
        })
    }
}

// MARK: - API Key Row

struct APIKeyRow: View {
    let key: SettingsFeature.APIKeyEntry
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Button(action: onSelect) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .green : .secondary)

                    VStack(alignment: .leading) {
                        Text(key.name)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("sk-ant-****\(String(key.key.suffix(4)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if isSelected {
                        Label("Active", systemImage: "dot.radiowaves.left.and.right")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding(.vertical, Theme.Spacing.extraSmall)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, Theme.Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                .fill(isSelected ? Theme.Colors.aikoAccent.opacity(0.1) : Color.clear)
        )
    }
}

// MARK: - Add API Key View

struct AddAPIKeyView: View {
    @Binding var keyName: String
    @Binding var keyValue: String
    let showingAPIKey: Bool
    let onToggleShow: () -> Void
    let onCancel: () -> Void
    let onSave: () -> Void

    var canSave: Bool {
        !keyName.isEmpty && !keyValue.isEmpty && keyValue.hasPrefix("sk-ant-")
    }

    var body: some View {
        SwiftUI.NavigationView {
            VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                Text("Add a new API key")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)

                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("Key Name")
                        .font(.headline)
                    TextField("", text: $keyName, prompt: Text("...").foregroundColor(.gray))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("API Key")
                        .font(.headline)
                    HStack {
                        Group {
                            if showingAPIKey {
                                TextField("", text: $keyValue, prompt: Text("...").foregroundColor(.gray))
                            } else {
                                SecureField("", text: $keyValue, prompt: Text("...").foregroundColor(.gray))
                            }
                        }
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                        Button(action: onToggleShow) {
                            Image(systemName: showingAPIKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }

                    if !keyValue.isEmpty, !keyValue.hasPrefix("sk-ant-") {
                        Text("API key must start with 'sk-ant-'")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Spacer()
            }
            .padding()
            #if os(iOS)
                .navigationBarTitle("Add API Key", displayMode: .inline)
                .navigationBarItems(
                    leading: Button("Cancel", action: onCancel),
                    trailing: Button("Save", action: onSave)
                        .disabled(!canSave)
                )
            #else
                .navigationTitle("Add API Key")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel", action: onCancel)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save", action: onSave)
                                .disabled(!canSave)
                        }
                    }
            #endif
        }
    }
}

// MARK: - Document Settings

struct DocumentSettingsView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }, content: { viewStore in
            VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                SettingsSection(title: "Template Settings") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        HStack {
                            Text("Default template set")
                            Spacer()
                            Picker("Template Set", selection: viewStore.binding(
                                get: { $0.documentSettings.defaultTemplateSet },
                                send: { .updateDefaultTemplateSet($0) }
                            )) {
                                ForEach(SettingsFeature.TemplateSet.allCases, id: \.self) { templateSet in
                                    Text(templateSet.rawValue).tag(templateSet)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 200)
                        }
                    }
                }

                SettingsSection(title: "Document Features") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        Toggle("Include metadata", isOn: viewStore.binding(
                            get: { $0.documentSettings.includeMetadata },
                            send: { .toggleIncludeMetadata($0) }
                        ))

                        Toggle("Include version history", isOn: viewStore.binding(
                            get: { $0.documentSettings.includeVersionHistory },
                            send: { .toggleIncludeVersionHistory($0) }
                        ))

                        Toggle("Auto-generate table of contents", isOn: viewStore.binding(
                            get: { $0.documentSettings.autoGenerateTableOfContents },
                            send: { .toggleAutoGenerateTOC($0) }
                        ))
                    }
                }
            }
        })
    }
}

// MARK: - Notification Settings

struct NotificationSettingsView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }, content: { viewStore in
            VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                SettingsSection(title: "Notification Preferences") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        Toggle("Enable notifications", isOn: viewStore.binding(
                            get: { $0.notificationSettings.enableNotifications },
                            send: { .toggleNotifications($0) }
                        ))
                    }
                }
            }
        })
    }
}

// MARK: - Data & Privacy Settings

struct DataPrivacySettingsView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }, content: { viewStore in
            VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                SettingsSection(title: "Privacy") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        Toggle("Share analytics data", isOn: viewStore.binding(
                            get: { $0.dataPrivacySettings.analyticsEnabled },
                            send: { .toggleAnalytics($0) }
                        ))

                        Text("Help improve AIKO by sharing anonymous usage data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                SettingsSection(title: "Data Management") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        HStack {
                            Button("Export All Data") {
                                viewStore.send(.exportData)
                            }

                            Button("Import Data") {
                                viewStore.send(.importData)
                            }
                        }
                    }
                }
            }
        })
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }, content: { viewStore in
            VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                SettingsSection(title: "Developer Options") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        Toggle("Enable debug mode", isOn: viewStore.binding(
                            get: { $0.advancedSettings.debugModeEnabled },
                            send: { .toggleDebugMode($0) }
                        ))

                        Toggle("Show detailed error messages", isOn: viewStore.binding(
                            get: { $0.advancedSettings.showDetailedErrors },
                            send: { .toggleDetailedErrors($0) }
                        ))
                    }
                }

                SettingsSection(title: "Performance") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        Button("Clear Cache") {
                            viewStore.send(.clearCache)
                        }
                    }
                }

                SettingsSection(title: "Output Settings") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        // Output Format
                        HStack {
                            Text("Output format")
                            Spacer()
                            Picker("Format", selection: viewStore.binding(
                                get: { $0.advancedSettings.outputFormat },
                                send: { .updateOutputFormat($0) }
                            )) {
                                ForEach(SettingsFeature.OutputFormat.allCases, id: \.self) { format in
                                    Text(format.rawValue).tag(format)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 200)
                        }

                        Text("Default format for generated documents")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                SettingsSection(title: "AI Model Settings") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        // Temperature
                        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                            HStack {
                                Text("Model Temperature")
                                Spacer()
                                Text(String(format: "%.1f", viewStore.advancedSettings.llmTemperature))
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }

                            Slider(
                                value: viewStore.binding(
                                    get: { $0.advancedSettings.llmTemperature },
                                    send: { .updateLLMTemperature($0) }
                                ),
                                in: 0 ... 1,
                                step: 0.1
                            )

                            Text("Controls creativity vs consistency (0 = focused, 1 = creative)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        // Output Length
                        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                            HStack {
                                Text("Output length")
                                Spacer()
                                Text("\(viewStore.advancedSettings.outputLength) tokens")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }

                            Stepper(
                                "Output length",
                                value: viewStore.binding(
                                    get: { $0.advancedSettings.outputLength },
                                    send: { .updateOutputLength($0) }
                                ),
                                in: 100 ... 20000,
                                step: 500
                            )
                            .labelsHidden()

                            Text("Maximum tokens for document generation (100-20,000)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Divider()
                    .padding(.vertical)

                // Reset button
                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        viewStore.send(.resetSettings)
                    } label: {
                        Label("Reset All Settings", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        })
    }
}

// MARK: - Settings Section Component

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            content
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

// MARK: - Export Progress View

struct ExportProgressView: View {
    let progress: Double

    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())

            Text("Exporting data... \(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 300)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Backup Progress View

struct BackupProgressView: View {
    let progress: Double

    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())

            Text("Creating backup... \(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 300)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}
