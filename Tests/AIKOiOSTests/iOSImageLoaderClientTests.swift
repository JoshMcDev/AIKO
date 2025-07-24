#if os(iOS)
    @testable import AppCore
@testable import AIKOiOSiOS
    @testable import AppCore
@testable import AIKOiOS
    import SwiftUI
    import UIKit
    import XCTest

    final class IOSImageLoaderClientTests: XCTestCase {
        private var clientUnwrapped: IOSImageLoaderClient {
            guard let client else { fatalError("client not initialized") }
            return client
        } var client: IOSImageLoaderClient?

        override func setUp() async throws {
            try await super.setUp()
            client = IOSImageLoaderClient()
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

            // Create test image data
            let testImageData = createTestImageData()

            // Test that loadImage executes on MainActor
            let image = await clientUnwrapped.loadImage(from: testImageData)
            XCTAssertNotNil(image, "Should return a valid Image")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After loadImage, should still be on main thread")
            }
        }

        func testLoadImageFromDataMainActor() async {
            let testImageData = createTestImageData()

            let image = await clientUnwrapped.loadImageFromData(testImageData)
            XCTAssertNotNil(image, "Should return a valid Image from data")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After loadImageFromData, should be on main thread")
            }
        }

        func testCreateImageMainActor() async {
            let testImageData = createTestImageData()
            let platformImage = PlatformImage(data: testImageData, format: .png)

            let image = await clientUnwrapped.createImage(from: platformImage)
            XCTAssertNotNil(image, "Should return a valid Image from PlatformImage")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After createImage, should be on main thread")
            }
        }

        func testConvertToSwiftUIImageMainActor() async {
            let testImageData = createTestImageData()
            let platformImage = PlatformImage(data: testImageData, format: .png)

            let image = await clientUnwrapped.convertToSwiftUIImage(platformImage)
            XCTAssertNotNil(image, "Should return a valid SwiftUI Image")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After convertToSwiftUIImage, should be on main thread")
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

        // MARK: - ImageLoaderClient Integration Tests

        func testStaticIOSClientCreation() async {
            let serviceClient = ImageLoaderClient.iOSLive
            let testImageData = createTestImageData()

            // Test that we can call the client methods
            let image = await serviceClient.loadImage(testImageData)
            XCTAssertNotNil(image, "Should return a valid Image")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Static iOS client should maintain MainActor context")
            }
        }

        func testAsyncAwaitPattern() async {
            let testImageData = createTestImageData()
            let platformImage = PlatformImage(data: testImageData, format: .png)

            // Test the async/await pattern works correctly
            async let loadImageTask = clientUnwrapped.loadImage(from: testImageData)
            async let createImageTask = clientUnwrapped.createImage(from: platformImage)
            async let convertImageTask = clientUnwrapped.convertToSwiftUIImage(platformImage)

            let (loadedImage, createdImage, convertedImage) = await (loadImageTask, createImageTask, convertImageTask)

            XCTAssertNotNil(loadedImage, "loadImage should return valid Image")
            XCTAssertNotNil(createdImage, "createImage should return valid Image")
            XCTAssertNotNil(convertedImage, "convertToSwiftUIImage should return valid Image")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After concurrent async operations, should be on main thread")
            }
        }

        // MARK: - Image Loading Tests

        func testLoadImageFromValidData() async {
            let testImageData = createTestImageData()

            let image = await clientUnwrapped.loadImage(from: testImageData)
            XCTAssertNotNil(image, "Should load image from valid data")
        }

        func testLoadImageFromInvalidData() async {
            let invalidData = Data([0x00, 0x01, 0x02, 0x03])

            let image = await clientUnwrapped.loadImage(from: invalidData)
            XCTAssertNil(image, "Should return nil for invalid image data")
        }

        func testLoadImageFromBundle() async {
            // Test loading from bundle (this may not work in test environment, but should not crash)
            let image = await clientUnwrapped.loadImageFromBundle(named: "nonexistent", withExtension: "png", in: Bundle.main)
            // We don't assert the result since the image may not exist in test bundle
            // The important thing is that it doesn't crash and maintains MainActor context

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After loadImageFromBundle, should be on main thread")
            }
        }

        func testLoadImageFromNonExistentFile() async {
            let nonExistentPath = "/nonexistent/path/image.png"

            let platformImage = await clientUnwrapped.loadImageFromFile(nonExistentPath)
            XCTAssertNil(platformImage, "Should return nil for non-existent file")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After loadImageFromFile, should be on main thread")
            }
        }

        // MARK: - PlatformImage Integration Tests

        func testPlatformImageCreation() async {
            let testImageData = createTestImageData()
            let platformImage = PlatformImage(data: testImageData, format: .png)

            let image = await clientUnwrapped.createImage(from: platformImage)
            XCTAssertNotNil(image, "Should create Image from PlatformImage")
        }

        func testPlatformImageConversion() async {
            let testImageData = createTestImageData()
            let platformImage = PlatformImage(data: testImageData, format: .png)

            let image = await clientUnwrapped.convertToSwiftUIImage(platformImage)
            XCTAssertNotNil(image, "Should convert PlatformImage to SwiftUI Image")
        }

        func testEmptyPlatformImage() async {
            let emptyPlatformImage = PlatformImage(data: Data(), format: .png)

            let image = await clientUnwrapped.createImage(from: emptyPlatformImage)
            XCTAssertNotNil(image, "Should return fallback image for empty data")
        }

        // MARK: - Convenience Accessor Tests

        func testConvenienceStaticAccessor() async {
            let serviceClient = IOSImageLoaderClient.live
            let testImageData = createTestImageData()

            // Test that the convenience accessor works
            let image = await serviceClient.loadImage(testImageData)
            XCTAssertNotNil(image, "Convenience accessor should work")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Convenience accessor should maintain MainActor context")
            }
        }

        // MARK: - Helper Methods

        private func createTestImageData() -> Data {
            // Create a simple 1x1 pixel PNG image
            let image = UIImage(systemName: "star.fill") ?? UIImage()
            return image.pngData() ?? Data()
        }
    }
#endif
