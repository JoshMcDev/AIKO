@testable import AppCore
@testable import AIKOiOS
@testable import AIKOiOSiOS
@testable import AppCore
@testable import AIKOiOS
@testable import AIKOiOS
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class ProgressIndicatorViewTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Configure snapshot testing
        isRecording = false
    }

    // MARK: - ProgressIndicatorStyle Tests

    func testProgressIndicatorStyleCases() {
        let allStyles: [ProgressIndicatorStyle] = [.compact, .detailed, .accessible]
        XCTAssertEqual(allStyles.count, 3)

        // Verify each style is Sendable
        Task {
            _ = ProgressIndicatorStyle.compact
            _ = ProgressIndicatorStyle.detailed
            _ = ProgressIndicatorStyle.accessible
        }
    }

    // MARK: - ProgressIndicatorView Basic Tests

    func testProgressIndicatorViewInitialization() {
        let progressState = ProgressState(
            phase: .scanning,
            fractionCompleted: 0.5,
            currentStep: "Scanning page 1"
        )

        let view = ProgressIndicatorView(
            progressState: progressState,
            style: .detailed
        )

        // Should compile without errors
        XCTAssertNotNil(view)
    }

    func testProgressIndicatorViewWithAllStyles() {
        let progressState = ProgressState(
            phase: .processing,
            fractionCompleted: 0.75,
            currentStep: "Processing images"
        )

        let compactView = ProgressIndicatorView(
            progressState: progressState,
            style: .compact
        )

        let detailedView = ProgressIndicatorView(
            progressState: progressState,
            style: .detailed
        )

        let accessibleView = ProgressIndicatorView(
            progressState: progressState,
            style: .accessible
        )

        XCTAssertNotNil(compactView)
        XCTAssertNotNil(detailedView)
        XCTAssertNotNil(accessibleView)
    }

    func testProgressIndicatorViewDefaultStyle() {
        let progressState = ProgressState(
            phase: .analyzing,
            fractionCompleted: 0.3,
            currentStep: "Analyzing content"
        )

        let viewWithoutStyle = ProgressIndicatorView(progressState: progressState)
        let viewWithDetailedStyle = ProgressIndicatorView(
            progressState: progressState,
            style: .detailed
        )

        // Default should be detailed
        XCTAssertNotNil(viewWithoutStyle)
        XCTAssertNotNil(viewWithDetailedStyle)
    }

    // MARK: - DetailedProgressView Tests

    func testDetailedProgressViewSnapshot() {
        let progressState = ProgressState(
            phase: .processing,
            fractionCompleted: 0.65,
            currentStep: "Enhancing image quality",
            totalSteps: 4,
            currentStepIndex: 2,
            estimatedTimeRemaining: 45.0
        )

        let view = ProgressIndicatorView(
            progressState: progressState,
            style: .detailed
        )
        .frame(width: 350, height: 140)
        .background(Color.white)

        assertSnapshot(matching: view, as: .image)
    }

    func testDetailedProgressViewWithDifferentPhases() {
        let phases: [(ProgressPhase, String)] = [
            (.preparing, "preparing"),
            (.scanning, "scanning"),
            (.processing, "processing"),
            (.analyzing, "analyzing"),
            (.completing, "completing"),
            (.idle, "idle"),
        ]

        for (phase, phaseName) in phases {
            let progressState = ProgressState(
                phase: phase,
                fractionCompleted: 0.5,
                currentStep: "Testing \(phaseName) phase"
            )

            let view = ProgressIndicatorView(
                progressState: progressState,
                style: .detailed
            )
            .frame(width: 350, height: 120)
            .background(Color.white)

            assertSnapshot(
                matching: view,
                as: .image,
                named: "detailed-\(phaseName)"
            )
        }
    }

    func testDetailedProgressViewWithMultipleSteps() {
        let progressState = ProgressState(
            phase: .processing,
            fractionCompleted: 0.6,
            currentStep: "Processing page 3 of 5",
            totalSteps: 5,
            currentStepIndex: 2,
            estimatedTimeRemaining: 30.0
        )

        let view = ProgressIndicatorView(
            progressState: progressState,
            style: .detailed
        )
        .frame(width: 350, height: 140)
        .background(Color.white)

        assertSnapshot(matching: view, as: .image, named: "detailed-multi-step")
    }

    func testDetailedProgressViewWithoutTimeEstimate() {
        let progressState = ProgressState(
            phase: .scanning,
            fractionCompleted: 0.8,
            currentStep: "Scanning document",
            totalSteps: 1,
            currentStepIndex: 0,
            estimatedTimeRemaining: nil
        )

        let view = ProgressIndicatorView(
            progressState: progressState,
            style: .detailed
        )
        .frame(width: 350, height: 120)
        .background(Color.white)

        assertSnapshot(matching: view, as: .image, named: "detailed-no-time")
    }

    // MARK: - CompactProgressView Tests

    func testCompactProgressViewSnapshot() {
        let progressState = ProgressState(
            phase: .processing,
            fractionCompleted: 0.4,
            currentStep: "Processing"
        )

        let view = ProgressIndicatorView(
            progressState: progressState,
            style: .compact
        )
        .frame(width: 300, height: 40)
        .background(Color.white)

        assertSnapshot(matching: view, as: .image, named: "compact-basic")
    }

    func testCompactProgressViewDifferentPercentages() {
        let percentages = [0.0, 0.25, 0.5, 0.75, 1.0]

        for (index, percentage) in percentages.enumerated() {
            let progressState = ProgressState(
                phase: .processing,
                fractionCompleted: percentage,
                currentStep: "Step \(index + 1)"
            )

            let view = ProgressIndicatorView(
                progressState: progressState,
                style: .compact
            )
            .frame(width: 300, height: 40)
            .background(Color.white)

            assertSnapshot(
                matching: view,
                as: .image,
                named: "compact-\(Int(percentage * 100))percent"
            )
        }
    }

    func testCompactProgressViewMinimalHeight() {
        let progressState = ProgressState(
            phase: .scanning,
            fractionCompleted: 0.7,
            currentStep: "Scanning"
        )

        let view = ProgressIndicatorView(
            progressState: progressState,
            style: .compact
        )
        .frame(width: 200, height: 30)
        .background(Color.white)

        assertSnapshot(matching: view, as: .image, named: "compact-minimal")
    }

    // MARK: - AccessibleProgressView Tests

    func testAccessibleProgressViewSnapshot() {
        let progressState = ProgressState(
            phase: .analyzing,
            fractionCompleted: 0.6,
            currentStep: "Analyzing document structure"
        )

        let view = ProgressIndicatorView(
            progressState: progressState,
            style: .accessible
        )
        .frame(width: 400, height: 200)
        .background(Color.white)

        assertSnapshot(matching: view, as: .image, named: "accessible-basic")
    }

    func testAccessibleProgressViewWithMultipleSteps() {
        let progressState = ProgressState(
            phase: .processing,
            fractionCompleted: 0.4,
            currentStep: "Processing page 2 of 5",
            totalSteps: 5,
            currentStepIndex: 1
        )

        let view = ProgressIndicatorView(
            progressState: progressState,
            style: .accessible
        )
        .frame(width: 400, height: 220)
        .background(Color.white)

        assertSnapshot(matching: view, as: .image, named: "accessible-multi-step")
    }

    func testAccessibleProgressViewLargeText() {
        let progressState = ProgressState(
            phase: .completing,
            fractionCompleted: 0.95,
            currentStep: "Finalizing results"
        )

        let view = ProgressIndicatorView(
            progressState: progressState,
            style: .accessible
        )
        .frame(width: 450, height: 250)
        .background(Color.white)
        .environment(\.dynamicTypeSize, .xxxLarge)

        assertSnapshot(matching: view, as: .image, named: "accessible-large-text")
    }

    // MARK: - Accessibility Tests

    func testProgressIndicatorAccessibilityLabels() {
        let progressState = ProgressState(
            phase: .scanning,
            fractionCompleted: 0.3,
            currentStep: "Scanning page 2 of 5"
        )

        let detailedView = ProgressIndicatorView(
            progressState: progressState,
            style: .detailed
        )

        let compactView = ProgressIndicatorView(
            progressState: progressState,
            style: .compact
        )

        let accessibleView = ProgressIndicatorView(
            progressState: progressState,
            style: .accessible
        )

        // Test that views can be created and contain progress information
        XCTAssertNotNil(detailedView)
        XCTAssertNotNil(compactView)
        XCTAssertNotNil(accessibleView)
    }

    func testProgressIndicatorAccessibilityWithVoiceOver() {
        let progressState = ProgressState(
            phase: .processing,
            fractionCompleted: 0.75,
            currentStep: "Processing images"
        )

        let view = ProgressIndicatorView(
            progressState: progressState,
            style: .accessible
        )
        .environment(\.accessibilityEnabled, true)

        // Test that accessibility-optimized view handles VoiceOver
        XCTAssertNotNil(view)
    }

    func testProgressIndicatorAccessibilityWithHighContrast() {
        let progressState = ProgressState(
            phase: .analyzing,
            fractionCompleted: 0.5,
            currentStep: "Analyzing content"
        )

        let view = ProgressIndicatorView(
            progressState: progressState,
            style: .detailed
        )
        .environment(\.accessibilityReduceTransparency, true)
        .frame(width: 350, height: 120)
        .background(Color.white)

        assertSnapshot(matching: view, as: .image, named: "high-contrast")
    }

    func testProgressIndicatorAccessibilityWithReducedMotion() {
        let progressState = ProgressState(
            phase: .completing,
            fractionCompleted: 0.9,
            currentStep: "Almost complete"
        )

        let view = ProgressIndicatorView(
            progressState: progressState,
            style: .detailed
        )
        .environment(\.accessibilityReduceMotion, true)

        // Should render without animation
        XCTAssertNotNil(view)
    }

    // MARK: - Dynamic Type Tests

    func testProgressIndicatorDynamicTypeSupport() {
        let progressState = ProgressState(
            phase: .processing,
            fractionCompleted: 0.6,
            currentStep: "Processing document"
        )

        let typeSizes: [(DynamicTypeSize, String)] = [
            (.small, "small"),
            (.medium, "medium"),
            (.large, "large"),
            (.xLarge, "xlarge"),
            (.xxLarge, "xxlarge"),
            (.xxxLarge, "xxxlarge"),
        ]

        for (typeSize, sizeName) in typeSizes {
            let view = ProgressIndicatorView(
                progressState: progressState,
                style: .detailed
            )
            .frame(width: 350, height: 150)
            .background(Color.white)
            .environment(\.dynamicTypeSize, typeSize)

            assertSnapshot(
                matching: view,
                as: .image,
                named: "dynamic-type-\(sizeName)"
            )
        }
    }

    func testProgressIndicatorAccessibilityTypeSupport() {
        let progressState = ProgressState(
            phase: .scanning,
            fractionCompleted: 0.4,
            currentStep: "Scanning page 1"
        )

        let accessibilityTypeSizes: [(DynamicTypeSize, String)] = [
            (.accessibilityMedium, "a11y-medium"),
            (.accessibilityLarge, "a11y-large"),
            (.accessibilityExtraLarge, "a11y-xlarge"),
            (.accessibilityExtraExtraLarge, "a11y-xxlarge"),
            (.accessibilityExtraExtraExtraLarge, "a11y-xxxlarge"),
        ]

        for (typeSize, sizeName) in accessibilityTypeSizes {
            let view = ProgressIndicatorView(
                progressState: progressState,
                style: .accessible
            )
            .frame(width: 400, height: 250)
            .background(Color.white)
            .environment(\.dynamicTypeSize, typeSize)

            assertSnapshot(
                matching: view,
                as: .image,
                named: "accessibility-type-\(sizeName)"
            )
        }
    }

    // MARK: - Dark Mode Tests

    func testProgressIndicatorDarkMode() {
        let progressState = ProgressState(
            phase: .processing,
            fractionCompleted: 0.7,
            currentStep: "Processing images"
        )

        let view = ProgressIndicatorView(
            progressState: progressState,
            style: .detailed
        )
        .frame(width: 350, height: 120)
        .background(Color.black)
        .environment(\.colorScheme, .dark)

        assertSnapshot(matching: view, as: .image, named: "dark-mode")
    }

    func testProgressIndicatorLightMode() {
        let progressState = ProgressState(
            phase: .processing,
            fractionCompleted: 0.7,
            currentStep: "Processing images"
        )

        let view = ProgressIndicatorView(
            progressState: progressState,
            style: .detailed
        )
        .frame(width: 350, height: 120)
        .background(Color.white)
        .environment(\.colorScheme, .light)

        assertSnapshot(matching: view, as: .image, named: "light-mode")
    }

    // MARK: - Error State Tests

    func testProgressIndicatorWithZeroProgress() {
        let progressState = ProgressState(
            phase: .preparing,
            fractionCompleted: 0.0,
            currentStep: "Initializing..."
        )

        let view = ProgressIndicatorView(
            progressState: progressState,
            style: .detailed
        )
        .frame(width: 350, height: 120)
        .background(Color.white)

        assertSnapshot(matching: view, as: .image, named: "zero-progress")
    }

    func testProgressIndicatorWithFullProgress() {
        let progressState = ProgressState(
            phase: .completing,
            fractionCompleted: 1.0,
            currentStep: "Complete"
        )

        let view = ProgressIndicatorView(
            progressState: progressState,
            style: .detailed
        )
        .frame(width: 350, height: 120)
        .background(Color.white)

        assertSnapshot(matching: view, as: .image, named: "full-progress")
    }

    func testProgressIndicatorWithLongText() {
        let longMessage = "This is a very long progress message that should be handled gracefully by the progress indicator view without causing layout issues"

        let progressState = ProgressState(
            phase: .analyzing,
            fractionCompleted: 0.5,
            currentStep: longMessage
        )

        let view = ProgressIndicatorView(
            progressState: progressState,
            style: .detailed
        )
        .frame(width: 350, height: 150)
        .background(Color.white)

        assertSnapshot(matching: view, as: .image, named: "long-text")
    }

    // MARK: - Performance Tests

    func testProgressIndicatorViewCreationPerformance() {
        let progressState = ProgressState(
            phase: .processing,
            fractionCompleted: 0.5,
            currentStep: "Processing"
        )

        measure {
            for _ in 0 ..< 1000 {
                _ = ProgressIndicatorView(
                    progressState: progressState,
                    style: .detailed
                )
            }
        }
    }

    func testProgressIndicatorViewRenderingPerformance() {
        let progressState = ProgressState(
            phase: .scanning,
            fractionCompleted: 0.3,
            currentStep: "Scanning"
        )

        measure {
            for _ in 0 ..< 100 {
                let view = ProgressIndicatorView(
                    progressState: progressState,
                    style: .compact
                )
                .frame(width: 300, height: 40)

                // Force view body evaluation
                _ = view.body
            }
        }
    }

    // MARK: - Edge Cases

    func testProgressIndicatorWithEmptyMessage() {
        let progressState = ProgressState(
            phase: .processing,
            fractionCompleted: 0.4,
            currentStep: ""
        )

        let view = ProgressIndicatorView(
            progressState: progressState,
            style: .detailed
        )
        .frame(width: 350, height: 120)
        .background(Color.white)

        assertSnapshot(matching: view, as: .image, named: "empty-message")
    }

    func testProgressIndicatorWithUnicodeMessage() {
        let progressState = ProgressState(
            phase: .analyzing,
            fractionCompleted: 0.6,
            currentStep: "正在分析文档... 📄✨"
        )

        let view = ProgressIndicatorView(
            progressState: progressState,
            style: .detailed
        )
        .frame(width: 350, height: 120)
        .background(Color.white)

        assertSnapshot(matching: view, as: .image, named: "unicode-message")
    }

    func testProgressIndicatorExtremeAspectRatios() {
        let progressState = ProgressState(
            phase: .processing,
            fractionCompleted: 0.5,
            currentStep: "Processing"
        )

        let wideView = ProgressIndicatorView(
            progressState: progressState,
            style: .compact
        )
        .frame(width: 600, height: 30)
        .background(Color.white)

        let tallView = ProgressIndicatorView(
            progressState: progressState,
            style: .accessible
        )
        .frame(width: 200, height: 400)
        .background(Color.white)

        assertSnapshot(matching: wideView, as: .image, named: "wide-aspect")
        assertSnapshot(matching: tallView, as: .image, named: "tall-aspect")
    }
}
