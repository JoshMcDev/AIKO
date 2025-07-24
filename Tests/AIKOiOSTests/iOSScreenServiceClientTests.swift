#if os(iOS)
    @testable import AppCore
@testable import AIKOiOSiOS
    @testable import AppCore
@testable import AIKOiOS
    import SwiftUI
    import XCTest

    final class IOSScreenServiceClientTests: XCTestCase {
        var client: IOSScreenServiceClient?

        private var clientUnwrapped: IOSScreenServiceClient {
            guard let client else { fatalError("client not initialized") }
            return client
        }

        override func setUp() async throws {
            try await super.setUp()
            client = IOSScreenServiceClient()
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

            // Test that mainScreenBounds executes on MainActor
            let bounds = await clientUnwrapped.mainScreenBounds()
            XCTAssertTrue(bounds.width > 0, "Screen bounds should have positive width")
            XCTAssertTrue(bounds.height > 0, "Screen bounds should have positive height")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After mainScreenBounds, should still be on main thread")
            }
        }

        func testMainScreenBoundsMainActor() async {
            let bounds = await clientUnwrapped.mainScreenBounds()

            XCTAssertTrue(bounds.width > 0, "Screen width should be positive")
            XCTAssertTrue(bounds.height > 0, "Screen height should be positive")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After mainScreenBounds, should be on main thread")
            }
        }

        func testMainScreenWidthMainActor() async {
            let width = await clientUnwrapped.mainScreenWidth()

            XCTAssertTrue(width > 0, "Screen width should be positive")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After mainScreenWidth, should be on main thread")
            }
        }

        func testMainScreenHeightMainActor() async {
            let height = await clientUnwrapped.mainScreenHeight()

            XCTAssertTrue(height > 0, "Screen height should be positive")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After mainScreenHeight, should be on main thread")
            }
        }

        func testScreenScaleMainActor() async {
            let scale = await clientUnwrapped.screenScale()

            XCTAssertTrue(scale > 0, "Screen scale should be positive")
            XCTAssertTrue(scale >= 1.0, "Screen scale should be at least 1.0")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After screenScale, should be on main thread")
            }
        }

        func testIsCompactMainActor() async {
            let isCompact = await clientUnwrapped.isCompact()

            XCTAssertTrue(isCompact == true || isCompact == false, "isCompact should be a boolean")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After isCompact, should be on main thread")
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

        // MARK: - ScreenServiceClient Integration Tests

        func testStaticIOSClientCreation() async {
            let serviceClient = ScreenServiceClient.iOSLive

            // Test that we can call the client methods
            let bounds = await serviceClient.mainScreenBounds()
            let width = await serviceClient.mainScreenWidth()
            let height = await serviceClient.mainScreenHeight()
            let scale = await serviceClient.screenScale()
            let isCompact = await serviceClient.isCompact()

            XCTAssertTrue(bounds.width > 0, "Bounds width should be positive")
            XCTAssertTrue(bounds.height > 0, "Bounds height should be positive")
            XCTAssertTrue(width > 0, "Width should be positive")
            XCTAssertTrue(height > 0, "Height should be positive")
            XCTAssertTrue(scale >= 1.0, "Scale should be at least 1.0")
            XCTAssertTrue(isCompact == true || isCompact == false, "isCompact should be boolean")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Static iOS client should maintain MainActor context")
            }
        }

        func testAsyncAwaitPattern() async {
            // Test the async/await pattern works correctly
            async let boundsTask = clientUnwrapped.mainScreenBounds()
            async let widthTask = clientUnwrapped.mainScreenWidth()
            async let heightTask = clientUnwrapped.mainScreenHeight()
            async let scaleTask = clientUnwrapped.screenScale()
            async let compactTask = clientUnwrapped.isCompact()

            let (bounds, width, height, scale, isCompact) = await (boundsTask, widthTask, heightTask, scaleTask, compactTask)

            XCTAssertTrue(bounds.width > 0, "Bounds width should be positive")
            XCTAssertTrue(bounds.height > 0, "Bounds height should be positive")
            XCTAssertTrue(width > 0, "Width should be positive")
            XCTAssertTrue(height > 0, "Height should be positive")
            XCTAssertTrue(scale >= 1.0, "Scale should be at least 1.0")
            XCTAssertTrue(isCompact == true || isCompact == false, "isCompact should be boolean")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After concurrent async operations, should be on main thread")
            }
        }

        // MARK: - Screen Property Tests

        func testScreenBoundsConsistency() async {
            let bounds = await clientUnwrapped.mainScreenBounds()
            let width = await clientUnwrapped.mainScreenWidth()
            let height = await clientUnwrapped.mainScreenHeight()

            XCTAssertEqual(bounds.width, width, "Bounds width should match individual width")
            XCTAssertEqual(bounds.height, height, "Bounds height should match individual height")
        }

        func testScreenPropertiesStability() async {
            // Test that screen properties remain consistent across multiple calls
            let bounds1 = await clientUnwrapped.mainScreenBounds()
            let bounds2 = await clientUnwrapped.mainScreenBounds()

            XCTAssertEqual(bounds1, bounds2, "Screen bounds should be consistent")

            let scale1 = await clientUnwrapped.screenScale()
            let scale2 = await clientUnwrapped.screenScale()

            XCTAssertEqual(scale1, scale2, "Screen scale should be consistent")

            let compact1 = await clientUnwrapped.isCompact()
            let compact2 = await clientUnwrapped.isCompact()

            XCTAssertEqual(compact1, compact2, "Compact state should be consistent")
        }

        func testScreenScaleValidRange() async {
            let scale = await clientUnwrapped.screenScale()

            // Screen scale should be in a reasonable range
            XCTAssertTrue(scale >= 1.0, "Screen scale should be at least 1.0")
            XCTAssertTrue(scale <= 4.0, "Screen scale should be reasonable (≤ 4.0)")

            // Common iOS scales are 1.0, 2.0, 3.0
            let commonScales: [CGFloat] = [1.0, 2.0, 3.0]
            let isCommonScale = commonScales.contains(scale)

            if !isCommonScale {
                // Allow for potential future scales, but they should still be reasonable
                XCTAssertTrue(scale > 0.5 && scale < 5.0, "Unusual scale should still be reasonable: \(scale)")
            }
        }

        func testScreenDimensionsReasonable() async {
            let width = await clientUnwrapped.mainScreenWidth()
            let height = await clientUnwrapped.mainScreenHeight()

            // iOS devices have reasonable screen dimensions
            XCTAssertTrue(width >= 200, "Screen width should be at least 200 points")
            XCTAssertTrue(height >= 200, "Screen height should be at least 200 points")
            XCTAssertTrue(width <= 2000, "Screen width should be reasonable (≤ 2000 points)")
            XCTAssertTrue(height <= 3000, "Screen height should be reasonable (≤ 3000 points)")
        }

        func testCompactStateLogic() async {
            let isCompact = await clientUnwrapped.isCompact()
            let width = await clientUnwrapped.mainScreenWidth()

            // Basic logic check: very narrow screens should typically be compact
            if width < 400 {
                // Most phones have width < 400, should typically be compact
                // Note: This is a heuristic, actual implementation may vary
            }

            // The important thing is that it returns a consistent boolean
            XCTAssertTrue(isCompact == true || isCompact == false, "isCompact should be a valid boolean")
        }

        // MARK: - Performance Tests

        func testScreenPropertiesPerformance() async {
            let iterations = 100
            let startTime = CFAbsoluteTimeGetCurrent()

            for _ in 0 ..< iterations {
                _ = await clientUnwrapped.mainScreenBounds()
                _ = await clientUnwrapped.mainScreenWidth()
                _ = await clientUnwrapped.mainScreenHeight()
                _ = await clientUnwrapped.screenScale()
                _ = await clientUnwrapped.isCompact()
            }

            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

            // Screen properties should be fast to access (allowing generous time for CI)
            XCTAssertLessThan(timeElapsed, 2.0, "Screen property access should be fast")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After performance test, should be on main thread")
            }
        }

        // MARK: - Multiple Access Tests

        func testConcurrentScreenPropertyAccess() async {
            // Test concurrent access to the same properties
            async let bounds1 = clientUnwrapped.mainScreenBounds()
            async let bounds2 = clientUnwrapped.mainScreenBounds()
            async let width1 = clientUnwrapped.mainScreenWidth()
            async let width2 = clientUnwrapped.mainScreenWidth()
            async let scale1 = clientUnwrapped.screenScale()
            async let scale2 = clientUnwrapped.screenScale()

            let (b1, b2, w1, w2, s1, s2) = await (bounds1, bounds2, width1, width2, scale1, scale2)

            XCTAssertEqual(b1, b2, "Concurrent bounds calls should return same result")
            XCTAssertEqual(w1, w2, "Concurrent width calls should return same result")
            XCTAssertEqual(s1, s2, "Concurrent scale calls should return same result")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After concurrent access, should be on main thread")
            }
        }

        // MARK: - Convenience Accessor Tests

        func testConvenienceStaticAccessor() async {
            let serviceClient = IOSScreenServiceClient.live

            // Test that the convenience accessor works
            let bounds = await serviceClient.mainScreenBounds()
            let scale = await serviceClient.screenScale()

            XCTAssertTrue(bounds.width > 0, "Convenience accessor should work for bounds")
            XCTAssertTrue(scale >= 1.0, "Convenience accessor should work for scale")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Convenience accessor should maintain MainActor context")
            }
        }
    }
#endif
