import XCTest

final class ExpenseManagerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-UITestStore", UUID().uuidString, "-DisableAnimations", "-AppleLocale", "en_US"]
        app.launch()
    }

    func testFirstUseAndThreePrimaryDestinations() {
        let begin = app.buttons["beginTracking"]
        XCTAssertTrue(begin.waitForExistence(timeout: 15))
        begin.tap()
        XCTAssertTrue(app.textFields["expenseAmount"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        for title in ["Today", "History", "Plan"] {
            let tab = app.tabBars.buttons[title]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "Missing required destination \(title)")
            tab.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
        }
        XCTAssertFalse(app.tabBars.buttons["Settings"].exists)
        XCTAssertFalse(app.tabBars.buttons["Analytics"].exists)
    }

    func testManualSaveSurvivesRelaunchAndCanBeEdited() {
        let begin = app.buttons["beginTracking"]
        XCTAssertTrue(begin.waitForExistence(timeout: 15))
        begin.tap()
        let amount = app.textFields["expenseAmount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("125.50")
        app.buttons["More details"].tap()
        let merchant = app.textFields["expenseMerchant"]
        XCTAssertTrue(merchant.waitForExistence(timeout: 5))
        merchant.tap()
        merchant.typeText("Test Cafe")
        let save = app.buttons["saveExpense"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.buttons["addExpense"].waitForExistence(timeout: 8))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["Test Cafe"].waitForExistence(timeout: 15))
        app.staticTexts["Test Cafe"].tap()
        let edit = app.buttons["editEntry"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        let existing = amount.value as? String ?? ""
        XCTAssertFalse(existing.isEmpty)
        amount.tap()
        amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count) + "150.25")
        app.buttons["saveExpense"].tap()
        XCTAssertTrue(app.buttons["addExpense"].waitForExistence(timeout: 8))
        let total = app.staticTexts["monthlySpending"]
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertTrue(total.label.contains("150.25"), "The edited entry must replace the old amount.")
    }

    func testInvalidAmountCannotBeSaved() {
        XCTAssertTrue(app.buttons["beginTracking"].waitForExistence(timeout: 15))
        app.buttons["beginTracking"].tap()
        let amount = app.textFields["expenseAmount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveExpense"].isEnabled)
        amount.tap()
        amount.typeText("0")
        XCTAssertFalse(app.buttons["saveExpense"].isEnabled)
    }
}
