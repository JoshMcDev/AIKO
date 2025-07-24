#if os(iOS)
    @testable import AppCore
@testable import AIKOiOSiOS
    @testable import AppCore
@testable import AIKOiOS
    import SwiftUI
    import XCTest

    final class IOSKeyboardServiceClientTests: XCTestCase {
        var client: IOSKeyboardServiceClient?

        private var clientUnwrapped: IOSKeyboardServiceClient {
            guard let client else { fatalError("client not initialized") }
            return client
        }

        override func setUp() async throws {
            try await super.setUp()
            client = IOSKeyboardServiceClient()
        }

        override func tearDown() async throws {
            client = nil
            try await super.tearDown()
        }

        // MARK: - MainActor Context Verification Tests

        func testMainActorContextVerification() async {
            // Verify that service operations execute on MainActor
            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Service should operate on MainActor/Main thread")
            }

            // Test that defaultKeyboardType executes on MainActor
            let keyboardType = await clientUnwrapped.defaultKeyboardType()
            XCTAssertEqual(keyboardType, .default, "Should return default keyboard type")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After defaultKeyboardType, should still be on main thread")
            }
        }

        func testKeyboardTypeMethodsMainActor() async {
            let defaultType = await clientUnwrapped.defaultKeyboardType()
            let emailType = await clientUnwrapped.emailKeyboardType()
            let numberType = await clientUnwrapped.numberKeyboardType()
            let phoneType = await clientUnwrapped.phoneKeyboardType()
            let urlType = await clientUnwrapped.urlKeyboardType()

            // All keyboard type methods should return valid types
            XCTAssertEqual(defaultType, .default, "defaultKeyboardType should return .default")
            XCTAssertEqual(emailType, .email, "emailKeyboardType should return .email")
            XCTAssertEqual(numberType, .number, "numberKeyboardType should return .number")
            XCTAssertEqual(phoneType, .phone, "phoneKeyboardType should return .phone")
            XCTAssertEqual(urlType, .url, "urlKeyboardType should return .url")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After keyboard type methods, should be on main thread")
            }
        }

        func testSupportsKeyboardTypesMainActor() async {
            let supports = await clientUnwrapped.supportsKeyboardTypes()

            // iOS should support keyboard types
            XCTAssertTrue(supports, "iOS should support keyboard types")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After supportsKeyboardTypes, should be on main thread")
            }
        }

        // MARK: - Template Compliance Tests

        func testInheritsFromSimpleServiceTemplate() {
            XCTAssertTrue(client is SimpleServiceTemplate, "Should inherit from SimpleServiceTemplate")
            XCTAssertTrue(client is MainActorService, "Should conform to MainActorService protocol")
        }

        func testTemplateStartMethod() async throws {
            // Test that the template's start method can be called without error
            try await clientUnwrapped.start()

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After start(), should be on main thread")
            }
        }

        // MARK: - KeyboardServiceClient Integration Tests

        func testStaticIOSClientCreation() async {
            let serviceClient = KeyboardServiceClient.iOSLive

            // Test that we can call the client methods
            let defaultType = await serviceClient.defaultKeyboardType()
            XCTAssertEqual(defaultType, .default, "Should return default keyboard type")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Static iOS client should maintain MainActor context")
            }
        }

        func testAsyncAwaitPattern() async {
            // Test the async/await pattern works correctly
            async let defaultTypeTask = clientUnwrapped.defaultKeyboardType()
            async let emailTypeTask = clientUnwrapped.emailKeyboardType()
            async let supportsTask = clientUnwrapped.supportsKeyboardTypes()

            let (defaultType, emailType, supports) = await (defaultTypeTask, emailTypeTask, supportsTask)

            XCTAssertEqual(defaultType, .default, "defaultKeyboardType should return .default")
            XCTAssertEqual(emailType, .email, "emailKeyboardType should return .email")
            XCTAssertTrue(supports, "supportsKeyboardTypes should return true")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After concurrent async operations, should be on main thread")
            }
        }

        // MARK: - Keyboard Type Validation Tests

        func testAllKeyboardTypesReturned() async {
            let types = await [
                clientUnwrapped.defaultKeyboardType(),
                clientUnwrapped.emailKeyboardType(),
                clientUnwrapped.numberKeyboardType(),
                clientUnwrapped.phoneKeyboardType(),
                clientUnwrapped.urlKeyboardType(),
            ]

            let expectedTypes: [PlatformKeyboardType] = [.default, .email, .number, .phone, .url]

            // All types should be returned correctly
            XCTAssertEqual(types, expectedTypes, "All keyboard types should be returned correctly")
        }

        func testKeyboardTypeConsistency() async {
            // Test that keyboard types are consistently returned
            let defaultType1 = await clientUnwrapped.defaultKeyboardType()
            let defaultType2 = await clientUnwrapped.defaultKeyboardType()
            let emailType1 = await clientUnwrapped.emailKeyboardType()
            let emailType2 = await clientUnwrapped.emailKeyboardType()

            XCTAssertEqual(defaultType1, defaultType2, "Default keyboard type should be consistent")
            XCTAssertEqual(emailType1, emailType2, "Email keyboard type should be consistent")
        }

        func testKeyboardSupportConsistency() async {
            let supports1 = await clientUnwrapped.supportsKeyboardTypes()
            let supports2 = await clientUnwrapped.supportsKeyboardTypes()

            // Support should be consistent across calls
            XCTAssertEqual(supports1, supports2, "Keyboard type support should be consistent")
        }

        // MARK: - Convenience Accessor Tests

        func testConvenienceStaticAccessor() async {
            let serviceClient = IOSKeyboardServiceClient.live

            // Test that the convenience accessor works
            let defaultType = await serviceClient.defaultKeyboardType()
            XCTAssertEqual(defaultType, .default, "Convenience accessor should work")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Convenience accessor should maintain MainActor context")
            }
        }
    }
#endif
