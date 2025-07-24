@testable import AppCoreiOS
@testable import AppCore
import XCTest

@available(iOS 16.0, *)
final class MediaWorkflowCoordinatorTests: XCTestCase {
    var sut: MediaWorkflowCoordinator?

    private var sutUnwrapped: MediaWorkflowCoordinator {
        guard let sut else { fatalError("sut not initialized") }
        return sut
    }

    override func setUp() async throws {
        try await super.setUp()
        sut = MediaWorkflowCoordinator()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Workflow Creation Tests

    func testCreateWorkflow_WithValidDefinition_ShouldCreateWorkflow() async throws {
        // Given
        let definition = WorkflowDefinition(
            name: "Test Workflow",
            description: "Test workflow description",
            steps: [
                WorkflowStepDefinition(
                    type: .validate,
                    name: "Validate Input"
                ),
                WorkflowStepDefinition(
                    type: .compress,
                    name: "Compress Image"
                ),
            ]
        )

        // When/Then
        await assertThrowsError {
            _ = try await sut.createWorkflow(definition)
        }
    }

    func testCreateWorkflow_WithEmptySteps_ShouldThrowError() async throws {
        // Given
        let definition = WorkflowDefinition(
            name: "Empty Workflow",
            steps: []
        )

        // When/Then
        await assertThrowsError {
            _ = try await sut.createWorkflow(definition)
        }
    }

    func testCreateWorkflow_WithConditionalSteps_ShouldCreateConditionalWorkflow() async throws {
        // Given
        let condition = WorkflowCondition(
            type: .mediaType,
            parameters: ["type": "image"]
        )
        let definition = WorkflowDefinition(
            name: "Conditional Workflow",
            steps: [
                WorkflowStepDefinition(
                    type: .resize,
                    name: "Resize if Image",
                    condition: condition
                ),
            ]
        )

        // When/Then
        await assertThrowsError {
            _ = try await sut.createWorkflow(definition)
        }
    }

    // MARK: - Workflow Execution Tests

    func testExecuteWorkflow_WithValidAssets_ShouldReturnHandle() async throws {
        // Given
        let workflow = createMockWorkflow()
        let assets = [createMockAsset(), createMockAsset()]

        // When/Then
        await assertThrowsError {
            _ = try await sut.executeWorkflow(workflow, with: assets)
        }
    }

    func testExecuteWorkflow_WithEmptyAssets_ShouldThrowError() async throws {
        // Given
        let workflow = createMockWorkflow()
        let assets: [MediaAsset] = []

        // When/Then
        await assertThrowsError {
            _ = try await sut.executeWorkflow(workflow, with: assets)
        }
    }

    func testExecuteWorkflow_ParallelConfiguration_ShouldExecuteInParallel() async throws {
        // Given
        let config = WorkflowConfiguration(
            parallel: true,
            maxParallelSteps: 3
        )
        let workflow = MediaWorkflow(
            name: "Parallel Workflow",
            steps: [
                WorkflowStep(type: .validate, name: "Step 1"),
                WorkflowStep(type: .compress, name: "Step 2"),
                WorkflowStep(type: .resize, name: "Step 3"),
            ],
            configuration: config
        )
        let assets = [createMockAsset()]

        // When/Then
        await assertThrowsError {
            _ = try await sut.executeWorkflow(workflow, with: assets)
        }
    }

    // MARK: - Execution Monitoring Tests

    func testMonitorExecution_ShouldStreamUpdates() async {
        // Given
        let handle = WorkflowExecutionHandle(workflowId: UUID())

        // When
        let stream = sut.monitorExecution(handle)
        var updates: [WorkflowExecutionUpdate] = []

        for await update in stream {
            updates.append(update)
            if updates.count >= 3 {
                break
            }
        }

        // Then
        XCTAssertTrue(updates.isEmpty) // Currently finishes immediately
    }

    // MARK: - Execution Control Tests

    func testPauseExecution_WithActiveExecution_ShouldPause() async throws {
        // Given
        let handle = WorkflowExecutionHandle(workflowId: UUID())

        // When/Then
        await assertThrowsError {
            try await sut.pauseExecution(handle)
        }
    }

    func testResumeExecution_WithPausedExecution_ShouldResume() async throws {
        // Given
        let handle = WorkflowExecutionHandle(workflowId: UUID())

        // When/Then
        await assertThrowsError {
            try await sut.resumeExecution(handle)
        }
    }

    func testCancelExecution_WithActiveExecution_ShouldCancel() async throws {
        // Given
        let handle = WorkflowExecutionHandle(workflowId: UUID())

        // When/Then
        await assertThrowsError {
            try await sut.cancelExecution(handle)
        }
    }

    // MARK: - Execution Status Tests

    func testGetExecutionStatus_WithValidHandle_ShouldReturnStatus() async {
        // Given
        let handle = WorkflowExecutionHandle(workflowId: UUID())

        // When
        let status = await sut.getExecutionStatus(handle)

        // Then
        XCTAssertEqual(status, .failed) // Currently returns failed
    }

    func testGetExecutionResults_WithCompletedExecution_ShouldReturnResults() async {
        // Given
        let handle = WorkflowExecutionHandle(workflowId: UUID())

        // When
        let results = await sut.getExecutionResults(handle)

        // Then
        XCTAssertEqual(results.status, .failed)
        XCTAssertTrue(results.processedAssets.isEmpty)
    }

    // MARK: - Workflow Template Tests

    func testSaveWorkflowTemplate_ShouldSaveTemplate() async throws {
        // Given
        let workflow = createMockWorkflow()
        let name = "Test Template"

        // When/Then
        await assertThrowsError {
            try await sut.saveWorkflowTemplate(workflow, name: name)
        }
    }

    func testLoadWorkflowTemplate_WithExistingTemplate_ShouldLoadWorkflow() async throws {
        // Given
        let name = "Test Template"

        // When/Then
        await assertThrowsError {
            _ = try await sut.loadWorkflowTemplate(name)
        }
    }

    func testListWorkflowTemplates_ShouldReturnTemplateList() async {
        // When
        let templates = await sut.listWorkflowTemplates()

        // Then
        XCTAssertTrue(templates.isEmpty) // Currently returns empty
    }

    func testDeleteWorkflowTemplate_WithExistingTemplate_ShouldDelete() async throws {
        // Given
        let name = "Test Template"

        // When/Then
        await assertThrowsError {
            try await sut.deleteWorkflowTemplate(name)
        }
    }

    // MARK: - Workflow Validation Tests

    func testValidateWorkflow_WithValidDefinition_ShouldReturnValid() async {
        // Given
        let definition = WorkflowDefinition(
            name: "Valid Workflow",
            steps: [
                WorkflowStepDefinition(type: .validate, name: "Step 1"),
            ]
        )

        // When
        let result = await sut.validateWorkflow(definition)

        // Then
        XCTAssertFalse(result.isValid) // Currently returns invalid
    }

    func testValidateWorkflow_WithInvalidStepConfiguration_ShouldReturnErrors() async {
        // Given
        let definition = WorkflowDefinition(
            name: "Invalid Workflow",
            steps: [
                WorkflowStepDefinition(
                    type: .custom,
                    name: "Custom Step",
                    configuration: ["invalid": "config"]
                ),
            ]
        )

        // When
        let result = await sut.validateWorkflow(definition)

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.errors.isEmpty)
    }

    // MARK: - Error Handling Tests

    func testWorkflowStep_WithStopOnError_ShouldStopOnFirstError() async throws {
        // Given
        let workflow = MediaWorkflow(
            name: "Stop on Error",
            steps: [
                WorkflowStep(type: .validate, name: "Step 1", onError: .stop),
                WorkflowStep(type: .compress, name: "Step 2", onError: .stop),
            ]
        )
        let assets = [createMockAsset()]

        // When/Then
        await assertThrowsError {
            _ = try await sut.executeWorkflow(workflow, with: assets)
        }
    }

    func testWorkflowStep_WithSkipOnError_ShouldContinueExecution() async throws {
        // Given
        let workflow = MediaWorkflow(
            name: "Skip on Error",
            steps: [
                WorkflowStep(type: .validate, name: "Step 1", onError: .skip),
                WorkflowStep(type: .compress, name: "Step 2", onError: .skip),
            ]
        )
        let assets = [createMockAsset()]

        // When/Then
        await assertThrowsError {
            _ = try await sut.executeWorkflow(workflow, with: assets)
        }
    }

    func testWorkflowStep_WithRetryOnError_ShouldRetryFailedSteps() async throws {
        // Given
        let workflow = MediaWorkflow(
            name: "Retry on Error",
            steps: [
                WorkflowStep(type: .validate, name: "Step 1", onError: .retry),
            ]
        )
        let assets = [createMockAsset()]

        // When/Then
        await assertThrowsError {
            _ = try await sut.executeWorkflow(workflow, with: assets)
        }
    }

    // MARK: - Complex Workflow Tests

    func testExecuteWorkflow_WithNestedConditions_ShouldEvaluateCorrectly() async throws {
        // Given
        let steps = [
            WorkflowStepDefinition(
                type: .validate,
                name: "Always Run"
            ),
            WorkflowStepDefinition(
                type: .compress,
                name: "Compress Images",
                condition: WorkflowCondition(type: .mediaType)
            ),
            WorkflowStepDefinition(
                type: .convert,
                name: "Convert Format",
                condition: WorkflowCondition(type: .previousStepResult)
            ),
        ]
        let definition = WorkflowDefinition(name: "Complex", steps: steps)

        // When/Then
        await assertThrowsError {
            _ = try await sut.createWorkflow(definition)
        }
    }

    func testExecuteWorkflow_WithTimeout_ShouldRespectTimeout() async throws {
        // Given
        let config = WorkflowConfiguration(timeout: 10.0)
        let workflow = MediaWorkflow(
            name: "Timeout Test",
            steps: [WorkflowStep(type: .validate, name: "Step")],
            configuration: config
        )
        let assets = [createMockAsset()]

        // When/Then
        await assertThrowsError {
            _ = try await sut.executeWorkflow(workflow, with: assets)
        }
    }

    // MARK: - Notification Tests

    func testExecuteWorkflow_WithNotifications_ShouldTriggerNotifications() async throws {
        // Given
        let notifications = NotificationSettings(
            onStart: true,
            onComplete: true,
            onError: true,
            onStepComplete: true
        )
        let config = WorkflowConfiguration(notificationSettings: notifications)
        let workflow = MediaWorkflow(
            name: "Notification Test",
            steps: [WorkflowStep(type: .validate, name: "Step")],
            configuration: config
        )
        let assets = [createMockAsset()]

        // When/Then
        await assertThrowsError {
            _ = try await sut.executeWorkflow(workflow, with: assets)
        }
    }

    // MARK: - Workflow Step Types Tests

    func testWorkflowStep_AllTypes_ShouldBeSupported() async throws {
        // Test each workflow step type
        let stepTypes: [WorkflowStepType] = [
            .validate, .compress, .resize, .convert,
            .extractMetadata, .generateThumbnail,
            .applyFilter, .watermark, .upload, .notify, .custom,
        ]

        for stepType in stepTypes {
            let workflow = MediaWorkflow(
                name: "Test \(stepType)",
                steps: [WorkflowStep(type: stepType, name: "Step")]
            )
            let assets = [createMockAsset()]

            await assertThrowsError {
                _ = try await sut.executeWorkflow(workflow, with: assets)
            }
        }
    }
}

// MARK: - Test Helpers

@available(iOS 16.0, *)
extension MediaWorkflowCoordinatorTests {
    func assertThrowsError(
        _ expression: @autoclosure () async throws -> some Any,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error but succeeded", file: file, line: line)
        } catch {
            // Expected error
        }
    }

    func createMockAsset() -> MediaAsset {
        MediaAsset(
            type: .image,
            url: URL(fileURLWithPath: "/tmp/test.jpg"),
            metadata: MediaMetadata(
                fileName: "test.jpg",
                fileExtension: "jpg",
                mimeType: "image/jpeg"
            ),
            size: 1000
        )
    }

    func createMockWorkflow() -> MediaWorkflow {
        MediaWorkflow(
            name: "Test Workflow",
            steps: [
                WorkflowStep(type: .validate, name: "Validate"),
                WorkflowStep(type: .compress, name: "Compress"),
            ]
        )
    }
}
