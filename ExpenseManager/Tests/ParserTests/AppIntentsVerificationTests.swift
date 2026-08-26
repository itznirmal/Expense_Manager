//
//  AppIntentsVerificationTests.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//

import XCTest
import AppIntents
@testable import ExpenseManager

final class AppIntentsVerificationTests: XCTestCase {
    
    // Note: To fully test AppIntents in unit tests requires some mocking, 
    // but we can verify the parameter bindings and basic initialization.
    
    func testLogExpenseIntentInitialization() {
        let intent = LogExpenseIntent()
        // We can't easily set properties directly without parameter wrappers,
        // but we verify the type exists and is accessible.
        XCTAssertNotNil(intent)
        XCTAssertEqual(LogExpenseIntent.title.key, "Log Expense")
    }
    
    func testParseTextExpenseIntentInitialization() {
        let intent = ParseTextExpenseIntent()
        XCTAssertNotNil(intent)
        XCTAssertEqual(ParseTextExpenseIntent.title.key, "Parse Expense Text")
    }
}
