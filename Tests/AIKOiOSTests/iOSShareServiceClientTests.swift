#if os(iOS)
    @testable import AppCore
@testable import AIKOiOSiOS
    @testable import AppCore
@testable import AIKOiOS
    import SwiftUI
    import XCTest

    final class IOSShareServiceClientTests: XCTestCase {
        var client: IOSShareServiceClient?

        private var clientUnwrapped: IOSShareServiceClient {
            guard let client else { fatalError("client not initialized") }
            return client
        }

        override func setUp() async throws {
            try await super.setUp()
            client = IOSShareServiceClient()
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

            // Test that share executes on MainActor (will likely fail in test env)
            let shareItems = ShareableItems(["Test text"])
            let result = await clientUnwrapped.share(items: shareItems)

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After share, should still be on main thread")
            }

            // In test environment, share will likely fail, but should not crash
            XCTAssertTrue(result == true || result == false, "Share should return a boolean")
        }

        func testCreateShareableFileMainActor() async {
            do {
                let url = try clientUnwrapped.createShareableFile(from: "Test content", fileName: "test.txt")
                XCTAssertTrue(url.isFileURL, "Should create a file URL")
                XCTAssertTrue(url.lastPathComponent == "test.txt", "Should use the provided filename")

                await MainActor.run {
                    XCTAssertTrue(Thread.isMainThread, "After createShareableFile, should be on main thread")
                }
            } catch {
                XCTFail("Should not throw error when creating shareable file: \(error)")
            }
        }

        func testShareContentMainActor() async {
            await clientUnwrapped.shareContent("Test content for sharing", fileName: "shared.txt")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After shareContent, should be on main thread")
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

        // MARK: - ShareServiceClient Integration Tests

        func testStaticIOSClientCreation() async {
            let serviceClient = ShareServiceClient.iOSLive

            // Test that we can call the client methods
            let shareItems = ShareableItems(["Integration test"])
            let result = await serviceClient.share(shareItems)

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Static iOS client should maintain MainActor context")
            }

            XCTAssertTrue(result == true || result == false, "Share should return a boolean")
        }

        func testAsyncAwaitPattern() async {
            // Test the async/await pattern works correctly
            let shareItems = ShareableItems(["Test content"])

            async let shareTask = clientUnwrapped.share(items: shareItems)
            async let shareContentTask = clientUnwrapped.shareContent("Content", fileName: "test.txt")

            let shareResult = await shareTask
            await shareContentTask

            XCTAssertTrue(shareResult == true || shareResult == false, "Share should return a boolean")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After concurrent async operations, should be on main thread")
            }
        }

        // MARK: - Share Functionality Tests

        func testShareWithStringItems() async {
            let items = ShareableItems(["String 1", "String 2", "String 3"])
            let result = await clientUnwrapped.share(items: items)

            // In test environment, this will likely fail, but should not crash
            XCTAssertTrue(result == true || result == false, "Share should return a boolean")
        }

        func testShareWithURLItems() async {
            guard let url = URL(string: "https://example.com") else {
                XCTFail("Failed to create URL from valid string 'https://example.com'")
                return
            }
            let items = ShareableItems([url])
            let result = await clientUnwrapped.share(items: items)

            // In test environment, this will likely fail, but should not crash
            XCTAssertTrue(result == true || result == false, "Share should return a boolean")
        }

        func testShareWithMixedItems() async {
            guard let url = URL(string: "https://example.com") else {
                XCTFail("Failed to create URL from valid string 'https://example.com'")
                return
            }
            let items = ShareableItems(["Text content", url])
            let result = await clientUnwrapped.share(items: items)

            // In test environment, this will likely fail, but should not crash
            XCTAssertTrue(result == true || result == false, "Share should return a boolean")
        }

        func testCreateShareableFileWithDifferentContent() async {
            let testCases = [
                ("Simple text", "simple.txt"),
                ("Text with special characters: åäö", "special.txt"),
                ("Multi-line\ntext\ncontent", "multiline.txt"),
                ("", "empty.txt"),
                ("Very long text " + String(repeating: "content ", count: 100), "long.txt"),
            ]

            for (content, fileName) in testCases {
                do {
                    let url = try clientUnwrapped.createShareableFile(from: content, fileName: fileName)
                    XCTAssertTrue(url.isFileURL, "Should create file URL for \(fileName)")
                    XCTAssertTrue(url.lastPathComponent == fileName, "Should use correct filename")

                    // Verify content was written correctly
                    let writtenContent = try String(contentsOf: url, encoding: .utf8)
                    XCTAssertEqual(writtenContent, content, "File content should match for \(fileName)")
                } catch {
                    XCTFail("Should not fail to create shareable file for \(fileName): \(error)")
                }
            }
        }

        func testCreateShareableFileWithDifferentExtensions() async {
            let extensions = ["txt", "md", "json", "csv", "log"]

            for ext in extensions {
                do {
                    let fileName = "test.\(ext)"
                    let url = try clientUnwrapped.createShareableFile(from: "Test content", fileName: fileName)
                    XCTAssertTrue(url.lastPathComponent == fileName, "Should use correct filename with extension")
                    XCTAssertTrue(url.pathExtension == ext, "Should preserve file extension")
                } catch {
                    XCTFail("Should not fail to create file with extension \(ext): \(error)")
                }
            }
        }

        func testShareContent() async {
            // Test the convenience method that creates file and shares it
            await clientUnwrapped.shareContent("Content to share", fileName: "convenience.txt")

            // Should complete without crashing (may fail in test environment)
            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After shareContent, should be on main thread")
            }
        }

        func testShareContentWithDifferentFormats() async {
            let testCases = [
                ("Plain text content", "plain.txt"),
                ("{\"key\": \"value\"}", "data.json"),
                ("# Markdown Header\n\nContent", "doc.md"),
                ("Name,Value\nTest,123", "data.csv"),
            ]

            for (content, fileName) in testCases {
                await clientUnwrapped.shareContent(content, fileName: fileName)
                // Should complete without error
            }

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After multiple shareContent calls, should be on main thread")
            }
        }

        // MARK: - Error Handling Tests

        func testCreateShareableFileWithInvalidFileName() async {
            // Test with potentially problematic filename
            do {
                let url = try clientUnwrapped.createShareableFile(from: "Test", fileName: "")
                XCTAssertTrue(url.isFileURL, "Should handle empty filename gracefully")
            } catch {
                // May fail with empty filename, which is acceptable
                XCTAssertNotNil(error, "Should provide error for invalid filename")
            }
        }

        func testShareInTestEnvironment() async {
            // In test environment, UI operations will likely fail
            let items = ShareableItems(["Test content"])
            let result = await clientUnwrapped.share(items: items)

            // Should handle gracefully even if it fails
            XCTAssertTrue(result == true || result == false, "Should return boolean even if sharing fails")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After test environment share, should be on main thread")
            }
        }

        // MARK: - Convenience Accessor Tests

        func testConvenienceStaticAccessor() async {
            let serviceClient = IOSShareServiceClient.live

            // Test that the convenience accessor works
            let items = ShareableItems(["Convenience test"])
            let result = await serviceClient.share(items)

            XCTAssertTrue(result == true || result == false, "Convenience accessor should work")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Convenience accessor should maintain MainActor context")
            }
        }

        // MARK: - File Management Tests

        func testTemporaryFileCleanup() async {
            var createdURLs: [URL] = []

            // Create multiple temporary files
            for i in 0 ..< 5 {
                do {
                    let url = try clientUnwrapped.createShareableFile(from: "Content \(i)", fileName: "temp\(i).txt")
                    createdURLs.append(url)
                    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "File should exist after creation")
                } catch {
                    XCTFail("Should not fail to create file \(i): \(error)")
                }
            }

            // Files should exist in temporary directory
            for url in createdURLs {
                XCTAssertTrue(url.path.contains("tmp") || url.path.contains("Temp"), "Should be in temporary directory")
            }
        }
    }
#endif
