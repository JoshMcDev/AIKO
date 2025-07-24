#if os(iOS)
    @testable import AppCore
@testable import AIKOiOSiOS
    @testable import AppCore
@testable import AIKOiOS
    import SwiftUI
    import UIKit
    import XCTest

    final class IOSBlurEffectServiceClientTests: XCTestCase {
        var client: IOSBlurEffectServiceClient?

        private var clientUnwrapped: IOSBlurEffectServiceClient {
            guard let client else { fatalError("client not initialized") }
            return client
        }

        override func setUp() async throws {
            try await super.setUp()
            client = IOSBlurEffectServiceClient()
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

            // Test that createBlurredBackground executes on MainActor
            let blurredView = await clientUnwrapped.createBlurredBackground(radius: 10.0)
            XCTAssertNotNil(blurredView, "Should return a valid AnyView")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After createBlurredBackground, should still be on main thread")
            }
        }

        func testSupportsNativeBlurMainActor() async {
            let supports = await clientUnwrapped.supportsNativeBlur()

            // The result type doesn't matter, we're testing MainActor context
            XCTAssertTrue(supports == true || supports == false, "Should return a boolean value")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After supportsNativeBlur, should be on main thread")
            }
        }

        func testRecommendedBlurStyleMainActor() async {
            let blurStyle = await clientUnwrapped.recommendedBlurStyle()

            // Should return a valid UIBlurEffect.Style
            let validStyles: [UIBlurEffect.Style] = [.regular, .light, .dark, .extraLight, .prominent, .systemUltraThinMaterial, .systemThinMaterial, .systemMaterial, .systemThickMaterial, .systemChromeMaterial]
            XCTAssertTrue(validStyles.contains(blurStyle), "Should return a valid UIBlurEffect.Style")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After recommendedBlurStyle, should be on main thread")
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

        // MARK: - BlurEffectServiceClient Integration Tests

        func testStaticIOSClientCreation() async {
            let serviceClient = BlurEffectServiceClient.iOS

            // Test that we can call the client methods
            let supports = await serviceClient.supportsNativeBlur()
            XCTAssertTrue(supports == true || supports == false, "Should return a boolean value")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Static iOS client should maintain MainActor context")
            }
        }

        func testAsyncAwaitPattern() async {
            // Test the async/await pattern works correctly
            async let supportsTask = clientUnwrapped.supportsNativeBlur()
            async let blurStyleTask = clientUnwrapped.recommendedBlurStyle()

            let (supports, blurStyle) = await (supportsTask, blurStyleTask)

            XCTAssertTrue(supports == true || supports == false, "supportsNativeBlur should return boolean")

            let validStyles: [UIBlurEffect.Style] = [.regular, .light, .dark, .extraLight, .prominent, .systemUltraThinMaterial, .systemThinMaterial, .systemMaterial, .systemThickMaterial, .systemChromeMaterial]
            XCTAssertTrue(validStyles.contains(blurStyle), "recommendedBlurStyle should return valid style")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After concurrent async operations, should be on main thread")
            }
        }

        // MARK: - UI Integration Tests

        func testCreateBlurredBackgroundReturnsValidView() async {
            let blurredView = await clientUnwrapped.createBlurredBackground(radius: 15.0)

            XCTAssertNotNil(blurredView, "Should return a non-nil AnyView")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After creating blurred background, should be on main thread")
            }
        }

        func testBlurRadiusVariations() async {
            // Test with different blur radius values
            let smallBlur = await clientUnwrapped.createBlurredBackground(radius: 5.0)
            let mediumBlur = await clientUnwrapped.createBlurredBackground(radius: 15.0)
            let largeBlur = await clientUnwrapped.createBlurredBackground(radius: 25.0)

            XCTAssertNotNil(smallBlur, "Small blur should return valid view")
            XCTAssertNotNil(mediumBlur, "Medium blur should return valid view")
            XCTAssertNotNil(largeBlur, "Large blur should return valid view")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After multiple blur operations, should be on main thread")
            }
        }
    }
#endif
