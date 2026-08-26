//
//  FinancialEngineTests.swift
//  ExpenseManagerTests
//
//  Created for Expense Manager iOS.
//  Unit Tests for SwiftData Financial Data Engine & Accounting Invariants.
//

import XCTest
import SwiftData
@testable import ExpenseManager

final class FinancialEngineTests: XCTestCase {
    
    private var modelContainer: ModelContainer!
    private var transactionService: SwiftDataTransactionService!
    private var accountService: SwiftDataAccountService!
    private var categoryService: SwiftDataCategoryService!
    private var budgetService: SwiftDataBudgetService!
    private var ruleService: MerchantRuleService!
    private var fingerprintService: ImportFingerprintService!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        modelContainer = try DatabaseContainer.inMemory()
        transactionService = SwiftDataTransactionService(modelContainer: modelContainer)
        accountService = SwiftDataAccountService(modelContainer: modelContainer)
        categoryService = SwiftDataCategoryService(modelContainer: modelContainer)
        budgetService = SwiftDataBudgetService(modelContainer: modelContainer)
        ruleService = MerchantRuleService(modelContainer: modelContainer)
        fingerprintService = ImportFingerprintService(modelContainer: modelContainer)
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        transactionService = nil
        accountService = nil
        categoryService = nil
        budgetService = nil
        ruleService = nil
        fingerprintService = nil
        try await super.tearDown()
    }
    
    // MARK: - 1. Decimal Currency Math Precision Tests
    
    func testDecimalCurrencyMathPrecision() {
        // Repeated fractional additions must have zero binary floating-point drift
        var sum: Decimal = .zero
        let oneCent = Decimal(string: "0.01")!
        
        for _ in 1...10000 {
            sum += oneCent
        }
        
        XCTAssertEqual(sum, Decimal(100), "Adding 0.01 exactly 10,000 times must equal 100.00 without floating point error")
        
        // Exact subtraction with large values
        let opening = Decimal(string: "123456789.99")!
        let debit = Decimal(string: "23456789.50")!
        let expectedRemainder = Decimal(string: "100000000.49")!
        
        XCTAssertEqual(opening - debit, expectedRemainder, "High magnitude Decimal subtraction must retain exact precision")
    }
    
    // MARK: - 2. Expense Creation Invariant
    
    @MainActor
    func testExpenseCreationReducesAccountBalance() async throws {
        let accountId = try await accountService.createAccount(
            name: "HDFC Checking",
            type: .bank,
            openingBalance: Decimal(10000),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: "1234"
        )
        
        let candidate = TransactionCandidate(
            type: .expense,
            amount: Decimal(2500),
            currencyCode: "INR",
            merchantName: "Amazon",
            accountSuggestion: accountId,
            source: .manual
        )
        
        try await transactionService.createTransaction(candidate)
        
        let account = try await accountService.getAccount(id: accountId)
        XCTAssertNotNil(account)
        XCTAssertEqual(account?.balance, Decimal(7500), "Expense must reduce account balance: 10,000 - 2,500 = 7,500")
    }
    
    // MARK: - 3. Income Creation Invariant
    
    @MainActor
    func testIncomeCreationIncreasesAccountBalance() async throws {
        let accountId = try await accountService.createAccount(
            name: "Salary Account",
            type: .bank,
            openingBalance: Decimal(5000),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "green",
            lastFour: "5678"
        )
        
        let candidate = TransactionCandidate(
            type: .income,
            amount: Decimal(50000),
            currencyCode: "INR",
            merchantName: "Employer Corp",
            accountSuggestion: accountId,
            source: .manual
        )
        
        try await transactionService.createTransaction(candidate)
        
        let account = try await accountService.getAccount(id: accountId)
        XCTAssertNotNil(account)
        XCTAssertEqual(account?.balance, Decimal(55000), "Income must increase account balance: 5,000 + 50,000 = 55,000")
    }
    
    // MARK: - 4. Refund Creation Invariant
    
    @MainActor
    func testRefundCreationIncreasesAccountBalance() async throws {
        let accountId = try await accountService.createAccount(
            name: "Credit Card",
            type: .creditCard,
            openingBalance: Decimal(1000),
            currencyCode: "INR",
            icon: "creditcard.fill",
            colorToken: "purple",
            lastFour: "9999"
        )
        
        let candidate = TransactionCandidate(
            type: .refund,
            amount: Decimal(450),
            currencyCode: "INR",
            merchantName: "Flipkart Refund",
            accountSuggestion: accountId,
            source: .sms
        )
        
        try await transactionService.createTransaction(candidate)
        
        let account = try await accountService.getAccount(id: accountId)
        XCTAssertNotNil(account)
        XCTAssertEqual(account?.balance, Decimal(1450), "Refund must increase account balance: 1,000 + 450 = 1,450")
    }
    
    // MARK: - 5. Transfer & Net Worth Invariants
    
    @MainActor
    func testTransferDebitsSourceCreditsDestinationKeepsNetWorthUnchanged() async throws {
        let bankId = try await accountService.createAccount(
            name: "Main Bank",
            type: .bank,
            openingBalance: Decimal(50000),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: "1111"
        )
        
        let cashId = try await accountService.createAccount(
            name: "Cash Wallet",
            type: .cash,
            openingBalance: Decimal(2000),
            currencyCode: "INR",
            icon: "banknote.fill",
            colorToken: "green",
            lastFour: nil
        )
        
        let initialNetWorth = try await accountService.calculateNetWorth()
        XCTAssertEqual(initialNetWorth, Decimal(52000))
        
        // Execute transfer of 10,000 from Bank to Cash
        let transferCandidate = TransactionCandidate(
            type: .transfer,
            amount: Decimal(10000),
            currencyCode: "INR",
            merchantName: "ATM Cash Withdrawal",
            accountSuggestion: bankId,
            destinationAccountSuggestion: cashId,
            source: .manual
        )
        
        try await transactionService.createTransaction(transferCandidate)
        
        let updatedBank = try await accountService.getAccount(id: bankId)
        let updatedCash = try await accountService.getAccount(id: cashId)
        
        XCTAssertEqual(updatedBank?.balance, Decimal(40000), "Source account must be debited by 10,000")
        XCTAssertEqual(updatedCash?.balance, Decimal(12000), "Destination account must be credited by 10,000")
        
        let postTransferNetWorth = try await accountService.calculateNetWorth()
        XCTAssertEqual(postTransferNetWorth, Decimal(52000), "Net worth must remain exactly unchanged after an internal transfer")
        
        // Ensure transfers do NOT inflate income/expense totals
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let endOfDay = startOfDay.addingTimeInterval(86400)
        let totals = try await transactionService.calculateTotals(startDate: startOfDay, endDate: endOfDay)
        
        XCTAssertEqual(totals.income, Decimal.zero, "Transfers must not count as income")
        XCTAssertEqual(totals.expense, Decimal.zero, "Transfers must not count as expense")
    }
    
    // MARK: - 6. Transaction Update Rollback & Reapplication
    
    @MainActor
    func testTransactionUpdateRollsBackOldBalanceAndAppliesNewBalance() async throws {
        let accountId = try await accountService.createAccount(
            name: "Checking",
            type: .bank,
            openingBalance: Decimal(10000),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: "2222"
        )
        
        // 1. Create original expense of 2,000
        var candidate = TransactionCandidate(
            type: .expense,
            amount: Decimal(2000),
            currencyCode: "INR",
            merchantName: "Grocery Store",
            accountSuggestion: accountId,
            source: .manual
        )
        
        let txId = try await transactionService.createTransaction(candidate)
        var acc = try await accountService.getAccount(id: accountId)
        XCTAssertEqual(acc?.balance, Decimal(8000))
        
        // 2. Update to expense of 3,500
        candidate.amount = Decimal(3500)
        try await transactionService.updateTransaction(id: txId, candidate: candidate)
        
        acc = try await accountService.getAccount(id: accountId)
        XCTAssertEqual(acc?.balance, Decimal(6500), "Updating expense from 2,000 to 3,500 should adjust balance to 6,500 (10,000 - 3,500)")
        
        // 3. Switch type from Expense to Income of 1,000
        candidate.type = .income
        candidate.amount = Decimal(1000)
        try await transactionService.updateTransaction(id: txId, candidate: candidate)
        
        acc = try await accountService.getAccount(id: accountId)
        XCTAssertEqual(acc?.balance, Decimal(11000), "Switching 3,500 expense to 1,000 income should adjust balance to 11,000 (10,000 + 1,000)")
    }
    
    // MARK: - 7. Transaction Deletion Rollback
    
    @MainActor
    func testTransactionDeletionRollsBackBalanceEffect() async throws {
        let accountId = try await accountService.createAccount(
            name: "Checking",
            type: .bank,
            openingBalance: Decimal(10000),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: "3333"
        )
        
        let expenseCandidate = TransactionCandidate(
            type: .expense,
            amount: Decimal(1500),
            currencyCode: "INR",
            merchantName: "Restaurant",
            accountSuggestion: accountId,
            source: .manual
        )
        
        let txId = try await transactionService.createTransaction(expenseCandidate)
        var acc = try await accountService.getAccount(id: accountId)
        XCTAssertEqual(acc?.balance, Decimal(8500))
        
        // Deleting the expense must restore original balance
        try await transactionService.deleteTransaction(id: txId)
        acc = try await accountService.getAccount(id: accountId)
        XCTAssertEqual(acc?.balance, Decimal(10000), "Deleting expense must restore the debited amount to account balance")
    }
    
    // MARK: - 8. Category Taxonomy & Date Range Filtering
    
    @MainActor
    func testCategoryAggregationAndDateRangeFiltering() async throws {
        try await categoryService.seedDefaultCategoriesIfNeeded()
        let categories = try await categoryService.fetchCategories(type: .expense)
        XCTAssertFalse(categories.isEmpty)
        
        let foodCategory = categories.first(where: { $0.id == "cat_food" })!
        
        let accountId = try await accountService.createAccount(
            name: "Primary Bank",
            type: .bank,
            openingBalance: Decimal(20000),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: "4444"
        )
        
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let lastWeek = now.addingTimeInterval(-86400 * 7)
        
        // Create 2 food expenses and 1 older expense
        try await transactionService.createTransaction(TransactionCandidate(
            type: .expense,
            amount: Decimal(500),
            currencyCode: "INR",
            merchantName: "Cafe",
            categorySuggestion: foodCategory.id,
            accountSuggestion: accountId,
            transactionDate: now
        ))
        
        try await transactionService.createTransaction(TransactionCandidate(
            type: .expense,
            amount: Decimal(1200),
            currencyCode: "INR",
            merchantName: "Diner",
            categorySuggestion: foodCategory.id,
            accountSuggestion: accountId,
            transactionDate: yesterday
        ))
        
        try await transactionService.createTransaction(TransactionCandidate(
            type: .expense,
            amount: Decimal(3000),
            currencyCode: "INR",
            merchantName: "Old Purchase",
            categorySuggestion: "cat_shopping",
            accountSuggestion: accountId,
            transactionDate: lastWeek
        ))
        
        // Filter by date range (last 2 days)
        let twoDaysAgo = now.addingTimeInterval(-86400 * 2)
        let filtered = try await transactionService.fetchTransactions(
            startDate: twoDaysAgo,
            endDate: now.addingTimeInterval(3600),
            categoryID: foodCategory.id,
            accountID: accountId
        )
        
        XCTAssertEqual(filtered.count, 2, "Should fetch only the 2 recent food transactions")
        
        let totals = try await transactionService.calculateTotals(
            startDate: twoDaysAgo,
            endDate: now.addingTimeInterval(3600)
        )
        XCTAssertEqual(totals.expense, Decimal(1700), "500 + 1200 = 1700")
        XCTAssertEqual(totals.income, Decimal.zero)
    }
    
    // MARK: - 9. Archived Account Handling
    
    @MainActor
    func testArchivedAccountHandling() async throws {
        let activeId = try await accountService.createAccount(
            name: "Active Account",
            type: .bank,
            openingBalance: Decimal(10000),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: "1111"
        )
        
        let oldId = try await accountService.createAccount(
            name: "Closed Old Account",
            type: .bank,
            openingBalance: Decimal(5000),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "gray",
            lastFour: "2222"
        )
        
        let initialNetWorth = try await accountService.calculateNetWorth()
        XCTAssertEqual(initialNetWorth, Decimal(15000))
        
        // Archive the old account
        try await accountService.setArchived(accountID: oldId, isArchived: true)
        
        let activeList = try await accountService.fetchAccounts(includeArchived: false)
        XCTAssertEqual(activeList.count, 1)
        XCTAssertEqual(activeList.first?.id, activeId)
        
        let allList = try await accountService.fetchAccounts(includeArchived: true)
        XCTAssertEqual(allList.count, 2)
        
        let activeNetWorth = try await accountService.calculateNetWorth()
        XCTAssertEqual(activeNetWorth, Decimal(10000), "Archived accounts must be excluded from active net worth")
    }
    
    // MARK: - 10. Budget Tracking & Pace
    
    @MainActor
    func testBudgetServiceTrackingAndPace() async throws {
        try await categoryService.seedDefaultCategoriesIfNeeded()
        let now = Date()
        
        // Set monthly grocery budget = 12,000
        try await budgetService.setBudget(
            categoryID: "cat_groceries",
            limitAmount: Decimal(12000),
            month: now,
            alertThresholdPercent: 80
        )
        
        // Add grocery expense = 3,000
        let accountId = try await accountService.createAccount(
            name: "Wallet",
            type: .cash,
            openingBalance: Decimal(20000),
            currencyCode: "INR",
            icon: "banknote.fill",
            colorToken: "green",
            lastFour: nil
        )
        
        try await transactionService.createTransaction(TransactionCandidate(
            type: .expense,
            amount: Decimal(3000),
            currencyCode: "INR",
            merchantName: "Supermarket",
            categorySuggestion: "cat_groceries",
            accountSuggestion: accountId,
            transactionDate: now
        ))
        
        let budgets = try await budgetService.fetchBudgets(for: now)
        let groceryBudget = budgets.first(where: { $0.categoryID == "cat_groceries" })
        XCTAssertNotNil(groceryBudget)
        XCTAssertEqual(groceryBudget?.limitAmount, Decimal(12000))
        XCTAssertEqual(groceryBudget?.spentAmount, Decimal(3000))
        XCTAssertEqual(groceryBudget?.remainingAmount, Decimal(9000))
        XCTAssertEqual(groceryBudget?.progressPercent, 0.25, accuracy: 0.001)
        XCTAssertFalse(groceryBudget?.isExceeded ?? true)
    }
    
    // MARK: - 11. Merchant Categorization Rules
    
    @MainActor
    func testMerchantRuleServiceMatching() async throws {
        try await ruleService.saveRule(
            merchant: "Swiggy",
            categoryID: "cat_food",
            accountID: "acc_cc",
            tags: ["food", "delivery"],
            pattern: "swiggy.*",
            confidence: 0.98
        )
        
        // Exact match
        let exact = try await ruleService.findMatchingRule(for: "Swiggy")
        XCTAssertNotNil(exact)
        XCTAssertEqual(exact?.preferredCategoryID, "cat_food")
        XCTAssertEqual(exact?.confidence, 0.98)
        
        // Pattern / case-insensitive match
        let patternMatch = try await ruleService.findMatchingRule(for: "SWIGGY BANGALORE IN")
        XCTAssertNotNil(patternMatch)
        XCTAssertEqual(patternMatch?.preferredCategoryID, "cat_food")
    }
    
    // MARK: - 12. Duplicate Import Fingerprinting
    
    @MainActor
    func testImportFingerprintDuplicateDetection() async throws {
        let now = Date()
        let hash = ImportFingerprintService.computeSourceHash(
            amount: Decimal(450),
            merchant: "Uber India",
            timestamp: now,
            reference: "TXN123456"
        )
        
        try await fingerprintService.recordFingerprint(
            sourceHash: hash,
            amount: Decimal(450),
            merchant: "Uber India",
            accountLastFour: "4321",
            reference: "TXN123456",
            timestamp: now,
            source: "sms"
        )
        
        // Exact hash match
        let hasHash = try await fingerprintService.hasFingerprint(hash: hash)
        XCTAssertTrue(hasHash)
        
        // Near-time duplicate detection within 5-minute window
        let isDup = try await fingerprintService.isDuplicate(
            amount: Decimal(450),
            merchant: "Uber India",
            date: now.addingTimeInterval(60), // 1 minute later
            accountLastFour: "4321",
            windowSeconds: 300
        )
        XCTAssertTrue(isDup, "Transaction with matching amount, merchant, and account within window must be flagged as duplicate")
        
        // Different amount should not be duplicate
        let notDup = try await fingerprintService.isDuplicate(
            amount: Decimal(999),
            merchant: "Uber India",
            date: now,
            accountLastFour: "4321",
            windowSeconds: 300
        )
        XCTAssertFalse(notDup, "Transaction with different amount must not be flagged as duplicate")
    }
    
    // MARK: - 13. Credit Card Net Worth & Bill Payment Invariant (ISS-001 / ISS-003)
    
    @MainActor
    func testCreditCardExpenseAndPaymentNetWorthCalculation() async throws {
        // 1. Create a Bank account with ₹50,000
        let bankId = try await accountService.createAccount(
            name: "HDFC Salary Account",
            type: .bank,
            openingBalance: Decimal(50000),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: "1234"
        )
        
        // 2. Create a Credit Card account with ₹0 balance
        let ccId = try await accountService.createAccount(
            name: "HDFC Credit Card",
            type: .creditCard,
            openingBalance: Decimal.zero,
            currencyCode: "INR",
            icon: "creditcard.fill",
            colorToken: "purple",
            lastFour: "5678"
        )
        
        // 3. Verify initial net worth is ₹50,000
        let initialNetWorth = try await accountService.calculateNetWorth()
        XCTAssertEqual(initialNetWorth, Decimal(50000), "Initial Net Worth should be ₹50,000")
        
        // 4. Log ₹5,000 expense on Credit Card -> Credit Card balance is -₹5,000, Net Worth is ₹45,000
        let expenseCandidate = TransactionCandidate(
            type: .expense,
            amount: Decimal(5000),
            currencyCode: "INR",
            merchantName: "Flipkart",
            accountSuggestion: ccId,
            source: .manual
        )
        try await transactionService.createTransaction(expenseCandidate)
        
        let ccAccountAfterExpense = try await accountService.getAccount(id: ccId)
        XCTAssertEqual(ccAccountAfterExpense?.balance, Decimal(-5000), "Credit Card balance must be -₹5,000 after ₹5,000 expense")
        
        let postExpenseNetWorth = try await accountService.calculateNetWorth()
        XCTAssertEqual(postExpenseNetWorth, Decimal(45000), "Net worth must be ₹45,000 (50,000 bank + (-5,000) credit card debt)")
        
        // 5. Transfer ₹5,000 from Bank to Credit Card (paying card bill) -> Bank balance is ₹45,000, Credit Card balance is ₹0, Net Worth remains ₹45,000
        let billPaymentCandidate = TransactionCandidate(
            type: .transfer,
            amount: Decimal(5000),
            currencyCode: "INR",
            merchantName: "Credit Card Bill Payment",
            accountSuggestion: bankId,
            destinationAccountSuggestion: ccId,
            source: .manual
        )
        try await transactionService.createTransaction(billPaymentCandidate)
        
        let bankAccountAfterBillPay = try await accountService.getAccount(id: bankId)
        let ccAccountAfterBillPay = try await accountService.getAccount(id: ccId)
        
        XCTAssertEqual(bankAccountAfterBillPay?.balance, Decimal(45000), "Bank balance must be ₹45,000 after ₹5,000 bill payment")
        XCTAssertEqual(ccAccountAfterBillPay?.balance, Decimal.zero, "Credit Card balance must be ₹0 after bill payment")
        
        let postBillPayNetWorth = try await accountService.calculateNetWorth()
        XCTAssertEqual(postBillPayNetWorth, Decimal(45000), "Net Worth must remain ₹45,000 after internal transfer / credit card bill payment")
    }
    
    // MARK: - 14. Negative Transaction Amount Normalization (ISS-002 / ISS-003)
    
    @MainActor
    func testNegativeTransactionAmountNormalization() async throws {
        let accountId = try await accountService.createAccount(
            name: "Savings Account",
            type: .bank,
            openingBalance: Decimal(10000),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: "4321"
        )
        
        // Create an expense with a negative amount (-2500)
        let negativeExpenseCandidate = TransactionCandidate(
            type: .expense,
            amount: Decimal(-2500),
            currencyCode: "INR",
            merchantName: "Grocery Store",
            accountSuggestion: accountId,
            source: .manual
        )
        
        let txId = try await transactionService.createTransaction(negativeExpenseCandidate)
        
        // Account balance must be debited (10,000 - 2,500 = 7,500), NOT credited
        let account = try await accountService.getAccount(id: accountId)
        XCTAssertEqual(account?.balance, Decimal(7500), "Negative amount must be normalized to positive so expense debits account balance")
        
        let recent = try await transactionService.fetchRecentTransactions(limit: 1)
        XCTAssertEqual(recent.first?.amount, Decimal(2500), "Stored transaction amount must be positive 2,500")
        
        // Update transaction with negative amount (-4000)
        var updatedCandidate = negativeExpenseCandidate
        updatedCandidate.amount = Decimal(-4000)
        try await transactionService.updateTransaction(id: txId, candidate: updatedCandidate)
        
        let updatedAccount = try await accountService.getAccount(id: accountId)
        XCTAssertEqual(updatedAccount?.balance, Decimal(6000), "Updating with negative amount must normalize and result in 10,000 - 4,000 = 6,000")
    }
}
