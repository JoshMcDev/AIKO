import ComposableArchitecture
import Foundation
import SwiftUI

@Reducer
public struct SettingsFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        // App Settings
        public var appSettings = AppSettings()

        // API Configuration
        public var apiSettings = APISettings()
        public var showingAPIKey: Bool = false

        // Document Generation Settings
        public var documentSettings = DocumentSettings()

        // Notification Settings
        public var notificationSettings = NotificationSettings()

        // Data & Privacy
        public var dataPrivacySettings = DataPrivacySettings()

        // Advanced Settings
        public var advancedSettings = AdvancedSettings()

        // UI State
        public var selectedSection: SettingsSection = .general
        public var showingResetConfirmation: Bool = false
        public var showingRestoreConfirmation: Bool = false
        public var showingExportData: Bool = false
        public var showingImportData: Bool = false
        public var exportProgress: Double = 0
        public var backupProgress: Double = 0
        public var showingBackupProgress: Bool = false
        public var error: String?

        public init() {}
    }

    public enum SettingsSection: String, CaseIterable {
        case general = "General"
        case api = "API Configuration"
        case documents = "Document Generation"
        case notifications = "Notifications"
        case dataPrivacy = "Data & Privacy"
        case advanced = "Advanced"
        case performance = "Performance"

        var icon: String {
            switch self {
            case .general: "gearshape"
            case .api: "key.fill"
            case .documents: "doc.text"
            case .notifications: "bell"
            case .dataPrivacy: "lock.shield"
            case .advanced: "wrench.and.screwdriver"
            case .performance: "speedometer"
            }
        }
    }

    public struct AppSettings: Equatable {
        public var theme: AppTheme = .system
        public var accentColor: AccentColor = .blue
        public var fontSize: FontSize = .medium
        public var autoSaveEnabled: Bool = true
        public var autoSaveInterval: Int = 30 // seconds
        public var confirmBeforeDelete: Bool = true
        public var defaultFileFormat: FileFormat = .docx
        // Backup settings
        public var backupEnabled: Bool = false
        public var backupSchedule: BackupSchedule = .manual
        public var lastBackupDate: Date?
        public var nextScheduledBackup: Date?
        // Biometric authentication
        public var faceIDEnabled: Bool = false
    }

    public struct APISettings: Equatable {
        public var anthropicAPIKey: String = ""
        public var samGovAPIKey: String = ""
        public var apiEndpoint: String = "https://api.anthropic.com"
        public var maxRetries: Int = 3
        public var timeoutInterval: TimeInterval = 30
        public var useCustomEndpoint: Bool = false
        public var customEndpoint: String = ""
        // Multiple API keys
        public var apiKeys: [APIKeyEntry] = []
        public var selectedAPIKeyId: String = ""
    }

    public struct APIKeyEntry: Equatable, Identifiable, Sendable {
        public let id: String = UUID().uuidString
        public var name: String
        public var key: String
        public var isActive: Bool = false

        public init(name: String, key: String, isActive: Bool = false) {
            self.name = name
            self.key = key
            self.isActive = isActive
        }
    }

    public enum LLMModel: String, CaseIterable, Equatable {
        case claude3Opus = "Claude 3 Opus"
        case claude3Sonnet = "Claude 3 Sonnet"
        case claude3Haiku = "Claude 3 Haiku"
        case claude2_1 = "Claude 2.1"
        case claude2 = "Claude 2.0"
        case claudeInstant = "Claude Instant"

        var apiValue: String {
            switch self {
            case .claude3Opus: "claude-3-opus-20240229"
            case .claude3Sonnet: "claude-3-sonnet-20240229"
            case .claude3Haiku: "claude-3-haiku-20240307"
            case .claude2_1: "claude-2.1"
            case .claude2: "claude-2.0"
            case .claudeInstant: "claude-instant-1.2"
            }
        }
    }

    public struct DocumentSettings: Equatable {
        public var defaultTemplateSet: TemplateSet = .standard
        public var includeMetadata: Bool = true
        public var includeVersionHistory: Bool = true
        public var autoGenerateTableOfContents: Bool = true
        public var defaultDocumentLanguage: DocumentLanguage = .english
        public var pageNumbering: Bool = true
        public var headerFooterEnabled: Bool = true
        public var watermarkEnabled: Bool = false
        public var watermarkText: String = "DRAFT"
    }

    public struct NotificationSettings: Equatable {
        public var enableNotifications: Bool = true
        public var documentGenerationComplete: Bool = true
        public var acquisitionReminders: Bool = true
        public var updateAvailable: Bool = true
        public var weeklyUsageReport: Bool = false
        public var soundEnabled: Bool = true
        public var notificationSound: NotificationSound = .default
    }

    public struct DataPrivacySettings: Equatable {
        public var analyticsEnabled: Bool = false
        public var crashReportingEnabled: Bool = true
        public var dataRetentionDays: Int = 90
        public var autoDeleteOldAcquisitions: Bool = false
        public var encryptLocalData: Bool = true
        public var biometricLockEnabled: Bool = false
    }

    public struct AdvancedSettings: Equatable {
        public var debugModeEnabled: Bool = false
        public var showDetailedErrors: Bool = false
        public var enableBetaFeatures: Bool = false
        public var cacheSizeMB: Int = 500
        public var maxConcurrentGenerations: Int = 3
        public var customPromptPrefixEnabled: Bool = false
        public var customPromptPrefix: String = ""
        // New advanced settings
        public var outputFormat: OutputFormat = .rtf
        public var llmTemperature: Double = 0.3
        public var outputLength: Int = 4000 // tokens
    }

    public enum AppTheme: String, CaseIterable {
        case light = "Light"
        case dark = "Dark"
        case system = "System"
    }

    public enum AccentColor: String, CaseIterable {
        case blue = "Blue"
        case purple = "Purple"
        case green = "Green"
        case orange = "Orange"
        case red = "Red"
        case pink = "Pink"
        case indigo = "Indigo"

        var color: Color {
            switch self {
            case .blue: .blue
            case .purple: .purple
            case .green: .green
            case .orange: .orange
            case .red: .red
            case .pink: .pink
            case .indigo: .indigo
            }
        }
    }

    public enum FontSize: String, CaseIterable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"
        case extraLarge = "Extra Large"

        var scaleFactor: CGFloat {
            switch self {
            case .small: 0.9
            case .medium: 1.0
            case .large: 1.1
            case .extraLarge: 1.2
            }
        }
    }

    public enum FileFormat: String, CaseIterable {
        case docx = "Word (.docx)"
        case pdf = "PDF"
        case markdown = "Markdown (.md)"
        case plainText = "Plain Text (.txt)"
        case rtf = "Rich Text (.rtf)"
    }

    public enum TemplateSet: String, CaseIterable {
        case standard = "Standard FAR"
        case simplified = "Simplified"
        case comprehensive = "Comprehensive"
        case custom = "Custom"
    }

    public enum DocumentLanguage: String, CaseIterable {
        case english = "English"
        case spanish = "Spanish"
        case french = "French"
        case german = "German"
    }

    public enum NotificationSound: String, CaseIterable {
        case `default` = "Default"
        case chime = "Chime"
        case ping = "Ping"
        case success = "Success"
        case none = "None"
    }

    public enum BackupSchedule: String, CaseIterable {
        case manual = "Manual"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
    }

    public enum OutputFormat: String, CaseIterable {
        case rtf = "Rich Text (RTF)"
        case markdown = "Markdown"
        case json = "JSON"
        case pdf = "PDF"
        case docx = "Word (DOCX)"
        case plainText = "Plain Text"
    }

    public enum Action {
        // Section Navigation
        case selectSection(SettingsSection)

        // App Settings
        case updateTheme(AppTheme)
        case updateAccentColor(AccentColor)
        case updateFontSize(FontSize)
        case toggleAutoSave(Bool)
        case updateAutoSaveInterval(Int)
        case toggleConfirmDelete(Bool)
        case updateDefaultFileFormat(FileFormat)
        // Backup settings
        case toggleBackup(Bool)
        case updateBackupSchedule(BackupSchedule)
        case backupNow
        case backupCompleted(Date)
        case scheduleNextBackup
        // Restore
        case restoreDefaults
        case confirmRestore(Bool)
        // Face ID
        case toggleFaceID(Bool)

        // API Settings
        case updateAPIKey(String)
        case updateSAMGovAPIKey(String)
        case toggleShowAPIKey(Bool)
        case validateAPIKey
        case apiKeyValidated(Bool)
        case updateAPIEndpoint(String)
        case updateMaxRetries(Int)
        case updateTimeoutInterval(TimeInterval)
        case toggleCustomEndpoint(Bool)
        case updateCustomEndpoint(String)
        // Multiple API keys
        case addAPIKey(name: String, key: String)
        case removeAPIKey(String) // ID
        case selectAPIKey(String) // ID
        case updateSelectedModel // Deprecated - kept for compatibility

        // Document Settings
        case updateDefaultTemplateSet(TemplateSet)
        case toggleIncludeMetadata(Bool)
        case toggleIncludeVersionHistory(Bool)
        case toggleAutoGenerateTOC(Bool)
        case updateDocumentLanguage(DocumentLanguage)
        case togglePageNumbering(Bool)
        case toggleHeaderFooter(Bool)
        case toggleWatermark(Bool)
        case updateWatermarkText(String)

        // Notification Settings
        case toggleNotifications(Bool)
        case toggleDocumentComplete(Bool)
        case toggleAcquisitionReminders(Bool)
        case toggleUpdateAvailable(Bool)
        case toggleWeeklyReport(Bool)
        case toggleSound(Bool)
        case updateNotificationSound(NotificationSound)

        // Data & Privacy
        case toggleAnalytics(Bool)
        case toggleCrashReporting(Bool)
        case updateDataRetention(Int)
        case toggleAutoDelete(Bool)
        case toggleEncryption(Bool)
        case toggleBiometric(Bool)

        // Advanced Settings
        case toggleDebugMode(Bool)
        case toggleDetailedErrors(Bool)
        case toggleBetaFeatures(Bool)
        case updateCacheSize(Int)
        case updateMaxConcurrentGenerations(Int)
        case toggleCustomPromptPrefix(Bool)
        case updateCustomPromptPrefix(String)
        case updateOutputFormat(OutputFormat)
        case updateLLMTemperature(Double)
        case updateOutputLength(Int)

        // Actions
        case resetSettings
        case confirmReset(Bool)
        case exportData
        case importData
        case dataExported(URL)
        case dataImported
        case updateExportProgress(Double)
        case clearCache
        case cacheCleared
        case error(String)
        case clearError
    }

    @Dependency(\.settingsManager) var settingsManager
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .selectSection(section):
                state.selectedSection = section
                return .none

            // App Settings
            case let .updateTheme(theme):
                state.appSettings.theme = theme
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .updateAccentColor(color):
                state.appSettings.accentColor = color
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .updateFontSize(size):
                state.appSettings.fontSize = size
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleAutoSave(enabled):
                state.appSettings.autoSaveEnabled = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .updateAutoSaveInterval(interval):
                state.appSettings.autoSaveInterval = interval
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleConfirmDelete(enabled):
                state.appSettings.confirmBeforeDelete = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .updateDefaultFileFormat(format):
                state.appSettings.defaultFileFormat = format
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleBackup(enabled):
                state.appSettings.backupEnabled = enabled
                if enabled {
                    return .run { send in
                        try? await settingsManager.saveSettings()
                        await send(.scheduleNextBackup)
                    }
                } else {
                    state.appSettings.nextScheduledBackup = nil
                    return .run { _ in
                        try? await settingsManager.saveSettings()
                    }
                }

            case let .updateBackupSchedule(schedule):
                state.appSettings.backupSchedule = schedule
                return .run { send in
                    try? await settingsManager.saveSettings()
                    await send(.scheduleNextBackup)
                }

            case .backupNow:
                state.showingBackupProgress = true
                return .run { send in
                    do {
                        _ = try await settingsManager.performBackup { progress in
                            Task { await send(.updateExportProgress(progress)) }
                        }
                        await send(.backupCompleted(Date()))
                    } catch {
                        await send(.error("Backup failed: \(error.localizedDescription)"))
                    }
                }

            case let .backupCompleted(date):
                state.appSettings.lastBackupDate = date
                state.showingBackupProgress = false
                state.backupProgress = 0
                return .run { send in
                    try? await settingsManager.saveSettings()
                    await send(.scheduleNextBackup)
                }

            case .scheduleNextBackup:
                guard state.appSettings.backupEnabled else { return .none }

                let now = Date()
                let nextBackup: Date

                switch state.appSettings.backupSchedule {
                case .manual:
                    state.appSettings.nextScheduledBackup = nil
                    return .none
                case .daily:
                    nextBackup = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86400)
                case .weekly:
                    nextBackup = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: now) ?? now.addingTimeInterval(604800)
                case .monthly:
                    nextBackup = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now.addingTimeInterval(2592000)
                }

                state.appSettings.nextScheduledBackup = nextBackup
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case .restoreDefaults:
                state.showingRestoreConfirmation = true
                return .none

            case let .confirmRestore(confirmed):
                state.showingRestoreConfirmation = false
                if confirmed {
                    return .run { send in
                        try? await settingsManager.restoreDefaults()
                        // Reset UI to default state
                        let defaultState = State()
                        await send(.updateTheme(defaultState.appSettings.theme))
                    }
                }
                return .none

            case let .toggleFaceID(enabled):
                state.appSettings.faceIDEnabled = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            // API Settings
            case let .updateAPIKey(key):
                state.apiSettings.anthropicAPIKey = key
                return .run { _ in
                    try? await settingsManager.saveAPIKey(key)
                }

            case let .updateSAMGovAPIKey(key):
                state.apiSettings.samGovAPIKey = key
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleShowAPIKey(show):
                state.showingAPIKey = show
                return .none

            case .validateAPIKey:
                return .run { [key = state.apiSettings.anthropicAPIKey] send in
                    let isValid = await settingsManager.validateAPIKey(key)
                    await send(.apiKeyValidated(isValid))
                }

            case let .apiKeyValidated(isValid):
                if !isValid {
                    state.error = "Invalid API key. Please check your key and try again."
                }
                return .none

            case let .updateAPIEndpoint(endpoint):
                state.apiSettings.apiEndpoint = endpoint
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .updateMaxRetries(retries):
                state.apiSettings.maxRetries = retries
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .updateTimeoutInterval(interval):
                state.apiSettings.timeoutInterval = interval
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleCustomEndpoint(enabled):
                state.apiSettings.useCustomEndpoint = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .updateCustomEndpoint(endpoint):
                state.apiSettings.customEndpoint = endpoint
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .addAPIKey(name, key):
                let newKey = APIKeyEntry(name: name, key: key, isActive: false)
                state.apiSettings.apiKeys.append(newKey)
                // If it's the first key, make it active
                if state.apiSettings.apiKeys.count == 1 {
                    state.apiSettings.selectedAPIKeyId = newKey.id
                    state.apiSettings.apiKeys[0].isActive = true
                }
                return .run { [keyToSave = newKey] _ in
                    try? await settingsManager.saveAPIKey(keyToSave.key)
                    try? await settingsManager.saveSettings()
                }

            case let .removeAPIKey(id):
                state.apiSettings.apiKeys.removeAll { $0.id == id }
                // If we removed the active key, select the first one
                if state.apiSettings.selectedAPIKeyId == id, !state.apiSettings.apiKeys.isEmpty {
                    state.apiSettings.selectedAPIKeyId = state.apiSettings.apiKeys[0].id
                    state.apiSettings.apiKeys[0].isActive = true
                }
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .selectAPIKey(id):
                // Deactivate all keys
                for index in state.apiSettings.apiKeys.indices {
                    state.apiSettings.apiKeys[index].isActive = false
                }
                // Activate the selected key
                if let index = state.apiSettings.apiKeys.firstIndex(where: { $0.id == id }) {
                    state.apiSettings.apiKeys[index].isActive = true
                    state.apiSettings.selectedAPIKeyId = id
                }
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case .updateSelectedModel:
                // Model selection has been removed - always uses Claude 4 Sonnet
                return .none

            // Document Settings
            case let .updateDefaultTemplateSet(templateSet):
                state.documentSettings.defaultTemplateSet = templateSet
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleIncludeMetadata(enabled):
                state.documentSettings.includeMetadata = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleIncludeVersionHistory(enabled):
                state.documentSettings.includeVersionHistory = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleAutoGenerateTOC(enabled):
                state.documentSettings.autoGenerateTableOfContents = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .updateDocumentLanguage(language):
                state.documentSettings.defaultDocumentLanguage = language
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .togglePageNumbering(enabled):
                state.documentSettings.pageNumbering = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleHeaderFooter(enabled):
                state.documentSettings.headerFooterEnabled = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleWatermark(enabled):
                state.documentSettings.watermarkEnabled = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .updateWatermarkText(text):
                state.documentSettings.watermarkText = text
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            // Notification Settings
            case let .toggleNotifications(enabled):
                state.notificationSettings.enableNotifications = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleDocumentComplete(enabled):
                state.notificationSettings.documentGenerationComplete = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleAcquisitionReminders(enabled):
                state.notificationSettings.acquisitionReminders = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleUpdateAvailable(enabled):
                state.notificationSettings.updateAvailable = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleWeeklyReport(enabled):
                state.notificationSettings.weeklyUsageReport = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleSound(enabled):
                state.notificationSettings.soundEnabled = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .updateNotificationSound(sound):
                state.notificationSettings.notificationSound = sound
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            // Data & Privacy
            case let .toggleAnalytics(enabled):
                state.dataPrivacySettings.analyticsEnabled = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleCrashReporting(enabled):
                state.dataPrivacySettings.crashReportingEnabled = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .updateDataRetention(days):
                state.dataPrivacySettings.dataRetentionDays = days
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleAutoDelete(enabled):
                state.dataPrivacySettings.autoDeleteOldAcquisitions = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleEncryption(enabled):
                state.dataPrivacySettings.encryptLocalData = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleBiometric(enabled):
                state.dataPrivacySettings.biometricLockEnabled = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            // Advanced Settings
            case let .toggleDebugMode(enabled):
                state.advancedSettings.debugModeEnabled = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleDetailedErrors(enabled):
                state.advancedSettings.showDetailedErrors = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleBetaFeatures(enabled):
                state.advancedSettings.enableBetaFeatures = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .updateCacheSize(size):
                state.advancedSettings.cacheSizeMB = size
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .updateMaxConcurrentGenerations(max):
                state.advancedSettings.maxConcurrentGenerations = max
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .toggleCustomPromptPrefix(enabled):
                state.advancedSettings.customPromptPrefixEnabled = enabled
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .updateCustomPromptPrefix(prefix):
                state.advancedSettings.customPromptPrefix = prefix
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .updateOutputFormat(format):
                state.advancedSettings.outputFormat = format
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .updateLLMTemperature(temperature):
                state.advancedSettings.llmTemperature = max(0, min(1, temperature))
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            case let .updateOutputLength(length):
                state.advancedSettings.outputLength = max(100, min(20000, length))
                return .run { _ in
                    try? await settingsManager.saveSettings()
                }

            // Actions
            case .resetSettings:
                state.showingResetConfirmation = true
                return .none

            case let .confirmReset(confirmed):
                state.showingResetConfirmation = false
                if confirmed {
                    return .run { send in
                        try? await settingsManager.resetToDefaults()
                        // Reload default settings
                        let defaultState = State()
                        await send(.updateTheme(defaultState.appSettings.theme))
                    }
                }
                return .none

            case .exportData:
                state.showingExportData = true
                return .run { send in
                    do {
                        let url = try await settingsManager.exportData { progress in
                            Task { await send(.updateExportProgress(progress)) }
                        }
                        await send(.dataExported(url))
                    } catch {
                        await send(.error("Failed to export data: \(error.localizedDescription)"))
                    }
                }

            case .importData:
                state.showingImportData = true
                return .none

            case .dataExported:
                state.showingExportData = false
                state.exportProgress = 0
                // Share the exported file
                return .none

            case .dataImported:
                state.showingImportData = false
                return .none

            case let .updateExportProgress(progress):
                state.exportProgress = progress
                return .none

            case .clearCache:
                return .run { send in
                    try? await settingsManager.clearCache()
                    await send(.cacheCleared)
                }

            case .cacheCleared:
                // Show success message
                return .none

            case let .error(message):
                state.error = message
                return .none

            case .clearError:
                state.error = nil
                return .none
            }
        }
    }
}
