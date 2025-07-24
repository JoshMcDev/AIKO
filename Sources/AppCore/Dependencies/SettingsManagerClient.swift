import ComposableArchitecture
import Foundation

/// TCA-compatible dependency client for settings management
@DependencyClient
public struct SettingsManagerClient: Sendable {
    public var loadSettings: @Sendable () async throws -> SettingsData
    public var saveSettings: @Sendable (SettingsData) async throws -> Void
    public var resetToDefaults: @Sendable () async throws -> Void
    public var saveAPIKey: @Sendable (String) async throws -> Void
    public var loadAPIKey: @Sendable () async throws -> String?
    public var validateAPIKey: @Sendable (String) async -> Bool = { _ in false }
    public var exportData: @Sendable (@escaping (Double) -> Void) async throws -> URL
    public var importData: @Sendable (URL) async throws -> Void
    public var clearCache: @Sendable () async throws -> Void
    public var performBackup: @Sendable (@escaping (Double) -> Void) async throws -> URL
    public var restoreBackup: @Sendable (URL, @escaping (Double) -> Void) async throws -> Void
}

extension SettingsManagerClient: TestDependencyKey {
    public static let testValue = Self()
    public static let previewValue = Self(
        loadSettings: { SettingsData() },
        saveSettings: { _ in },
        resetToDefaults: {},
        saveAPIKey: { _ in },
        loadAPIKey: { "preview-key" },
        validateAPIKey: { _ in true },
        exportData: { _ in URL(fileURLWithPath: "/tmp/test.json") },
        importData: { _ in },
        clearCache: {},
        performBackup: { _ in URL(fileURLWithPath: "/tmp/backup.json") },
        restoreBackup: { _, _ in }
    )
}

public extension DependencyValues {
    var settingsManagerClient: SettingsManagerClient {
        get { self[SettingsManagerClient.self] }
        set { self[SettingsManagerClient.self] = newValue }
    }
}
