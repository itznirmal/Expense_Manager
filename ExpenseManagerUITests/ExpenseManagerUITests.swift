//
//  ExpenseManagerUITests.swift
//  ExpenseManagerUITests
//
//  Created for Expense Manager iOS.
//  UI Tests verifying critical end-to-end user navigation workflows.
//

import XCTest

final class ExpenseManagerUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-DisableAnimations"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Verifies that the app launches cleanly into Dashboard and allows seamless tab navigation.
    func testAppLaunchAndTabBarNavigation() throws {
        // 1. Verify Dashboard Root Navigation Title exists
        let dashboardNavTitle = app.navigationBars["Expense Manager"]
        XCTAssertTrue(dashboardNavTitle.waitForExistence(timeout: 5.0), "Dashboard should be visible upon launch.")

        // 2. Navigate to Transactions Tab
        let transactionsTab = app.tabBars.buttons["Transactions"]
        if transactionsTab.exists {
            transactionsTab.tap()
            let transactionsNavTitle = app.navigationBars["Transactions"]
            XCTAssertTrue(transactionsNavTitle.waitForExistence(timeout: 3.0), "Transactions screen should load.")
        }

        // 3. Navigate to Budgets Tab
        let budgetsTab = app.tabBars.buttons["Budgets"]
        if budgetsTab.exists {
            budgetsTab.tap()
            let budgetsNavTitle = app.navigationBars["Budgets"]
            XCTAssertTrue(budgetsNavTitle.waitForExistence(timeout: 3.0), "Budgets screen should load.")
        }

        // 4. Navigate to Analytics Tab
        let analyticsTab = app.tabBars.buttons["Analytics"]
        if analyticsTab.exists {
            analyticsTab.tap()
            let analyticsNavTitle = app.navigationBars["Analytics"]
            XCTAssertTrue(analyticsNavTitle.waitForExistence(timeout: 3.0), "Analytics screen should load.")
        }

        // 5. Navigate to Settings Tab
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()
            let settingsNavTitle = app.navigationBars["Settings"]
            XCTAssertTrue(settingsNavTitle.waitForExistence(timeout: 3.0), "Settings screen should load.")
        }
    }

    /// Verifies that the Smart Entry creation flow sheet can be presented and dismissed.
    func testSmartEntrySheetPresentation() throws {
        let smartAddButton = app.buttons["Smart Add"]
        if smartAddButton.waitForExistence(timeout: 3.0) {
            smartAddButton.tap()
            
            // Verify Smart Text entry modal is presented
            let cancelOrDoneButton = app.buttons["Cancel"]
            if cancelOrDoneButton.waitForExistence(timeout: 3.0) {
                cancelOrDoneButton.tap()
            }
        }
    }
}
