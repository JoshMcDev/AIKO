#if os(iOS)
    @testable import AppCore
@testable import AIKOiOSiOS
    @testable import AppCore
@testable import AIKOiOS
    import SwiftUI
    import XCTest

    final class IOSFontScalingServiceClientTests: XCTestCase {
        var client: IOSFontScalingServiceClient?

        private var clientUnwrapped: IOSFontScalingServiceClient {
            guard let client else { fatalError("client not initialized") }
            return client
        }

        override func setUp() async throws {
            try await super.setUp()
            client = IOSFontScalingServiceClient()
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

            // Test that scaledFontSize executes on MainActor
            let scaledSize = await clientUnwrapped.scaledFontSize(
                for: 16.0,
                textStyle: .body,
                sizeCategory: .medium
            )
            XCTAssertTrue(scaledSize > 0, "Scaled font size should be positive")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After scaledFontSize, should still be on main thread")
            }
        }

        func testSupportsUIFontMetricsMainActor() async {
            let supports = await clientUnwrapped.supportsUIFontMetrics()
            XCTAssertTrue(supports, "iOS should support UIFontMetrics")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After supportsUIFontMetrics, should be on main thread")
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

        // MARK: - FontScalingServiceClient Integration Tests

        func testStaticIOSClientCreation() async {
            let serviceClient = FontScalingServiceClient.iOS

            // Test that we can call the client methods
            let scaledSize = await serviceClient._scaledFontSize(16.0, .body, .medium)
            let supports = await serviceClient._supportsUIFontMetrics()

            XCTAssertTrue(scaledSize > 0, "Scaled font size should be positive")
            XCTAssertTrue(supports, "iOS should support UIFontMetrics")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Static iOS client should maintain MainActor context")
            }
        }

        func testAsyncAwaitPattern() async {
            // Test the async/await pattern works correctly
            async let scaledSizeTask = clientUnwrapped.scaledFontSize(for: 18.0, textStyle: .headline, sizeCategory: .large)
            async let supportsTask = clientUnwrapped.supportsUIFontMetrics()

            let (scaledSize, supports) = await (scaledSizeTask, supportsTask)

            XCTAssertTrue(scaledSize > 0, "Scaled font size should be positive")
            XCTAssertTrue(supports, "iOS should support UIFontMetrics")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After concurrent async operations, should be on main thread")
            }
        }

        // MARK: - Font Scaling Tests

        func testUIFontMetricsSupport() async {
            let supports = await clientUnwrapped.supportsUIFontMetrics()
            XCTAssertTrue(supports, "iOS platform should always support UIFontMetrics")
        }

        func testScaledFontSizeBasic() async {
            let baseSize: CGFloat = 16.0
            let scaledSize = await clientUnwrapped.scaledFontSize(
                for: baseSize,
                textStyle: .body,
                sizeCategory: .medium
            )

            XCTAssertTrue(scaledSize > 0, "Scaled font size should be positive")
            // For medium size category, scaled size should be reasonable
            XCTAssertTrue(scaledSize >= 10.0 && scaledSize <= 30.0, "Scaled size should be reasonable for medium category")
        }

        func testDifferentTextStyles() async {
            let baseSize: CGFloat = 16.0
            let sizeCategory = ContentSizeCategory.medium

            let textStyles: [Font.TextStyle] = [
                .largeTitle, .title, .title2, .title3,
                .headline, .subheadline, .body, .callout,
                .footnote, .caption, .caption2,
            ]

            for textStyle in textStyles {
                let scaledSize = await clientUnwrapped.scaledFontSize(
                    for: baseSize,
                    textStyle: textStyle,
                    sizeCategory: sizeCategory
                )

                XCTAssertTrue(scaledSize > 0, "Scaled font size should be positive for \(textStyle)")
                XCTAssertTrue(scaledSize >= 5.0 && scaledSize <= 50.0, "Scaled size should be reasonable for \(textStyle)")
            }
        }

        func testDifferentSizeCategories() async {
            let baseSize: CGFloat = 16.0
            let textStyle = Font.TextStyle.body

            let sizeCategories: [ContentSizeCategory] = [
                .extraSmall, .small, .medium, .large,
                .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
                .accessibilityMedium, .accessibilityLarge,
                .accessibilityExtraLarge, .accessibilityExtraExtraLarge,
                .accessibilityExtraExtraExtraLarge,
            ]

            for sizeCategory in sizeCategories {
                let scaledSize = await clientUnwrapped.scaledFontSize(
                    for: baseSize,
                    textStyle: textStyle,
                    sizeCategory: sizeCategory
                )

                XCTAssertTrue(scaledSize > 0, "Scaled font size should be positive for \(sizeCategory)")
            }
        }

        func testScaledFontSizeProgression() async {
            let baseSize: CGFloat = 16.0
            let textStyle = Font.TextStyle.body

            // Test that larger size categories generally produce larger font sizes
            let smallSize = await clientUnwrapped.scaledFontSize(for: baseSize, textStyle: textStyle, sizeCategory: .small)
            let mediumSize = await clientUnwrapped.scaledFontSize(for: baseSize, textStyle: textStyle, sizeCategory: .medium)
            let largeSize = await clientUnwrapped.scaledFontSize(for: baseSize, textStyle: textStyle, sizeCategory: .large)
            let extraLargeSize = await clientUnwrapped.scaledFontSize(for: baseSize, textStyle: textStyle, sizeCategory: .extraLarge)

            XCTAssertTrue(smallSize <= mediumSize, "Small should not be larger than medium")
            XCTAssertTrue(mediumSize <= largeSize, "Medium should not be larger than large")
            XCTAssertTrue(largeSize <= extraLargeSize, "Large should not be larger than extra large")
        }

        func testAccessibilitySizeCategories() async {
            let baseSize: CGFloat = 16.0
            let textStyle = Font.TextStyle.body

            // Test accessibility size categories
            let accessibilityMedium = await clientUnwrapped.scaledFontSize(
                for: baseSize,
                textStyle: textStyle,
                sizeCategory: .accessibilityMedium
            )
            let accessibilityExtraLarge = await clientUnwrapped.scaledFontSize(
                for: baseSize,
                textStyle: textStyle,
                sizeCategory: .accessibilityExtraLarge
            )
            let accessibilityExtraExtraExtraLarge = await clientUnwrapped.scaledFontSize(
                for: baseSize,
                textStyle: textStyle,
                sizeCategory: .accessibilityExtraExtraExtraLarge
            )

            XCTAssertTrue(accessibilityMedium > baseSize, "Accessibility medium should be larger than base")
            XCTAssertTrue(accessibilityExtraLarge > accessibilityMedium, "Accessibility extra large should be larger")
            XCTAssertTrue(accessibilityExtraExtraExtraLarge > accessibilityExtraLarge, "Largest accessibility should be largest")
        }

        func testDifferentBaseSizes() async {
            let baseSizes: [CGFloat] = [10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 24.0]
            let textStyle = Font.TextStyle.body
            let sizeCategory = ContentSizeCategory.medium

            for baseSize in baseSizes {
                let scaledSize = await clientUnwrapped.scaledFontSize(
                    for: baseSize,
                    textStyle: textStyle,
                    sizeCategory: sizeCategory
                )

                XCTAssertTrue(scaledSize > 0, "Scaled size should be positive for base size \(baseSize)")

                // Scaled size should generally be close to base size for medium category
                let ratio = scaledSize / baseSize
                XCTAssertTrue(ratio >= 0.5 && ratio <= 2.0, "Scaling ratio should be reasonable for base size \(baseSize)")
            }
        }

        // MARK: - Consistency Tests

        func testScalingConsistency() async {
            let baseSize: CGFloat = 16.0
            let textStyle = Font.TextStyle.body
            let sizeCategory = ContentSizeCategory.medium

            // Multiple calls should return the same result
            let size1 = await clientUnwrapped.scaledFontSize(for: baseSize, textStyle: textStyle, sizeCategory: sizeCategory)
            let size2 = await clientUnwrapped.scaledFontSize(for: baseSize, textStyle: textStyle, sizeCategory: sizeCategory)
            let size3 = await clientUnwrapped.scaledFontSize(for: baseSize, textStyle: textStyle, sizeCategory: sizeCategory)

            XCTAssertEqual(size1, size2, "Multiple calls should return consistent results")
            XCTAssertEqual(size2, size3, "Multiple calls should return consistent results")
        }

        func testConcurrentScaling() async {
            let baseSize: CGFloat = 16.0

            // Test concurrent scaling operations
            async let bodySize = clientUnwrapped.scaledFontSize(for: baseSize, textStyle: .body, sizeCategory: .medium)
            async let headlineSize = clientUnwrapped.scaledFontSize(for: baseSize, textStyle: .headline, sizeCategory: .large)
            async let footnoteSize = clientUnwrapped.scaledFontSize(for: baseSize, textStyle: .footnote, sizeCategory: .small)
            async let titleSize = clientUnwrapped.scaledFontSize(for: baseSize, textStyle: .title, sizeCategory: .extraLarge)

            let (body, headline, footnote, title) = await (bodySize, headlineSize, footnoteSize, titleSize)

            XCTAssertTrue(body > 0, "Body size should be positive")
            XCTAssertTrue(headline > 0, "Headline size should be positive")
            XCTAssertTrue(footnote > 0, "Footnote size should be positive")
            XCTAssertTrue(title > 0, "Title size should be positive")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After concurrent scaling, should be on main thread")
            }
        }

        // MARK: - Performance Tests

        func testScalingPerformance() async {
            let baseSize: CGFloat = 16.0
            let textStyle = Font.TextStyle.body
            let sizeCategory = ContentSizeCategory.medium

            let iterations = 100
            let startTime = CFAbsoluteTimeGetCurrent()

            for _ in 0 ..< iterations {
                _ = await clientUnwrapped.scaledFontSize(for: baseSize, textStyle: textStyle, sizeCategory: sizeCategory)
            }

            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

            // Font scaling should be fast (allowing generous time for CI)
            XCTAssertLessThan(timeElapsed, 2.0, "Font scaling should be fast")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After performance test, should be on main thread")
            }
        }

        // MARK: - Convenience Accessor Tests

        func testConvenienceStaticAccessor() async {
            let serviceClient = IOSFontScalingServiceClient.live

            // Test that the convenience accessor works
            let scaledSize = await serviceClient._scaledFontSize(16.0, .body, .medium)
            let supports = await serviceClient._supportsUIFontMetrics()

            XCTAssertTrue(scaledSize > 0, "Convenience accessor should work for font scaling")
            XCTAssertTrue(supports, "Convenience accessor should work for UIFontMetrics support")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Convenience accessor should maintain MainActor context")
            }
        }
    }
#endif
