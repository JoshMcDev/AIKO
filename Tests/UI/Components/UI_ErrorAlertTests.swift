@testable import AppCore
import ComposableArchitecture
import XCTest

@MainActor
final class ErrorAlertTests: XCTestCase {
    // MARK: - Test Metrics

    struct TestMetrics {
        var mop: Double = 0.0 // Measure of Performance
        var moe: Double = 0.0 // Measure of Effectiveness

        var overallScore: Double { (mop + moe) / 2.0 }
        var passed: Bool { overallScore >= 0.8 }
    }

    // MARK: - Unit Tests

    func testErrorAlertPresentation() async throws {
        var metrics = TestMetrics()

        let store = TestStore(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        )

        let startTime = Date()
        let testError = "Failed to load acquisition data"

        // Send error action
        await store.send(.loadAcquisitionError(testError)) { state in
            // Verify alert is presented
            XCTAssertNotNil(state.errorAlert)
            XCTAssertEqual(state.errorAlert?.title, TextState("Failed to Load Acquisition"))
            XCTAssertEqual(state.errorAlert?.message, TextState(testError))

            // MOE: Alert correctly configured
            metrics.moe = state.errorAlert != nil ? 1.0 : 0.0
        }

        let endTime = Date()

        // MOP: Alert presentation speed
        let timeTaken = endTime.timeIntervalSince(startTime)
        metrics.mop = timeTaken < 0.1 ? 1.0 : max(0, 1.0 - timeTaken * 10)

        XCTAssertTrue(metrics.passed, "Error alert presentation failed with score: \(metrics.overallScore)")
        print(" Alert Presentation - MOP: \(metrics.mop), MOE: \(metrics.moe), Score: \(metrics.overallScore)")
    }

    func testErrorAlertDismissal() async throws {
        var metrics = TestMetrics()

        let store = TestStore(
            initialState: AppFeature.State(
                errorAlert: AlertState {
                    TextState("Test Error")
                } actions: {
                    ButtonState(action: .dismiss) {
                        TextState("OK")
                    }
                } message: {
                    TextState("Test error message")
                }
            ),
            reducer: { AppFeature() }
        )

        let startTime = Date()

        // Test dismissal
        await store.send(.errorAlert(.dismiss)) { state in
            // Verify alert is dismissed
            XCTAssertNil(state.errorAlert)
            metrics.moe = state.errorAlert == nil ? 1.0 : 0.0
        }

        let endTime = Date()

        // MOP: Dismissal speed
        let timeTaken = endTime.timeIntervalSince(startTime)
        metrics.mop = timeTaken < 0.05 ? 1.0 : max(0, 1.0 - timeTaken * 20)

        XCTAssertTrue(metrics.passed, "Alert dismissal failed with score: \(metrics.overallScore)")
        print(" Alert Dismissal - MOP: \(metrics.mop), MOE: \(metrics.moe), Score: \(metrics.overallScore)")
    }

    func testMultipleErrorScenarios() async throws {
        var metrics = TestMetrics()
        var totalMOP = 0.0
        var totalMOE = 0.0

        let errorScenarios = [
            "Network connection failed",
            "Invalid acquisition data",
            "Core Data save error",
            "Authentication failed",
            "Document generation timeout",
        ]

        for (index, errorMessage) in errorScenarios.enumerated() {
            let store = TestStore(
                initialState: AppFeature.State(),
                reducer: { AppFeature() }
            )

            let startTime = Date()

            // Test each error scenario
            await store.send(.loadAcquisitionError(errorMessage)) { state in
                let hasAlert = state.errorAlert != nil
                let correctMessage = state.errorAlert?.message == TextState(errorMessage)
                totalMOE += (hasAlert && correctMessage) ? 1.0 : 0.0
            }

            let endTime = Date()
            let timeTaken = endTime.timeIntervalSince(startTime)
            totalMOP += timeTaken < 0.1 ? 1.0 : max(0, 1.0 - timeTaken * 10)

            print("  Scenario \(index + 1): \(errorMessage) ✓")
        }

        // Calculate average metrics
        metrics.mop = totalMOP / Double(errorScenarios.count)
        metrics.moe = totalMOE / Double(errorScenarios.count)

        XCTAssertTrue(metrics.passed, "Multiple error scenarios failed with score: \(metrics.overallScore)")
        print(" Multiple Scenarios - MOP: \(metrics.mop), MOE: \(metrics.moe), Score: \(metrics.overallScore)")
    }

    // MARK: - Integration Tests

    func testErrorAlertWithUserInteraction() async throws {
        var metrics = TestMetrics()

        let store = TestStore(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        )

        // Simulate full error flow
        let testError = "Critical system error occurred"
        var interactionSteps = 0
        let startTime = Date()

        // Step 1: Error occurs
        await store.send(.loadAcquisitionError(testError)) { state in
            XCTAssertNotNil(state.errorAlert)
            interactionSteps += 1
        }

        // Step 2: User sees alert (simulated delay)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Step 3: User dismisses alert
        await store.send(.errorAlert(.dismiss)) { state in
            XCTAssertNil(state.errorAlert)
            interactionSteps += 1
        }

        let endTime = Date()

        // MOP: Complete interaction speed
        let totalTime = endTime.timeIntervalSince(startTime)
        metrics.mop = totalTime < 0.5 ? 1.0 : max(0, 1.0 - (totalTime - 0.5) * 2)

        // MOE: All steps completed successfully
        metrics.moe = interactionSteps == 2 ? 1.0 : Double(interactionSteps) / 2.0

        XCTAssertTrue(metrics.passed, "User interaction test failed with score: \(metrics.overallScore)")
        print(" User Interaction - MOP: \(metrics.mop), MOE: \(metrics.moe), Score: \(metrics.overallScore)")
    }

    // MARK: - Stress Tests

    func testRapidErrorAlerts() async throws {
        var metrics = TestMetrics()

        let store = TestStore(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        )

        let startTime = Date()
        var successfulAlerts = 0
        let totalAlerts = 10

        // Rapidly show and dismiss alerts
        for i in 0 ..< totalAlerts {
            let errorMessage = "Rapid error \(i + 1)"

            await store.send(.loadAcquisitionError(errorMessage)) { state in
                if state.errorAlert?.message == TextState(errorMessage) {
                    successfulAlerts += 1
                }
            }

            await store.send(.errorAlert(.dismiss)) { state in
                XCTAssertNil(state.errorAlert)
            }
        }

        let endTime = Date()

        // MOP: Handling rapid alerts
        let totalTime = endTime.timeIntervalSince(startTime)
        let avgTimePerAlert = totalTime / Double(totalAlerts)
        metrics.mop = avgTimePerAlert < 0.1 ? 1.0 : max(0, 1.0 - (avgTimePerAlert - 0.1) * 10)

        // MOE: All alerts handled correctly
        metrics.moe = Double(successfulAlerts) / Double(totalAlerts)

        XCTAssertTrue(metrics.passed, "Rapid alerts test failed with score: \(metrics.overallScore)")
        print(" Rapid Alerts - MOP: \(metrics.mop), MOE: \(metrics.moe), Score: \(metrics.overallScore)")
    }
}
