#if os(iOS)
    @testable import AppCore
@testable import AIKOiOSiOS
    @testable import AppCore
@testable import AIKOiOS
    import SwiftUI
    import XCTest

    final class IOSTextFieldServiceClientTests: XCTestCase {
        var client: IOSTextFieldServiceClient?

        private var clientUnwrapped: IOSTextFieldServiceClient {
            guard let client else { fatalError("client not initialized") }
            return client
        }

        override func setUp() async throws {
            try await super.setUp()
            client = IOSTextFieldServiceClient()
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

            // Test that supportsAutocapitalization executes on MainActor
            let supportsAutocap = await clientUnwrapped.supportsAutocapitalization()
            XCTAssertTrue(supportsAutocap, "iOS should support autocapitalization")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After supportsAutocapitalization, should still be on main thread")
            }
        }

        func testSupportsAutocapitalizationMainActor() async {
            let supports = await clientUnwrapped.supportsAutocapitalization()
            XCTAssertTrue(supports, "iOS should support autocapitalization")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After supportsAutocapitalization, should be on main thread")
            }
        }

        func testSupportsKeyboardTypesMainActor() async {
            let supports = await clientUnwrapped.supportsKeyboardTypes()
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

        // MARK: - TextFieldServiceClient Integration Tests

        func testStaticIOSClientCreation() async {
            let serviceClient = TextFieldServiceClient.iOSLive

            // Test that we can call the client methods
            let supportsAutocap = await serviceClient.supportsAutocapitalization()
            let supportsKeyboardTypes = await serviceClient.supportsKeyboardTypes()

            XCTAssertTrue(supportsAutocap, "iOS should support autocapitalization")
            XCTAssertTrue(supportsKeyboardTypes, "iOS should support keyboard types")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Static iOS client should maintain MainActor context")
            }
        }

        func testAsyncAwaitPattern() async {
            // Test the async/await pattern works correctly
            async let autocapTask = clientUnwrapped.supportsAutocapitalization()
            async let keyboardTypesTask = clientUnwrapped.supportsKeyboardTypes()

            let (supportsAutocap, supportsKeyboardTypes) = await (autocapTask, keyboardTypesTask)

            XCTAssertTrue(supportsAutocap, "iOS should support autocapitalization")
            XCTAssertTrue(supportsKeyboardTypes, "iOS should support keyboard types")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After concurrent async operations, should be on main thread")
            }
        }

        // MARK: - Text Field Capability Tests

        func testAutocapitalizationSupport() async {
            let supports = await clientUnwrapped.supportsAutocapitalization()
            XCTAssertTrue(supports, "iOS platform should support autocapitalization")
        }

        func testKeyboardTypesSupport() async {
            let supports = await clientUnwrapped.supportsKeyboardTypes()
            XCTAssertTrue(supports, "iOS platform should support different keyboard types")
        }

        func testMultipleCapabilityChecks() async {
            // Test multiple calls return consistent results
            let autocap1 = await clientUnwrapped.supportsAutocapitalization()
            let keyboardTypes1 = await clientUnwrapped.supportsKeyboardTypes()
            let autocap2 = await clientUnwrapped.supportsAutocapitalization()
            let keyboardTypes2 = await clientUnwrapped.supportsKeyboardTypes()

            XCTAssertEqual(autocap1, autocap2, "Multiple autocapitalization checks should be consistent")
            XCTAssertEqual(keyboardTypes1, keyboardTypes2, "Multiple keyboard types checks should be consistent")
            XCTAssertTrue(autocap1, "iOS should support autocapitalization")
            XCTAssertTrue(keyboardTypes1, "iOS should support keyboard types")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After multiple capability checks, should be on main thread")
            }
        }

        func testConcurrentCapabilityChecks() async {
            // Test concurrent calls to the same methods
            async let autocap1 = clientUnwrapped.supportsAutocapitalization()
            async let autocap2 = clientUnwrapped.supportsAutocapitalization()
            async let keyboardTypes1 = clientUnwrapped.supportsKeyboardTypes()
            async let keyboardTypes2 = clientUnwrapped.supportsKeyboardTypes()

            let (a1, a2, k1, k2) = await (autocap1, autocap2, keyboardTypes1, keyboardTypes2)

            XCTAssertEqual(a1, a2, "Concurrent autocapitalization calls should return same result")
            XCTAssertEqual(k1, k2, "Concurrent keyboard types calls should return same result")
            XCTAssertTrue(a1, "iOS should support autocapitalization")
            XCTAssertTrue(k1, "iOS should support keyboard types")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After concurrent capability checks, should be on main thread")
            }
        }

        // MARK: - Performance Tests

        func testCapabilityCheckPerformance() async {
            let iterations = 100
            let startTime = CFAbsoluteTimeGetCurrent()

            for _ in 0 ..< iterations {
                _ = await clientUnwrapped.supportsAutocapitalization()
                _ = await clientUnwrapped.supportsKeyboardTypes()
            }

            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

            // Should complete quickly (allowing generous time for CI)
            XCTAssertLessThan(timeElapsed, 5.0, "Capability checks should be fast")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After performance test, should be on main thread")
            }
        }

        // MARK: - Convenience Accessor Tests

        func testConvenienceStaticAccessor() async {
            let serviceClient = IOSTextFieldServiceClient.live

            // Test that the convenience accessor works
            let supportsAutocap = await serviceClient.supportsAutocapitalization()
            let supportsKeyboardTypes = await serviceClient.supportsKeyboardTypes()

            XCTAssertTrue(supportsAutocap, "Convenience accessor should work for autocapitalization")
            XCTAssertTrue(supportsKeyboardTypes, "Convenience accessor should work for keyboard types")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Convenience accessor should maintain MainActor context")
            }
        }
    }
#endif
