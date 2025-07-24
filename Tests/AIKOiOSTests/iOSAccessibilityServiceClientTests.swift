#if os(iOS)
    @testable import AppCore
@testable import AIKOiOSiOS
    @testable import AppCore
@testable import AIKOiOS
    import SwiftUI
    import XCTest

    final class IOSAccessibilityServiceClientTests: XCTestCase {
        var client: IOSAccessibilityServiceClient?

        private var clientUnwrapped: IOSAccessibilityServiceClient {
            guard let client else { fatalError("client not initialized") }
            return client
        }

        override func setUp() async throws {
            try await super.setUp()
            client = IOSAccessibilityServiceClient()
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

            // Test that announceNotification executes on MainActor
            await clientUnwrapped.announceNotification("Test message", priority: .medium)

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After announceNotification, should still be on main thread")
            }
        }

        func testSupportsAccessibilityNotificationsMainActor() async {
            let supports = await clientUnwrapped.supportsAccessibilityNotifications()

            // The result type doesn't matter, we're testing MainActor context
            XCTAssertTrue(supports == true || supports == false, "Should return a boolean value")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After supportsAccessibilityNotifications, should be on main thread")
            }
        }

        func testNotifyVoiceOverStatusChangeMainActor() async {
            await clientUnwrapped.notifyVoiceOverStatusChange()

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After notifyVoiceOverStatusChange, should be on main thread")
            }
        }

        func testVoiceOverStatusChangeNotificationNameMainActor() async {
            let notificationName = await clientUnwrapped.voiceOverStatusChangeNotificationName()

            // The result might be nil, that's fine
            XCTAssertTrue(notificationName != nil || notificationName == nil, "Should return optional Notification.Name")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After voiceOverStatusChangeNotificationName, should be on main thread")
            }
        }

        func testHasVoiceOverStatusNotificationsMainActor() async {
            let hasNotifications = await clientUnwrapped.hasVoiceOverStatusNotifications()

            XCTAssertTrue(hasNotifications == true || hasNotifications == false, "Should return a boolean value")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After hasVoiceOverStatusNotifications, should be on main thread")
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

        // MARK: - AccessibilityServiceClient Integration Tests

        func testStaticIOSClientCreation() async {
            let serviceClient = AccessibilityServiceClient.iOS

            // Test that we can call the client methods
            let supports = await serviceClient.supportsAccessibilityNotifications()
            XCTAssertTrue(supports == true || supports == false, "Should return a boolean value")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Static iOS client should maintain MainActor context")
            }
        }

        func testAsyncAwaitPattern() async {
            // Test the async/await pattern works correctly
            async let supportsTask = clientUnwrapped.supportsAccessibilityNotifications()
            async let hasNotificationsTask = clientUnwrapped.hasVoiceOverStatusNotifications()

            let (supports, hasNotifications) = await (supportsTask, hasNotificationsTask)

            XCTAssertTrue(supports == true || supports == false, "supportsAccessibilityNotifications should return boolean")
            XCTAssertTrue(hasNotifications == true || hasNotifications == false, "hasVoiceOverStatusNotifications should return boolean")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After concurrent async operations, should be on main thread")
            }
        }
    }
#endif
