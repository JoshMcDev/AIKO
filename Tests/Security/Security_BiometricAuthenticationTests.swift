@testable import AppCore
import ComposableArchitecture
import XCTest

final class BiometricAuthenticationTests: XCTestCase {
    func testFaceIDAuthentication() async throws {
        let store = TestStore(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        ) {
            $0.biometricAuthenticationService = .testValue
            $0.settingsManager = .testValue
            $0.userProfileService = .testValue
            $0.acquisitionService = .testValue
        }

        // Set up initial state
        store.state.isOnboardingCompleted = true
        store.state.settings.appSettings.faceIDEnabled = true

        // Test authentication flow
        await store.send(.checkFaceIDAuthentication)
        await store.receive(.authenticateWithFaceID) {
            $0.isAuthenticating = true
        }
        await store.receive(.authenticationCompleted(true)) {
            $0.isAuthenticating = false
            $0.isAuthenticated = true
        }
    }

    func testFaceIDDisabled() async throws {
        let store = TestStore(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        ) {
            $0.biometricAuthenticationService = .testValue
            $0.settingsManager = SettingsManager(
                loadSettings: {
                    var settings = SettingsData()
                    settings.appSettings.faceIDEnabled = false
                    return settings
                },
                saveSettings: {},
                resetToDefaults: {},
                restoreDefaults: {},
                saveAPIKey: { _ in },
                loadAPIKey: { "test-api-key" },
                validateAPIKey: { _ in true },
                exportData: { _ in
                    guard let url = URL(string: "file://test.json") else {
                        XCTFail("Failed to create test export URL")
                        return URL(fileURLWithPath: "/dev/null")
                    }
                    return url
                },
                importData: { _ in },
                clearCache: {},
                performBackup: { _ in
                    guard let url = URL(string: "file://backup.json") else {
                        XCTFail("Failed to create test backup URL")
                        return URL(fileURLWithPath: "/dev/null")
                    }
                    return url
                }
            )
            $0.userProfileService = .testValue
            $0.acquisitionService = .testValue
        }

        // Set up initial state
        store.state.isOnboardingCompleted = true

        // Test that authentication is skipped when Face ID is disabled
        await store.send(.checkFaceIDAuthentication)
        await store.receive(.authenticationCompleted(true)) {
            $0.isAuthenticated = true
        }
    }

    func testAPIKeyManagement() {
        var settings = SettingsFeature.State()

        // Test adding API keys
        settings.apiSettings.apiKeys = [
            SettingsFeature.APIKeyEntry(
                id: "1",
                name: "Production",
                key: "sk-ant-prod-123",
                createdAt: Date()
            ),
            SettingsFeature.APIKeyEntry(
                id: "2",
                name: "Development",
                key: "sk-ant-dev-456",
                createdAt: Date()
            ),
        ]

        XCTAssertEqual(settings.apiSettings.apiKeys.count, 2)

        // Test selecting API key
        settings.apiSettings.selectedAPIKeyId = "1"
        XCTAssertEqual(settings.apiSettings.selectedAPIKeyId, "1")

        // Test LLM model selection
        settings.apiSettings.selectedModel = .claude3Sonnet
        XCTAssertEqual(settings.apiSettings.selectedModel, .claude3Sonnet)
    }

    func testOutputLengthSettings() {
        var settings = SettingsFeature.State()

        // Test default values
        XCTAssertEqual(settings.advancedSettings.outputLength, 4000)

        // Test setting output length
        settings.advancedSettings.outputLength = 10000
        XCTAssertEqual(settings.advancedSettings.outputLength, 10000)

        // Test temperature settings
        XCTAssertEqual(settings.advancedSettings.llmTemperature, 0.3)
        settings.advancedSettings.llmTemperature = 0.7
        XCTAssertEqual(settings.advancedSettings.llmTemperature, 0.7)
    }
}
