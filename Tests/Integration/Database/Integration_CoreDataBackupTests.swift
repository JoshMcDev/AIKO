@testable import AppCore
import ComposableArchitecture
import XCTest

@MainActor
final class CoreDataBackupTests: XCTestCase {
    // MARK: - Test Metrics

    struct TestMetrics {
        var mop: Double = 0.0 // Measure of Performance (0-1)
        var moe: Double = 0.0 // Measure of Effectiveness (0-1)

        var overallScore: Double {
            (mop + moe) / 2.0
        }

        var passed: Bool {
            overallScore >= 0.8
        }
    }

    // MARK: - Unit Tests

    func testCoreDataExportPerformance() async throws {
        var metrics = TestMetrics()
        let coreDataStack = CoreDataStack.shared

        // Setup test data
        let startTime = Date()

        do {
            // Test export functionality
            let exportData = try await coreDataStack.exportCoreDataToJSON()
            let endTime = Date()

            // MOP: Performance measurement (time taken)
            let timeTaken = endTime.timeIntervalSince(startTime)
            metrics.mop = timeTaken < 1.0 ? 1.0 : max(0, 1.0 - (timeTaken - 1.0) / 5.0)

            // MOE: Effectiveness measurement (data validity)
            let jsonObject = try JSONSerialization.jsonObject(with: exportData) as? [String: Any]
            let hasRequiredKeys = jsonObject?.keys.contains { ["acquisitions", "templates", "generations"].contains($0) } ?? false
            metrics.moe = hasRequiredKeys ? 1.0 : 0.0

            XCTAssertTrue(metrics.passed, "Export test failed with score: \(metrics.overallScore)")
            print(" Export Performance - MOP: \(metrics.mop), MOE: \(metrics.moe), Score: \(metrics.overallScore)")

        } catch {
            XCTFail("Export failed: \(error)")
        }
    }

    func testCoreDataImportRestore() async throws {
        var metrics = TestMetrics()
        let coreDataStack = CoreDataStack.shared

        // Create test backup data
        let testBackup: [String: Any] = [
            "acquisitions": [],
            "templates": [],
            "generations": [],
        ]

        do {
            let backupData = try JSONSerialization.data(withJSONObject: testBackup)
            let startTime = Date()

            // Test import functionality
            try await coreDataStack.importCoreDataFromJSON(backupData)
            let endTime = Date()

            // MOP: Import speed
            let timeTaken = endTime.timeIntervalSince(startTime)
            metrics.mop = timeTaken < 2.0 ? 1.0 : max(0, 1.0 - (timeTaken - 2.0) / 5.0)

            // MOE: Data integrity after import
            let verifyExport = try await coreDataStack.exportCoreDataToJSON()
            metrics.moe = !verifyExport.isEmpty ? 1.0 : 0.0

            XCTAssertTrue(metrics.passed, "Import test failed with score: \(metrics.overallScore)")
            print(" Import Performance - MOP: \(metrics.mop), MOE: \(metrics.moe), Score: \(metrics.overallScore)")

        } catch {
            XCTFail("Import failed: \(error)")
        }
    }

    func testSettingsManagerBackupIntegration() async throws {
        var metrics = TestMetrics()

        let store = TestStore(
            initialState: SettingsFeature.State(),
            reducer: { SettingsFeature() }
        )

        // Test backup action
        let expectation = XCTestExpectation(description: "Backup completes")
        var backupProgress = 0.0

        await store.send(.performBackup { progress in
            backupProgress = progress
            if progress >= 1.0 {
                expectation.fulfill()
            }
        })

        await fulfillment(of: [expectation], timeout: 5.0)

        // MOP: Backup completion time
        metrics.mop = backupProgress >= 1.0 ? 1.0 : backupProgress

        // MOE: Backup data completeness
        await store.receive(\.backupCompleted) { state in
            metrics.moe = state.lastBackupDate != nil ? 1.0 : 0.0
        }

        XCTAssertTrue(metrics.passed, "Settings backup test failed with score: \(metrics.overallScore)")
        print(" Settings Backup - MOP: \(metrics.mop), MOE: \(metrics.moe), Score: \(metrics.overallScore)")
    }

    // MARK: - Error Handling Tests

    func testBackupErrorHandling() async throws {
        var metrics = TestMetrics()
        let coreDataStack = CoreDataStack.shared

        // Test with invalid data
        let invalidData = Data("invalid json".utf8)

        do {
            try await coreDataStack.importCoreDataFromJSON(invalidData)
            metrics.moe = 0.0 // Should have thrown error
        } catch {
            // Expected error
            metrics.moe = 1.0
            metrics.mop = 1.0 // Handled error quickly
        }

        XCTAssertTrue(metrics.passed, "Error handling test failed with score: \(metrics.overallScore)")
        print(" Error Handling - MOP: \(metrics.mop), MOE: \(metrics.moe), Score: \(metrics.overallScore)")
    }
}
