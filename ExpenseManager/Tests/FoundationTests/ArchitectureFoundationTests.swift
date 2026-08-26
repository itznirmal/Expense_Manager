//
//  ArchitectureFoundationTests.swift
//  ExpenseManagerTests
//
//  Created for Expense Manager iOS.
//  Unit Tests for Core Utilities, Precision Arithmetic, DI, and AppState.
//

import XCTest
@testable import ExpenseManager

final class ArchitectureFoundationTests: XCTestCase {
    
    // MARK: - 1. Currency Formatter Precision & Parsing Tests
    
    func testCurrencyFormatterBasicFormatting() {
        let formatter = CurrencyFormatter.shared
        let amount = Decimal(520)
        let formatted = formatter.format(amount: amount, currencyCode: "INR", locale: Locale(identifier: "en_IN"))
        
        XCTAssertTrue(formatted.contains("520"), "Formatted string should contain 520")
        XCTAssertTrue(formatted.contains("₹") || formatted.contains("INR"), "Formatted string should contain currency symbol")
    }
    
    func testCurrencyFormatterNegativeAmount() {
        let formatter = CurrencyFormatter.shared
        let amount = Decimal(-1450.50)
        let formatted = formatter.format(amount: amount, currencyCode: "INR", locale: Locale(identifier: "en_IN"))
        
        XCTAssertTrue(formatted.hasPrefix("-"), "Negative amount must be prefixed with '-'")
        XCTAssertTrue(formatted.contains("1,450.50") || formatted.contains("1450.50"), "Formatted string must preserve decimal precision")
    }
    
    func testCurrencyFormatterZeroAmount() {
        let formatter = CurrencyFormatter.shared
        let formatted = formatter.format(amount: .zero, currencyCode: "INR", locale: Locale(identifier: "en_IN"))
        
        XCTAssertTrue(formatted.contains("0.00"), "Zero amount should format as 0.00")
    }
    
    func testCurrencyFormatterCompactFormatting() {
        let formatter = CurrencyFormatter.shared
        let locale = Locale(identifier: "en_IN")
        
        let lakhAmount = Decimal(150000)
        let formattedLakh = formatter.formatCompact(amount: lakhAmount, currencyCode: "INR", locale: locale)
        XCTAssertTrue(formattedLakh.contains("1.5 L") || formattedLakh.contains("1.50 L") || formattedLakh.contains("L"), "150,000 should format in Lakh scale: \(formattedLakh)")
        
        let croreAmount = Decimal(25000000)
        let formattedCrore = formatter.formatCompact(amount: croreAmount, currencyCode: "INR", locale: locale)
        XCTAssertTrue(formattedCrore.contains("2.5 Cr") || formattedCrore.contains("2.50 Cr") || formattedCrore.contains("Cr"), "2.5 Cr should format in Crore scale: \(formattedCrore)")
    }
    
    func testCurrencyFormatterParsing() {
        let formatter = CurrencyFormatter.shared
        let locale = Locale(identifier: "en_IN")
        
        // Exact symbols and prefixes
        XCTAssertEqual(formatter.parse(from: "₹520", locale: locale), Decimal(520))
        XCTAssertEqual(formatter.parse(from: "Rs. 1,450.50", locale: locale), Decimal(1450.50))
        XCTAssertEqual(formatter.parse(from: "INR 85000", locale: locale), Decimal(85000))
        XCTAssertEqual(formatter.parse(from: "350.25", locale: locale), Decimal(350.25))
        XCTAssertEqual(formatter.parse(from: "-₹500.00", locale: locale), Decimal(-500.00))
        XCTAssertEqual(formatter.parse(from: "(₹1200)", locale: locale), Decimal(-1200))
        
        // Invalid strings should return nil
        XCTAssertNil(formatter.parse(from: "NotAnAmount", locale: locale))
        XCTAssertNil(formatter.parse(from: "", locale: locale))
    }
    
    // MARK: - 2. Date Formatter Helper Tests
    
    func testDateFormatterRelativeDates() {
        let helper = DateFormatterHelper.shared
        let now = Date()
        
        XCTAssertEqual(helper.relativeDateString(for: now, relativeTo: now), "Today")
        
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        XCTAssertEqual(helper.relativeDateString(for: yesterday, relativeTo: now), "Yesterday")
    }
    
    func testDateFormatterMonthBoundaries() {
        let helper = DateFormatterHelper.shared
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 15
        components.hour = 12
        let testDate = calendar.date(from: components)!
        
        let startOfMonth = helper.startOfMonth(for: testDate, calendar: calendar)
        let startComponents = calendar.dateComponents([.year, .month, .day], from: startOfMonth)
        XCTAssertEqual(startComponents.day, 1)
        XCTAssertEqual(startComponents.month, 8)
        XCTAssertEqual(startComponents.year, 2026)
        
        let endOfMonth = helper.endOfMonth(for: testDate, calendar: calendar)
        let endComponents = calendar.dateComponents([.year, .month, .day], from: endOfMonth)
        XCTAssertEqual(endComponents.day, 31) // August has 31 days
        XCTAssertEqual(endComponents.month, 8)
    }
    
    // MARK: - 3. Confidence Score Threshold Tests
    
    func testConfidenceScoreTiers() {
        let high = ConfidenceScore(0.95)
        XCTAssertEqual(high.tier, .high)
        XCTAssertTrue(high.isAutoSaveEligible)
        XCTAssertFalse(high.requiresReview)
        
        let medium = ConfidenceScore(0.75)
        XCTAssertEqual(medium.tier, .medium)
        XCTAssertFalse(medium.isAutoSaveEligible)
        XCTAssertTrue(medium.requiresReview)
        
        let low = ConfidenceScore(0.40)
        XCTAssertEqual(low.tier, .low)
        XCTAssertFalse(low.isAutoSaveEligible)
        XCTAssertTrue(low.requiresReview)
    }
    
    func testConfidenceScoreClamping() {
        let overMax = ConfidenceScore(1.5)
        XCTAssertEqual(overMax.value, 1.0)
        
        let underMin = ConfidenceScore(-0.5)
        XCTAssertEqual(underMin.value, 0.0)
    }
    
    // MARK: - 4. Privacy Logging & Sanitization Tests
    
    func testAppLoggerSanitization() {
        let fullAccountNumber = "123456789012"
        let sanitized = AppLogger.sanitize(accountNumber: fullAccountNumber)
        XCTAssertEqual(sanitized, "•••• 9012")
        XCTAssertFalse(sanitized.contains("12345678"), "Full account number must not be exposed")
        
        let emptySanitized = AppLogger.sanitize(accountNumber: nil)
        XCTAssertEqual(emptySanitized, "•••• [empty]")
        
        let fp = AppLogger.fingerprint(text: "Swiggy order 520")
        XCTAssertTrue(fp.hasPrefix("FP-"), "Fingerprint must have FP- prefix")
    }
    
    // MARK: - 5. AppState State Mutations Tests
    
    @MainActor
    func testAppStateTabSwitching() {
        let appState = AppState()
        XCTAssertEqual(appState.selectedTab, .dashboard)
        
        appState.selectedTab = .transactions
        XCTAssertEqual(appState.selectedTab, .transactions)
        
        appState.selectedTab = .budgets
        XCTAssertEqual(appState.selectedTab, .budgets)
    }
    
    @MainActor
    func testAppStateSheetPresentation() {
        let appState = AppState()
        XCTAssertNil(appState.presentedSheet)
        
        appState.presentSheet(.smartTextEntry)
        XCTAssertEqual(appState.presentedSheet, .smartTextEntry)
        
        appState.dismissSheet()
        XCTAssertNil(appState.presentedSheet)
    }
    
    @MainActor
    func testAppStateToastPresentationAndDismissal() {
        let appState = AppState()
        XCTAssertNil(appState.activeToast)
        
        appState.showToast(title: "Saved", message: "Transaction added", type: .success)
        XCTAssertNotNil(appState.activeToast)
        XCTAssertEqual(appState.activeToast?.title, "Saved")
        XCTAssertEqual(appState.activeToast?.type, .success)
        
        appState.dismissToast()
        XCTAssertNil(appState.activeToast)
    }
    
    // MARK: - 6. Dependency Container & Mock Services Tests
    
    @MainActor
    func testDependencyContainerResolution() async throws {
        let container = DependencyContainer.mock()
        
        // Test transaction service
        let recent = try await container.transactionService.fetchRecentTransactions(limit: 10)
        XCTAssertFalse(recent.isEmpty, "Mock transaction service should provide sample data")
        
        // Test account service & net worth
        let accounts = try await container.accountService.fetchAccounts(includeArchived: false)
        XCTAssertFalse(accounts.isEmpty, "Mock account service should provide sample accounts")
        
        let netWorth = try await container.accountService.calculateNetWorth()
        XCTAssertGreaterThan(netWorth, Decimal.zero, "Net worth should be calculated deterministically")
        
        // Test parser service
        let parsed = try await container.parserService.parse(text: "Swiggy 520", source: .smartText)
        XCTAssertEqual(parsed.merchantName, "Swiggy")
        XCTAssertEqual(parsed.amount, Decimal(520))
        XCTAssertEqual(parsed.type, .expense)
        
        // Test budget service
        let budgets = try await container.budgetService.fetchBudgets(for: Date())
        XCTAssertFalse(budgets.isEmpty, "Mock budget service should return budgets")
    }
    
    @MainActor
    func testTransactionServiceCRUD() async throws {
        let container = DependencyContainer.inMemoryEmpty()
        
        let candidate = TransactionCandidate(
            type: .expense,
            amount: Decimal(350),
            currencyCode: "INR",
            merchantName: "Coffee Shop",
            categorySuggestion: "Dining",
            source: .manual
        )
        
        let txId = try await container.transactionService.createTransaction(candidate)
        XCTAssertFalse(txId.isEmpty)
        
        let fetched = try await container.transactionService.fetchRecentTransactions(limit: 10)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.merchantName, "Coffee Shop")
        XCTAssertEqual(fetched.first?.amount, Decimal(350))
        
        try await container.transactionService.deleteTransaction(id: txId)
        let afterDelete = try await container.transactionService.fetchRecentTransactions(limit: 10)
        XCTAssertEqual(afterDelete.count, 0)
    }
}
