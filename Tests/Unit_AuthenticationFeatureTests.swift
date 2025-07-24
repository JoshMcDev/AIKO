@testable import AppCore
import ComposableArchitecture
import XCTest

@MainActor
final class AuthenticationFeatureTests: XCTestCase {
    func testInitialState() {
        let state = AuthenticationFeature.State()

        XCTAssertFalse(state.isAuthenticating)
        XCTAssertFalse(state.isAuthenticated)
        XCTAssertNil(state.authenticationError)
        XCTAssertEqual(state.biometricType, .none)
        XCTAssertNil(state.lastAuthenticationDate)
        XCTAssertTrue(state.requiresAuthentication)
    }

    func testBiometricTypeDetection() async {
        let store = TestStore(
            initialState: AuthenticationFeature.State()
        ) {
            AuthenticationFeature()
        } withDependencies: {
            $0.biometricAuthenticationService = .mock
        }

        await store.send(.checkBiometricAvailability)

        // The mock service will return a biometric type
        await store.receive(.biometricTypeDetected(.faceID)) {
            $0.biometricType = .faceID
        }
    }

    func testSuccessfulAuthentication() async {
        let store = TestStore(
            initialState: AuthenticationFeature.State(
                biometricType: .faceID
            )
        ) {
            AuthenticationFeature()
        } withDependencies: {
            $0.biometricAuthenticationService = .mockSuccess
            $0.date = .constant(Date(timeIntervalSince1970: 1_234_567_890))
        }

        await store.send(.authenticate)

        await store.receive(.authenticationStarted) {
            $0.isAuthenticating = true
            $0.authenticationError = nil
        }

        await store.receive(.authenticationSucceeded) {
            $0.isAuthenticating = false
            $0.isAuthenticated = true
            $0.authenticationError = nil
            $0.lastAuthenticationDate = Date(timeIntervalSince1970: 1_234_567_890)
        }
    }

    func testFailedAuthentication() async {
        let store = TestStore(
            initialState: AuthenticationFeature.State(
                biometricType: .touchID
            )
        ) {
            AuthenticationFeature()
        } withDependencies: {
            $0.biometricAuthenticationService = .mockFailure
        }

        await store.send(.authenticate)

        await store.receive(.authenticationStarted) {
            $0.isAuthenticating = true
            $0.authenticationError = nil
        }

        await store.receive(.authenticationFailed("Authentication failed")) {
            $0.isAuthenticating = false
            $0.isAuthenticated = false
            $0.authenticationError = "Authentication failed"
        }
    }

    func testAuthenticationWithNoBiometrics() async {
        let store = TestStore(
            initialState: AuthenticationFeature.State(
                biometricType: .none
            )
        ) {
            AuthenticationFeature()
        }

        // Should not attempt authentication
        await store.send(.authenticate)
        // No state changes expected
    }

    func testAuthenticationWhileAuthenticating() async {
        let store = TestStore(
            initialState: AuthenticationFeature.State(
                isAuthenticating: true,
                biometricType: .faceID
            )
        ) {
            AuthenticationFeature()
        }

        // Should not start another authentication
        await store.send(.authenticate)
        // No state changes expected
    }

    func testLogout() async {
        let store = TestStore(
            initialState: AuthenticationFeature.State(
                isAuthenticated: true,
                authenticationError: "Previous error",
                lastAuthenticationDate: Date()
            )
        ) {
            AuthenticationFeature()
        }

        await store.send(.logout) {
            $0.isAuthenticated = false
            $0.lastAuthenticationDate = nil
            $0.authenticationError = nil
        }
    }

    func testSetRequiresAuthentication() async {
        let store = TestStore(
            initialState: AuthenticationFeature.State()
        ) {
            AuthenticationFeature()
        }

        // Disable authentication requirement
        await store.send(.setRequiresAuthentication(false)) {
            $0.requiresAuthentication = false
            $0.isAuthenticated = true
        }

        // Re-enable authentication requirement
        await store.send(.setRequiresAuthentication(true)) {
            $0.requiresAuthentication = true
            // isAuthenticated remains true until logout or failed auth
        }
    }

    func testStateHelpers() {
        var state = AuthenticationFeature.State()

        // Test needsAuthentication
        XCTAssertTrue(state.needsAuthentication)

        state.isAuthenticated = true
        XCTAssertFalse(state.needsAuthentication)

        state.requiresAuthentication = false
        XCTAssertFalse(state.needsAuthentication)

        // Test canUseBiometrics
        state.biometricType = .none
        XCTAssertFalse(state.canUseBiometrics)

        state.biometricType = .faceID
        XCTAssertTrue(state.canUseBiometrics)

        // Test authenticationStatus
        state = AuthenticationFeature.State()
        XCTAssertEqual(state.authenticationStatus, "Not authenticated")

        state.isAuthenticating = true
        XCTAssertEqual(state.authenticationStatus, "Authenticating...")

        state.isAuthenticating = false
        state.isAuthenticated = true
        XCTAssertEqual(state.authenticationStatus, "Authenticated")

        state.isAuthenticated = false
        state.authenticationError = "Test error"
        XCTAssertEqual(state.authenticationStatus, "Authentication failed: Test error")
    }

    func testAuthenticationFreshness() {
        var state = AuthenticationFeature.State()

        // No authentication date
        XCTAssertFalse(state.isAuthenticationFresh())

        // Fresh authentication (just now)
        state.lastAuthenticationDate = Date()
        XCTAssertTrue(state.isAuthenticationFresh())

        // Stale authentication (6 minutes ago)
        state.lastAuthenticationDate = Date().addingTimeInterval(-360)
        XCTAssertFalse(state.isAuthenticationFresh())

        // Edge case: exactly 5 minutes
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        state.lastAuthenticationDate = fiveMinutesAgo
        XCTAssertFalse(state.isAuthenticationFresh(now: Date()))
    }
}

// MARK: - BiometricType Tests

final class BiometricTypeTests: XCTestCase {
    func testIconNames() {
        XCTAssertEqual(BiometricType.none.iconName, "lock")
        XCTAssertEqual(BiometricType.faceID.iconName, "faceid")
        XCTAssertEqual(BiometricType.touchID.iconName, "touchid")
        XCTAssertEqual(BiometricType.opticID.iconName, "opticid")
    }

    func testRawValues() {
        XCTAssertEqual(BiometricType.none.rawValue, "None")
        XCTAssertEqual(BiometricType.faceID.rawValue, "Face ID")
        XCTAssertEqual(BiometricType.touchID.rawValue, "Touch ID")
        XCTAssertEqual(BiometricType.opticID.rawValue, "Optic ID")
    }
}

// MARK: - Mock Dependencies

extension BiometricAuthenticationService {
    static let mock = BiometricAuthenticationService(
        authenticate: { _ in true },
        checkBiometricAvailability: { .faceID }
    )

    static let mockSuccess = BiometricAuthenticationService(
        authenticate: { _ in true },
        checkBiometricAvailability: { .faceID }
    )

    static let mockFailure = BiometricAuthenticationService(
        authenticate: { _ in throw AuthenticationError.failed },
        checkBiometricAvailability: { .touchID }
    )
}

enum AuthenticationError: Error {
    case failed
}
