//
//  ConfidenceEngineTests.swift
//  ExpenseManagerTests
//
//  Created for Expense Manager iOS.
//  Unit Test Suite for Confidence Engine & Routing Diagnostics.
//

import XCTest
@testable import ExpenseManager

final class ConfidenceEngineTests: XCTestCase {
    
    func testManualEntryAlwaysHighScore() {
        let draft = ParsedTransactionDraft(
            type: .expense,
            amount: Decimal(500),
            merchantName: "Coffee",
            rawText: "Coffee"
        )
        let eval = ConfidenceEngine.evaluate(draft: draft, source: .manual)
        XCTAssertEqual(eval.score.value, 1.0)
        XCTAssertEqual(eval.score.tier, .high)
        XCTAssertTrue(eval.isAutoSaveEligible)
        XCTAssertTrue(eval.warnings.isEmpty)
    }
    
    func testHighConfidenceExtraction() {
        let draft = ParsedTransactionDraft(
            type: .expense,
            amount: Decimal(520),
            merchantName: "Swiggy",
            inferredCategory: "Food & Dining",
            accountSuggestion: "HDFC Bank •••• 8432",
            paymentMethod: .upi,
            upiVPA: "swiggy@upi",
            rawText: "Swiggy 520 via HDFC card"
        )
        let eval = ConfidenceEngine.evaluate(draft: draft, source: .smartText, hasMatchedRule: true)
        
        // Amount(0.35) + Merchant(0.25) + Direction(0.15) + Account(0.15) + Category(0.10) + Rule(0.15) + UPI(0.05) = 1.0 (clamped)
        XCTAssertGreaterThanOrEqual(eval.score.value, 0.90)
        XCTAssertEqual(eval.score.tier, .high)
        XCTAssertTrue(eval.isAutoSaveEligible)
    }
    
    func testMediumConfidenceMissingAccount() {
        let draft = ParsedTransactionDraft(
            type: .expense,
            amount: Decimal(350),
            merchantName: "Starbucks",
            inferredCategory: "Food & Dining",
            accountSuggestion: nil,
            rawText: "Starbucks 350"
        )
        let eval = ConfidenceEngine.evaluate(draft: draft, source: .smartText)
        
        // Amount(0.35) + Merchant(0.25) + Direction(0.15) + Category(0.10) = 0.85
        XCTAssertEqual(eval.score.tier, .medium)
        XCTAssertFalse(eval.isAutoSaveEligible)
        XCTAssertTrue(eval.warnings.contains("Unassigned bank/payment account"))
    }
    
    func testLowConfidenceMissingAmountAndMerchant() {
        let draft = ParsedTransactionDraft(
            type: .expense,
            amount: .zero,
            merchantName: "Unknown Merchant",
            inferredCategory: nil,
            accountSuggestion: nil,
            rawText: "Something paid"
        )
        let eval = ConfidenceEngine.evaluate(draft: draft, source: .sms)
        
        XCTAssertLessThan(eval.score.value, 0.65)
        XCTAssertEqual(eval.score.tier, .low)
        XCTAssertFalse(eval.isAutoSaveEligible)
        XCTAssertTrue(eval.warnings.contains("Missing or invalid amount"))
        XCTAssertTrue(eval.warnings.contains("Unassigned bank/payment account"))
        XCTAssertTrue(eval.warnings.contains("Uncategorized transaction"))
    }
    
    func testHighValueTransactionWarning() {
        let draft = ParsedTransactionDraft(
            type: .expense,
            amount: Decimal(75000),
            merchantName: "Apple Store",
            inferredCategory: "Shopping",
            accountSuggestion: "HDFC Credit Card",
            rawText: "Apple Store 75000"
        )
        let eval = ConfidenceEngine.evaluate(draft: draft, source: .ocr)
        
        XCTAssertTrue(eval.warnings.contains("High value transaction requires confirmation"))
        XCTAssertFalse(eval.isAutoSaveEligible, "High value transactions must not be auto-saved without confirmation")
    }
    
    func testRuleMatchingBoost() {
        let draft = ParsedTransactionDraft(
            type: .expense,
            amount: Decimal(200),
            merchantName: "Corner Shop",
            inferredCategory: nil,
            accountSuggestion: nil,
            rawText: "Corner Shop 200"
        )
        let evalWithoutRule = ConfidenceEngine.evaluate(draft: draft, source: .smartText, hasMatchedRule: false)
        let evalWithRule = ConfidenceEngine.evaluate(draft: draft, source: .smartText, hasMatchedRule: true)
        
        XCTAssertGreaterThan(evalWithRule.score.value, evalWithoutRule.score.value)
    }
}
