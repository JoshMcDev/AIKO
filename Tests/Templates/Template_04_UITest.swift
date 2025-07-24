//
//  UI Test Template
//  AIKO
//
//  Test Naming Convention: test_ScreenName_UserAction_ExpectedUIBehavior()
//  Example: test_LoginScreen_tapSubmitButton_navigatesToHome()
//

@testable import AppCore
import ComposableArchitecture
import ViewInspector
import XCTest

final class ScreenNameUITests: XCTestCase {
    // MARK: - Properties

    var sut: ScreenNameView?
    var store: Store<FeatureName.State, FeatureName.Action>?

    private var sutUnwrapped: ScreenNameView {
        guard let sut else { fatalError("sut not initialized") }
        return sut
    }

    private var storeUnwrapped: Store<FeatureName.State, FeatureName.Action> {
        guard let store else { fatalError("store not initialized") }
        return store
    }

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        store = Store(
            initialState: FeatureName.State(),
            reducer: { FeatureName() }
        )
        sut = ScreenNameView(store: storeUnwrapped)
    }

    override func tearDown() {
        sut = nil
        store = nil
        super.tearDown()
    }

    // MARK: - View Rendering Tests

    func test_viewAppearance_withInitialState_rendersCorrectly() throws {
        // Test that all expected UI elements are present
        let inspection = try sutUnwrapped.inspect()

        XCTAssertNoThrow(try inspection.find(text: "Expected Text"))
        XCTAssertNoThrow(try inspection.find(button: "Expected Button"))
    }

    // MARK: - User Interaction Tests

    func test_userAction_tapButton_triggersExpectedAction() throws {
        // Given
        let expectation = expectation(description: "Action triggered")

        // When
        let button = try sutUnwrapped.inspect().find(button: "Action Button")
        try button.tap()

        // Then
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Accessibility Tests

    func test_accessibility_allElementsHaveLabels() throws {
        // Verify all interactive elements have accessibility labels
        let inspection = try sutUnwrapped.inspect()

        // Check buttons
        let buttons = try inspection.findAll(ViewType.Button.self)
        for button in buttons {
            XCTAssertNotNil(try button.accessibilityLabel())
        }
    }

    // MARK: - Layout Tests

    func test_layout_onDifferentDeviceSizes_adaptsCorrectly() {
        // Test on different screen sizes
        let devices = [
            PreviewDevice(rawValue: "iPhone 15 Pro"),
            PreviewDevice(rawValue: "iPhone SE"),
            PreviewDevice(rawValue: "iPad Pro"),
        ]

        for device in devices {
            // Test layout constraints
        }
    }
}
