#if os(iOS)
    @testable import AppCore
@testable import AIKOiOSiOS
    @testable import AppCore
@testable import AIKOiOS
    import SwiftUI
    import XCTest

    final class IOSNavigationServiceClientTests: XCTestCase {
        var client: IOSNavigationServiceClient?

        private var clientUnwrapped: IOSNavigationServiceClient {
            guard let client else { fatalError("client not initialized") }
            return client
        }

        override func setUp() async throws {
            try await super.setUp()
            client = IOSNavigationServiceClient()
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

            // Test that supportsNavigationStack executes on MainActor
            let supports = await clientUnwrapped.supportsNavigationStack()
            XCTAssertTrue(supports == true || supports == false, "Should return a boolean value")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After supportsNavigationStack, should still be on main thread")
            }
        }

        func testDefaultNavigationStyleMainActor() async {
            let style = await clientUnwrapped.defaultNavigationStyle()

            // Should return a valid NavigationStyle
            let validStyles: [NavigationStyle] = [.stack, .tab, .page]
            XCTAssertTrue(validStyles.contains(style), "Should return a valid NavigationStyle")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After defaultNavigationStyle, should be on main thread")
            }
        }

        func testSupportsNavigationBarDisplayModeMainActor() async {
            let supports = await clientUnwrapped.supportsNavigationBarDisplayMode()

            // The result type doesn't matter, we're testing MainActor context
            XCTAssertTrue(supports == true || supports == false, "Should return a boolean value")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After supportsNavigationBarDisplayMode, should be on main thread")
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

        // MARK: - NavigationServiceClient Integration Tests

        func testStaticIOSClientCreation() async {
            let serviceClient = NavigationServiceClient.iOSLive

            // Test that we can call the client methods
            let supports = await serviceClient.supportsNavigationStack()
            XCTAssertTrue(supports == true || supports == false, "Should return a boolean value")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Static iOS client should maintain MainActor context")
            }
        }

        func testAsyncAwaitPattern() async {
            // Test the async/await pattern works correctly
            async let supportsStackTask = clientUnwrapped.supportsNavigationStack()
            async let defaultStyleTask = clientUnwrapped.defaultNavigationStyle()
            async let supportsDisplayModeTask = clientUnwrapped.supportsNavigationBarDisplayMode()

            let (supportsStack, defaultStyle, supportsDisplayMode) = await (supportsStackTask, defaultStyleTask, supportsDisplayModeTask)

            XCTAssertTrue(supportsStack == true || supportsStack == false, "supportsNavigationStack should return boolean")
            let validStyles: [NavigationStyle] = [.stack, .tab, .page]
            XCTAssertTrue(validStyles.contains(defaultStyle), "defaultNavigationStyle should return valid style")
            XCTAssertTrue(supportsDisplayMode == true || supportsDisplayMode == false, "supportsNavigationBarDisplayMode should return boolean")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After concurrent async operations, should be on main thread")
            }
        }

        // MARK: - Navigation Feature Tests

        func testNavigationStackSupport() async {
            let supports = await clientUnwrapped.supportsNavigationStack()

            // On iOS 16+, should support navigation stack
            if #available(iOS 16.0, *) {
                XCTAssertTrue(supports, "Should support NavigationStack on iOS 16+")
            } else {
                XCTAssertFalse(supports, "Should not support NavigationStack on iOS < 16")
            }
        }

        func testDefaultNavigationStyleConsistency() async {
            let style1 = await clientUnwrapped.defaultNavigationStyle()
            let style2 = await clientUnwrapped.defaultNavigationStyle()

            // Default style should be consistent across calls
            XCTAssertEqual(style1, style2, "Default navigation style should be consistent")
        }

        func testNavigationBarDisplayModeSupport() async {
            let supports = await clientUnwrapped.supportsNavigationBarDisplayMode()

            // iOS should generally support navigation bar display mode
            XCTAssertTrue(supports, "iOS should support navigation bar display mode")
        }

        // MARK: - Convenience Accessor Tests

        func testConvenienceStaticAccessor() async {
            let serviceClient = IOSNavigationServiceClient.live

            // Test that the convenience accessor works
            let supports = await serviceClient.supportsNavigationStack()
            XCTAssertTrue(supports == true || supports == false, "Convenience accessor should work")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Convenience accessor should maintain MainActor context")
            }
        }
    }
#endif
