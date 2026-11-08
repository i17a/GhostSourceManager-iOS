import XCTest

final class UILayoutAndEditorTests: XCTestCase {
    func testJSONEditorKeyboardAndPinnedActions() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing-manifest")
        app.launch()

        let appsTab = app.buttons["tab.apps"]
        XCTAssertTrue(appsTab.waitForExistence(timeout: 5))
        appsTab.tap()

        let jsonMode = app.segmentedControls.buttons["محرر JSON الكامل"]
        XCTAssertTrue(jsonMode.waitForExistence(timeout: 5))
        jsonMode.tap()

        let editor = app.textViews["manifestJSONEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "The system keyboard should appear for editing")

        let validateButton = app.buttons["validateJSON"]
        let saveButton = app.buttons["saveJSON"]
        let hideKeyboardButton = app.buttons["hideJSONKeyboard"]
        XCTAssertTrue(validateButton.isHittable, "Validation must remain reachable above the keyboard")
        XCTAssertTrue(saveButton.isHittable, "Save must remain reachable above the keyboard")
        XCTAssertTrue(hideKeyboardButton.isHittable, "The editor must provide an explicit keyboard-dismiss control")
        validateButton.tap()
        hideKeyboardButton.tap()
        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 3), "The explicit control should dismiss the keyboard")

        XCTAssertTrue(editor.exists, "Validation must not replace or discard the editor contents")
    }

    func testAddIPAScreenUsesSafeAreaAndCanReachLastAction() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing-manifest")
        app.launch()

        let addTab = app.buttons["tab.addIPA"]
        XCTAssertTrue(addTab.waitForExistence(timeout: 5))
        XCTAssertTrue(addTab.isHittable, "The raised plus tab must not be clipped at the bottom safe area")
        addTab.tap()

        let nameField = app.textFields["ipaField.appName"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        let dismissKeyboard = app.buttons["hideFormKeyboard"]
        XCTAssertTrue(dismissKeyboard.isHittable)
        dismissKeyboard.tap()
        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 3))

        let publish = app.buttons["publishIPA"]
        for _ in 0..<8 where !publish.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(publish.waitForExistence(timeout: 5))
        XCTAssertTrue(publish.isHittable, "The final publish action must be fully reachable by scrolling")
        XCTAssertLessThanOrEqual(publish.frame.maxY, app.frame.maxY)
    }
}
