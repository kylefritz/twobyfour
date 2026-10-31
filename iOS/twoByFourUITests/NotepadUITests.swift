import XCTest

/// Drives the app in the simulator: the keypad, the sheets list, rounding,
/// and saving. Each test gets its own empty sheets folder.
final class NotepadUITests: XCTestCase {
    var app: XCUIApplication!
    var sheetsDir: String!

    override func setUp() {
        continueAfterFailure = false
        sheetsDir = (NSTemporaryDirectory() as NSString).appendingPathComponent(UUID().uuidString)
        app = XCUIApplication()
        app.launchEnvironment["TWOBYFOUR_SHEETS_DIR"] = sheetsDir
        app.launchEnvironment["TWOBYFOUR_NO_GUIDE"] = "1"
        app.launch()
    }

    private func press(_ labels: String...) {
        for label in labels { app.buttons[label].tap() }
    }

    private var notepad: XCUIElement { app.textViews.firstMatch }

    private func answer(_ line: Int) -> XCUIElement { app.descendants(matching: .any)["answer-\(line)"] }

    func testKeypadTypesAndAnswers() {
        XCTAssertTrue(app.navigationBars["Scratch"].waitForExistence(timeout: 5))
        press("4", "7", "space", "3", "fraction slash", "1", "6", "inches",
              "minus", "1", "fraction slash", "8", "inches")
        XCTAssertEqual(notepad.value as? String, "47 3/16\" − 1/8\"")
        XCTAssertEqual(answer(1).label, "3' 11 1/16\" (47 1/16\")")

        answer(1).tap()
        XCTAssertTrue(app.navigationBars["Other units"].waitForExistence(timeout: 5))
    }

    func testLettersKeyboardAndBack() {
        press("1", "2", "2", "0", "space", "letters")
        notepad.typeText("mm")
        XCTAssertEqual(answer(1).label, "≈ 4' 0 1/16\" (48 1/16\")")
        press("back to the keypad")
        XCTAssertTrue(app.buttons["fraction slash"].waitForExistence(timeout: 5))
    }

    func testSheetsCreateRenameRoundDelete() {
        press("Sheets", "New Sheet")
        XCTAssertTrue(app.navigationBars["Untitled"].waitForExistence(timeout: 5))

        press("More", "Rename…")
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.clearAndType("Deck")
        app.alerts.buttons["Rename"].tap()
        XCTAssertTrue(app.navigationBars["Deck"].waitForExistence(timeout: 5))

        press("1", "2", "2", "0", "space", "letters")
        notepad.typeText("mm")
        XCTAssertEqual(answer(1).label, "≈ 4' 0 1/16\" (48 1/16\")")
        press("More")
        app.buttons["Round to"].tap()
        app.buttons["1/32\""].tap()
        XCTAssertTrue(answer(1).waitForLabel("≈ 4' 0 1/32\" (48 1/32\")"))

        press("Sheets")
        let row = app.buttons.containing(.staticText, identifier: "Deck").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        app.sheets.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Scratch"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Deck"].exists)
    }

    func testTextSurvivesRelaunch() {
        press("1", "0", "5", "inches")
        XCTAssertEqual(answer(1).label, "8' 9\" (105\")")
        sleep(2)  // typing saves half a second after the last key
        app.terminate()
        app.launch()
        XCTAssertTrue(notepad.waitForExistence(timeout: 5))
        XCTAssertEqual(notepad.value as? String, "105\"")
    }
}

extension XCUIElement {
    func clearAndType(_ text: String) {
        tap()
        if let current = value as? String, !current.isEmpty {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        typeText(text)
    }

    func waitForLabel(_ label: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: self)],
                              timeout: timeout) == .completed
    }
}
