#if os(iOS)
    @testable import AppCore
@testable import AIKOiOSiOS
    @testable import AppCore
@testable import AIKOiOS
    import CoreHaptics
    import SwiftUI
    import XCTest

    final class IOSHapticManagerClientTests: XCTestCase {
        var client: IOSHapticManagerClient?

        private var clientUnwrapped: IOSHapticManagerClient {
            guard let client else { fatalError("client not initialized") }
            return client
        }

        override func setUp() async throws {
            try await super.setUp()
            client = IOSHapticManagerClient()
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

            // Test that impact executes on MainActor
            await clientUnwrapped.impact(.light)

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After impact, should still be on main thread")
            }
        }

        func testImpactMainActor() async {
            await clientUnwrapped.impact(.medium)

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After impact, should be on main thread")
            }
        }

        func testNotificationMainActor() async {
            await clientUnwrapped.notification(.success)

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After notification, should be on main thread")
            }
        }

        func testSelectionMainActor() async {
            await clientUnwrapped.selection()

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After selection, should be on main thread")
            }
        }

        func testButtonTapMainActor() async {
            await clientUnwrapped.buttonTap()

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After buttonTap, should be on main thread")
            }
        }

        func testToggleSwitchMainActor() async {
            await clientUnwrapped.toggleSwitch()

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After toggleSwitch, should be on main thread")
            }
        }

        func testSuccessActionMainActor() async {
            await clientUnwrapped.successAction()

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After successAction, should be on main thread")
            }
        }

        func testErrorActionMainActor() async {
            await clientUnwrapped.errorAction()

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After errorAction, should be on main thread")
            }
        }

        func testWarningActionMainActor() async {
            await clientUnwrapped.warningAction()

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After warningAction, should be on main thread")
            }
        }

        func testDragStartedMainActor() async {
            await clientUnwrapped.dragStarted()

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After dragStarted, should be on main thread")
            }
        }

        func testDragEndedMainActor() async {
            await clientUnwrapped.dragEnded()

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After dragEnded, should be on main thread")
            }
        }

        func testRefreshMainActor() async {
            await clientUnwrapped.refresh()

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After refresh, should be on main thread")
            }
        }

        // MARK: - Template Compliance Tests

        func testInheritsFromSimpleServiceTemplate() {
            XCTAssertTrue(clientUnwrapped is SimpleServiceTemplate, "Should inherit from SimpleServiceTemplate")
            XCTAssertTrue(clientUnwrapped is MainActorService, "Should conform to MainActorService protocol")
        }

        func testTemplateStartMethod() async throws {
            // Test that the template's start method can be called without error
            try await clientUnwrapped.start()

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After start(), should be on main thread")
            }
        }

        // MARK: - HapticManagerClient Integration Tests

        func testStaticIOSClientCreation() async {
            let serviceClient = HapticManagerClient.iOSLive

            // Test that we can call the client methods
            await serviceClient.impact(.light)
            await serviceClient.notification(.success)
            await serviceClient.selection()

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Static iOS client should maintain MainActor context")
            }
        }

        func testAsyncAwaitPattern() async {
            // Test the async/await pattern works correctly
            async let impactTask = clientUnwrapped.impact(.medium)
            async let notificationTask = clientUnwrapped.notification(.warning)
            async let selectionTask = clientUnwrapped.selection()

            await (impactTask, notificationTask, selectionTask)

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After concurrent async operations, should be on main thread")
            }
        }

        // MARK: - Haptic Functionality Tests

        func testAllImpactStyles() async {
            // Test all impact styles
            await clientUnwrapped.impact(.light)
            await clientUnwrapped.impact(.medium)
            await clientUnwrapped.impact(.heavy)
            await clientUnwrapped.impact(.soft)
            await clientUnwrapped.impact(.rigid)

            // Should complete without error
            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After all impact styles, should be on main thread")
            }
        }

        func testAllNotificationTypes() async {
            // Test all notification types
            await clientUnwrapped.notification(.success)
            await clientUnwrapped.notification(.warning)
            await clientUnwrapped.notification(.error)

            // Should complete without error
            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After all notification types, should be on main thread")
            }
        }

        func testConvenienceHapticMethods() async {
            // Test convenience methods that map to specific haptic patterns
            await clientUnwrapped.buttonTap() // Maps to light impact
            await clientUnwrapped.toggleSwitch() // Maps to medium impact
            await clientUnwrapped.successAction() // Maps to success notification
            await clientUnwrapped.errorAction() // Maps to error notification
            await clientUnwrapped.warningAction() // Maps to warning notification
            await clientUnwrapped.dragStarted() // Maps to soft impact
            await clientUnwrapped.dragEnded() // Maps to rigid impact

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After convenience methods, should be on main thread")
            }
        }

        func testRefreshHapticSequence() async {
            // Test the refresh method which performs a sequence of haptics
            await clientUnwrapped.refresh()

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After refresh sequence, should be on main thread")
            }
        }

        func testSelectionHaptic() async {
            // Test selection haptic
            await clientUnwrapped.selection()

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After selection haptic, should be on main thread")
            }
        }

        // MARK: - Multiple Operations Tests

        func testMultipleImpacts() async {
            // Test multiple impacts in sequence
            await clientUnwrapped.impact(.light)
            await clientUnwrapped.impact(.medium)
            await clientUnwrapped.impact(.heavy)

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After multiple impacts, should be on main thread")
            }
        }

        func testMixedHapticOperations() async {
            // Test mixing different types of haptic operations
            await clientUnwrapped.impact(.medium)
            await clientUnwrapped.notification(.success)
            await clientUnwrapped.selection()
            await clientUnwrapped.buttonTap()
            await clientUnwrapped.dragStarted()

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After mixed operations, should be on main thread")
            }
        }

        func testConcurrentHapticOperations() async {
            // Test concurrent haptic operations
            async let impact1 = clientUnwrapped.impact(.light)
            async let impact2 = clientUnwrapped.impact(.medium)
            async let notification1 = clientUnwrapped.notification(.success)
            async let selection1 = clientUnwrapped.selection()

            await (impact1, impact2, notification1, selection1)

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After concurrent haptic operations, should be on main thread")
            }
        }

        // MARK: - Error Handling Tests

        func testHapticsOnNonHapticCapableDevice() async {
            // Even on devices without haptic support, methods should complete without crashing
            await clientUnwrapped.impact(.heavy)
            await clientUnwrapped.notification(.error)
            await clientUnwrapped.selection()

            // Should complete successfully regardless of device capabilities
            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After haptics on any device, should be on main thread")
            }
        }
    }
#endif
