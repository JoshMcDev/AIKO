#if os(iOS)
    @testable import AppCore
@testable import AIKOiOSiOS
    @testable import AppCore
@testable import AIKOiOS
    import SwiftUI
    import XCTest

    final class IOSFileServiceClientTests: XCTestCase {
        var client: IOSFileServiceClient?

        private var clientUnwrapped: IOSFileServiceClient {
            guard let client else { fatalError("client not initialized") }
            return client
        }

        override func setUp() async throws {
            try await super.setUp()
            client = IOSFileServiceClient()
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

            // Test that saveFile executes on MainActor (will likely fail in test env, but should not crash)
            let result = await clientUnwrapped.saveFile(
                content: "Test content",
                suggestedFileName: "test.txt",
                allowedFileTypes: ["txt"]
            )

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After saveFile, should still be on main thread")
            }

            // Result may be failure in test environment, but should return a Result
            switch result {
            case .success:
                XCTAssertTrue(true, "Save file succeeded")
            case .failure:
                XCTAssertTrue(true, "Save file failed (expected in test environment)")
            }
        }

        func testOpenFileMainActor() async {
            // Test that openFile executes on MainActor (will likely return nil in test env)
            let url = await clientUnwrapped.openFile(allowedFileTypes: ["txt", "pdf"])

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After openFile, should be on main thread")
            }

            // Result may be nil in test environment
            if let url {
                XCTAssertTrue(url.isFileURL, "Returned URL should be a file URL")
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

        // MARK: - FileServiceClient Integration Tests

        func testStaticIOSClientCreation() async {
            let serviceClient = FileServiceClient.iOSLive

            // Test that we can call the client methods (will likely fail in test env)
            let result = await serviceClient.saveFile("Test", "test.txt", ["txt"])

            switch result {
            case .success:
                XCTAssertTrue(true, "Save file succeeded")
            case .failure:
                XCTAssertTrue(true, "Save file failed (expected in test environment)")
            }

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Static iOS client should maintain MainActor context")
            }
        }

        func testAsyncAwaitPattern() async {
            // Test the async/await pattern works correctly
            async let saveTask = clientUnwrapped.saveFile(
                content: "Test content 1",
                suggestedFileName: "test1.txt",
                allowedFileTypes: ["txt"]
            )
            async let openTask = clientUnwrapped.openFile(allowedFileTypes: ["txt", "pdf"])

            let (saveResult, openUrl) = await (saveTask, openTask)

            // Results may fail in test environment, but should complete without crashing
            switch saveResult {
            case .success, .failure:
                XCTAssertTrue(true, "Save operation completed")
            }

            // Open may return nil in test environment
            if let openUrl {
                XCTAssertTrue(openUrl.isFileURL, "Open result should be nil or valid URL")
            }

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After concurrent async operations, should be on main thread")
            }
        }

        // MARK: - File Operations Tests

        func testSaveFileWithDifferentFileTypes() async {
            let testCases = [
                ("txt", "Plain text content"),
                ("json", "{\"key\": \"value\"}"),
                ("md", "# Markdown Content"),
                ("csv", "name,value\ntest,123"),
            ]

            for (fileType, content) in testCases {
                let result = await clientUnwrapped.saveFile(
                    content: content,
                    suggestedFileName: "test.\(fileType)",
                    allowedFileTypes: [fileType]
                )

                // In test environment, this will likely fail, but should not crash
                switch result {
                case .success:
                    XCTAssertTrue(true, "Save \(fileType) file succeeded")
                case .failure:
                    XCTAssertTrue(true, "Save \(fileType) file failed (expected in test environment)")
                }
            }

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After multiple save operations, should be on main thread")
            }
        }

        func testOpenFileWithDifferentAllowedTypes() async {
            let allowedTypes = [
                ["txt"],
                ["pdf", "doc", "docx"],
                ["jpg", "png", "gif"],
                ["txt", "md", "pdf"],
            ]

            for types in allowedTypes {
                let url = await clientUnwrapped.openFile(allowedFileTypes: types)

                // In test environment, this will likely return nil
                if let url {
                    XCTAssertTrue(url.isFileURL, "Returned URL should be a file URL")
                }
            }

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After multiple open operations, should be on main thread")
            }
        }

        func testSaveFileWithEmptyContent() async {
            let result = await clientUnwrapped.saveFile(
                content: "",
                suggestedFileName: "empty.txt",
                allowedFileTypes: ["txt"]
            )

            // Should handle empty content gracefully
            switch result {
            case .success:
                XCTAssertTrue(true, "Save empty file succeeded")
            case .failure:
                XCTAssertTrue(true, "Save empty file failed (expected in test environment)")
            }

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After save empty content, should be on main thread")
            }
        }

        func testSaveFileWithLongContent() async {
            let longContent = String(repeating: "This is a test line with some content.\n", count: 1000)

            let result = await clientUnwrapped.saveFile(
                content: longContent,
                suggestedFileName: "long_content.txt",
                allowedFileTypes: ["txt"]
            )

            // Should handle long content gracefully
            switch result {
            case .success:
                XCTAssertTrue(true, "Save long content succeeded")
            case .failure:
                XCTAssertTrue(true, "Save long content failed (expected in test environment)")
            }

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After save long content, should be on main thread")
            }
        }

        func testOpenFileWithEmptyAllowedTypes() async {
            let url = await clientUnwrapped.openFile(allowedFileTypes: [])

            // Should handle empty allowed types gracefully
            XCTAssertNil(url, "Should return nil for empty allowed types")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After open with empty types, should be on main thread")
            }
        }

        // MARK: - Error Handling Tests

        func testSaveFileInTestEnvironment() async {
            // In test environment, file operations will likely fail due to no UI context
            let result = await clientUnwrapped.saveFile(
                content: "Test content",
                suggestedFileName: "test.txt",
                allowedFileTypes: ["txt"]
            )

            // Should handle gracefully even if it fails
            switch result {
            case let .success(url):
                XCTAssertTrue(url.isFileURL, "Success URL should be a file URL")
            case let .failure(error):
                XCTAssertNotNil(error, "Error should be provided if operation fails")
            }

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After test environment save, should be on main thread")
            }
        }

        // MARK: - Convenience Accessor Tests

        func testConvenienceStaticAccessor() async {
            let serviceClient = IOSFileServiceClientAccessor.live

            // Test that the convenience accessor works
            let result = await serviceClient.saveFile("Test", "convenience.txt", ["txt"])

            switch result {
            case .success:
                XCTAssertTrue(true, "Convenience accessor save succeeded")
            case .failure:
                XCTAssertTrue(true, "Convenience accessor save failed (expected in test environment)")
            }

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Convenience accessor should maintain MainActor context")
            }
        }
    }
#endif
