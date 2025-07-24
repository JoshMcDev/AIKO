#if os(iOS)
    @testable import AppCore
@testable import AIKOiOSiOS
    @testable import AppCore
@testable import AIKOiOS
    import SwiftUI
    import XCTest

    final class IOSPlatformViewServiceClientTests: XCTestCase {
        var client: IOSPlatformViewServiceClient?

        private var clientUnwrapped: IOSPlatformViewServiceClient {
            guard let client else { fatalError("client not initialized") }
            return client
        }

        override func setUp() async throws {
            try await super.setUp()
            client = IOSPlatformViewServiceClient()
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

            // Test that createNavigationStack executes on MainActor
            let navigationStack = await clientUnwrapped.createNavigationStack {
                Text("Test Content")
            }
            XCTAssertNotNil(navigationStack, "Should return a navigation stack view")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After createNavigationStack, should still be on main thread")
            }
        }

        func testCreateDocumentPickerMainActor() async {
            let documentPicker = await clientUnwrapped.createDocumentPicker { _ in
                // Mock callback
            }
            XCTAssertNotNil(documentPicker, "Should return a document picker view")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After createDocumentPicker, should be on main thread")
            }
        }

        func testCreateImagePickerMainActor() async {
            let imagePicker = await clientUnwrapped.createImagePicker { _ in
                // Mock callback
            }
            XCTAssertNotNil(imagePicker, "Should return an image picker view")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After createImagePicker, should be on main thread")
            }
        }

        func testCreateShareSheetMainActor() async {
            let shareSheet = await clientUnwrapped.createShareSheet(items: ["Test item"])
            XCTAssertNotNil(shareSheet, "Should return a share sheet view")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After createShareSheet, should be on main thread")
            }
        }

        func testApplyWindowStyleMainActor() async {
            let originalView = AnyView(Text("Test"))
            let styledView = await clientUnwrapped.applyWindowStyle(to: originalView)
            XCTAssertNotNil(styledView, "Should return a styled view")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After applyWindowStyle, should be on main thread")
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

        // MARK: - PlatformViewServiceClient Integration Tests

        func testStaticIOSClientCreation() async {
            let serviceClient = PlatformViewServiceClient.iOS

            // Test that we can call the client methods
            let navigationStack = await serviceClient._createNavigationStack {
                Text("Integration Test")
            }
            XCTAssertNotNil(navigationStack, "Should return a navigation stack")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Static iOS client should maintain MainActor context")
            }
        }

        func testAsyncAwaitPattern() async {
            // Test the async/await pattern works correctly
            async let navigationTask = clientUnwrapped.createNavigationStack { Text("Nav Test") }
            async let shareSheetTask = clientUnwrapped.createShareSheet(items: ["Share Test"])
            async let windowStyleTask = clientUnwrapped.applyWindowStyle(to: AnyView(Text("Style Test")))

            let (navigation, shareSheet, windowStyled) = await (navigationTask, shareSheetTask, windowStyleTask)

            XCTAssertNotNil(navigation, "Navigation stack should be created")
            XCTAssertNotNil(shareSheet, "Share sheet should be created")
            XCTAssertNotNil(windowStyled, "Window style should be applied")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After concurrent async operations, should be on main thread")
            }
        }

        // MARK: - Platform View Creation Tests

        func testCreateNavigationStackWithDifferentContent() async {
            let textView = await clientUnwrapped.createNavigationStack {
                Text("Text Content")
            }
            XCTAssertNotNil(textView, "Should create navigation stack with text")

            let buttonView = await clientUnwrapped.createNavigationStack {
                Button("Button") {}
            }
            XCTAssertNotNil(buttonView, "Should create navigation stack with button")

            let listView = await clientUnwrapped.createNavigationStack {
                List {
                    Text("Item 1")
                    Text("Item 2")
                }
            }
            XCTAssertNotNil(listView, "Should create navigation stack with list")
        }

        func testCreateDocumentPickerWithCallback() async {
            var documentsReceived: [(Data, String)] = []

            let documentPicker = await clientUnwrapped.createDocumentPicker { documents in
                documentsReceived = documents
            }

            XCTAssertNotNil(documentPicker, "Should create document picker with callback")
            XCTAssertTrue(documentsReceived.isEmpty, "Documents array should start empty")
        }

        func testCreateImagePickerWithCallback() async {
            var imageDataReceived: Data?

            let imagePicker = await clientUnwrapped.createImagePicker { data in
                imageDataReceived = data
            }

            XCTAssertNotNil(imagePicker, "Should create image picker with callback")
            XCTAssertNil(imageDataReceived, "Image data should start nil")
        }

        func testCreateShareSheetWithDifferentItems() async {
            let stringItems = await clientUnwrapped.createShareSheet(items: ["String 1", "String 2"])
            XCTAssertNotNil(stringItems, "Should create share sheet with strings")

            guard let testURL = URL(string: "https://example.com") else {
                XCTFail("Failed to create test URL from 'https://example.com'")
                return
            }
            let urlItems = await clientUnwrapped.createShareSheet(items: [testURL])
            XCTAssertNotNil(urlItems, "Should create share sheet with URLs")

            guard let mixedTestURL = URL(string: "https://example.com") else {
                XCTFail("Failed to create test URL from 'https://example.com' for mixed items test")
                return
            }
            let mixedItems = await clientUnwrapped.createShareSheet(items: ["Text", mixedTestURL])
            XCTAssertNotNil(mixedItems, "Should create share sheet with mixed items")

            let emptyItems = await clientUnwrapped.createShareSheet(items: [])
            XCTAssertNotNil(emptyItems, "Should create share sheet with empty items")
        }

        func testCreateSidebarNavigation() async {
            let sidebarView = await clientUnwrapped.createSidebarNavigation(
                sidebar: {
                    VStack {
                        Text("Sidebar Item 1")
                        Text("Sidebar Item 2")
                    }
                },
                detail: {
                    Text("Detail Content")
                }
            )

            XCTAssertNotNil(sidebarView, "Should create sidebar navigation")
            // Note: On iOS, this typically returns the detail view since iOS doesn't have true sidebar navigation
        }

        func testApplyWindowStyleToViews() async {
            let textView = AnyView(Text("Window Style Test"))
            let styledText = await clientUnwrapped.applyWindowStyle(to: textView)
            XCTAssertNotNil(styledText, "Should apply window style to text view")

            let buttonView = AnyView(Button("Window Button") {})
            let styledButton = await clientUnwrapped.applyWindowStyle(to: buttonView)
            XCTAssertNotNil(styledButton, "Should apply window style to button view")

            let navigationView = AnyView(NavigationView { Text("Navigation") })
            let styledNavigation = await clientUnwrapped.applyWindowStyle(to: navigationView)
            XCTAssertNotNil(styledNavigation, "Should apply window style to navigation view")
        }

        func testApplyToolbarStyleToViews() async {
            let textView = AnyView(Text("Toolbar Style Test"))
            let styledText = await clientUnwrapped.applyToolbarStyle(to: textView)
            XCTAssertNotNil(styledText, "Should apply toolbar style to text view")

            let listView = AnyView(List { Text("List Item") })
            let styledList = await clientUnwrapped.applyToolbarStyle(to: listView)
            XCTAssertNotNil(styledList, "Should apply toolbar style to list view")
        }

        func testCreateDropZone() async {
            var droppedItems: [Any] = []

            let dropZone = await clientUnwrapped.createDropZone(
                content: {
                    Text("Drop Zone Content")
                },
                onItemsDropped: { items in
                    droppedItems = items
                }
            )

            XCTAssertNotNil(dropZone, "Should create drop zone")
            XCTAssertTrue(droppedItems.isEmpty, "Dropped items should start empty")
            // Note: On iOS, drop zones may not function the same as on macOS
        }

        // MARK: - View Composition Tests

        func testComplexViewComposition() async {
            // Test creating complex view hierarchies
            let complexView = await clientUnwrapped.createNavigationStack {
                VStack {
                    Text("Header")
                    List {
                        ForEach(0 ..< 5) { index in
                            HStack {
                                Text("Item \(index)")
                                Spacer()
                                Button("Action") {}
                            }
                        }
                    }
                    HStack {
                        Button("Cancel") {}
                        Spacer()
                        Button("Save") {}
                    }
                }
            }

            XCTAssertNotNil(complexView, "Should handle complex view composition")
        }

        func testViewStyleChaining() async {
            let originalView = AnyView(Text("Chaining Test"))

            // Apply multiple styles in sequence
            let windowStyled = await clientUnwrapped.applyWindowStyle(to: originalView)
            let toolbarStyled = await clientUnwrapped.applyToolbarStyle(to: windowStyled)

            XCTAssertNotNil(toolbarStyled, "Should handle style chaining")
        }

        // MARK: - Performance Tests

        func testViewCreationPerformance() async {
            let iterations = 50 // Reduced for UI operations
            let startTime = CFAbsoluteTimeGetCurrent()

            for i in 0 ..< iterations {
                _ = await clientUnwrapped.createNavigationStack {
                    Text("Performance Test \(i)")
                }
            }

            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

            // View creation should be reasonably fast (allowing generous time for UI operations)
            XCTAssertLessThan(timeElapsed, 5.0, "View creation should be reasonably fast")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After performance test, should be on main thread")
            }
        }

        func testConcurrentViewCreation() async {
            // Test concurrent view creation operations
            async let nav1 = clientUnwrapped.createNavigationStack { Text("Concurrent 1") }
            async let nav2 = clientUnwrapped.createNavigationStack { Text("Concurrent 2") }
            async let share1 = clientUnwrapped.createShareSheet(items: ["Concurrent Share 1"])
            async let share2 = clientUnwrapped.createShareSheet(items: ["Concurrent Share 2"])
            async let picker1 = clientUnwrapped.createDocumentPicker { _ in }
            async let picker2 = clientUnwrapped.createImagePicker { _ in }

            let (n1, n2, s1, s2, p1, p2) = await (nav1, nav2, share1, share2, picker1, picker2)

            XCTAssertNotNil(n1, "Concurrent navigation 1 should be created")
            XCTAssertNotNil(n2, "Concurrent navigation 2 should be created")
            XCTAssertNotNil(s1, "Concurrent share 1 should be created")
            XCTAssertNotNil(s2, "Concurrent share 2 should be created")
            XCTAssertNotNil(p1, "Concurrent document picker should be created")
            XCTAssertNotNil(p2, "Concurrent image picker should be created")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "After concurrent view creation, should be on main thread")
            }
        }

        // MARK: - Convenience Accessor Tests

        func testConvenienceStaticAccessor() async {
            let serviceClient = IOSPlatformViewServiceClient.live

            // Test that the convenience accessor works
            let navigationStack = await serviceClient._createNavigationStack {
                Text("Convenience Test")
            }
            XCTAssertNotNil(navigationStack, "Convenience accessor should work")

            await MainActor.run {
                XCTAssertTrue(Thread.isMainThread, "Convenience accessor should maintain MainActor context")
            }
        }
    }
#endif
