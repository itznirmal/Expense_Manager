//
//  DataExportAndSecurityTests.swift
//  ExpenseManagerTests
//
//  Created for Expense Manager iOS.
//  Unit Tests for CSV Formula Injection Neutralization (AC-SEC-1), JSON Backup Checksums, and Data Purge.
//

import XCTest
import SwiftData
@testable import ExpenseManager

final class DataExportAndSecurityTests: XCTestCase {
    
    private var modelContainer: ModelContainer!
    private var exportService: DataExportService!
    private var dependencyContainer: DependencyContainer!
    private var appState: AppState!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        modelContainer = try DatabaseContainer.inMemory()
        dependencyContainer = DependencyContainer.live(modelContainer: modelContainer)
        exportService = DataExportService(modelContainer: modelContainer)
        appState = AppState()
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        exportService = nil
        dependencyContainer = nil
        appState = nil
        try await super.tearDown()
    }
    
    // MARK: - 1. CSV Formula Sanitizer (AC-SEC-1) Tests
    
    func testCSVFormulaSanitizerNeutralization() {
        // Adversarial inputs starting with =, +, -, @, \t, \r
        let equalsInput = "=SUM(A1:A10)"
        let cmdInput = "+cmd|' /C calc'!A0"
        let atInput = "@SUM(B1:B5)"
        let minusInput = "-12345"
        let tabInput = "\tTabbedMerchant"
        let carriageInput = "\rCarriageMerchant"
        let normalInput = "Starbucks Coffee"
        
        XCTAssertEqual(CSVFormulaSanitizer.neutralize(equalsInput), "'=SUM(A1:A10)")
        XCTAssertEqual(CSVFormulaSanitizer.neutralize(cmdInput), "'+cmd|' /C calc'!A0")
        XCTAssertEqual(CSVFormulaSanitizer.neutralize(atInput), "'@SUM(B1:B5)")
        XCTAssertEqual(CSVFormulaSanitizer.neutralize(minusInput), "'-12345")
        XCTAssertEqual(CSVFormulaSanitizer.neutralize(tabInput), "'\tTabbedMerchant")
        XCTAssertEqual(CSVFormulaSanitizer.neutralize(carriageInput), "'\rCarriageMerchant")
        XCTAssertEqual(CSVFormulaSanitizer.neutralize(normalInput), "Starbucks Coffee")
    }
    
    func testCSVFormulaSanitizerEscapingAndQuotes() {
        // Test RFC-4180 escaping with neutralized formula triggers
        let formulaWithComma = "=HYPERLINK(\"http://evil.com\", \"Click Me\")"
        let escapedFormula = CSVFormulaSanitizer.sanitizeAndEscape(formulaWithComma)
        XCTAssertTrue(escapedFormula.hasPrefix("\"'"))
        XCTAssertTrue(escapedFormula.contains("\"\"http://evil.com\"\""))
        
        // Regular string with commas and quotes
        let complexText = "Cafe \"Mocha\", Downtown"
        let escapedComplex = CSVFormulaSanitizer.sanitizeAndEscape(complexText)
        XCTAssertEqual(escapedComplex, "\"Cafe \"\"Mocha\"\", Downtown\"")
        
        // Safe plain text
        let safeText = "Uber India"
        XCTAssertEqual(CSVFormulaSanitizer.sanitizeAndEscape(safeText), "Uber India")
    }
    
    // MARK: - 2. CSV Ledger Export Tests
    
    @MainActor
    func testCSVExportFormattingAndAdversarialNeutralization() async throws {
        // Seed an account and default categories
        let accountID = try await dependencyContainer.accountService.createAccount(
            name: "HDFC Primary",
            type: .bank,
            openingBalance: Decimal(50000),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: "4321"
        )
        
        try await dependencyContainer.categoryService.seedDefaultCategoriesIfNeeded()
        let categories = try await dependencyContainer.categoryService.fetchCategories(type: nil)
        let foodCategory = categories.first(where: { $0.name.contains("Food") })!
        
        // Seed Transaction 1: Formula in merchant name
        var tx1 = TransactionCandidate(
            type: .expense,
            amount: Decimal(1500),
            currencyCode: "INR",
            merchantName: "=SUM(A1:A10)",
            categorySuggestion: foodCategory.name,
            accountSuggestion: "HDFC Primary",
            paymentMethod: .upi,
            transactionDate: Date(),
            notes: "+cmd|' /C calc'!A0",
            tags: ["@tax-deductible", "business"],
            source: .smartText,
            sourceReference: "-REF9999"
        )
        try await dependencyContainer.transactionService.saveTransaction(candidate: tx1)
        
        // Seed Transaction 2: Normal transaction
        var tx2 = TransactionCandidate(
            type: .income,
            amount: Decimal(85000),
            currencyCode: "INR",
            merchantName: "Acme Technologies, Inc.",
            categorySuggestion: "Salary",
            accountSuggestion: "HDFC Primary",
            paymentMethod: .netBanking,
            transactionDate: Date().addingTimeInterval(-3600),
            notes: "Monthly Payroll \"Bonus Included\"",
            tags: ["salary", "payroll"],
            source: .manual,
            sourceReference: "NEFT-12345"
        )
        try await dependencyContainer.transactionService.saveTransaction(candidate: tx2)
        
        // Export CSV
        let csvString = try await exportService.exportTransactionsToCSV(startDate: nil, endDate: nil)
        XCTAssertFalse(csvString.isEmpty)
        
        let lines = csvString.components(separatedBy: "\r\n")
        XCTAssertGreaterThanOrEqual(lines.count, 3)
        
        // Check header line
        let header = lines[0]
        XCTAssertEqual(header, "ID,Date,Type,Amount,Currency,Merchant,Category,Account,DestinationAccount,PaymentMethod,ReferenceNumber,Source,Notes,Tags")
        
        // Verify formula neutralization in CSV rows
        let fullCSV = csvString
        XCTAssertTrue(fullCSV.contains("'=SUM(A1:A10)"), "Formula trigger '=' must be escaped with single quote")
        XCTAssertTrue(fullCSV.contains("'+cmd|' /C calc'!A0"), "Formula trigger '+' must be escaped with single quote")
        XCTAssertTrue(fullCSV.contains("'@tax-deductible"), "Formula trigger '@' must be escaped with single quote")
        XCTAssertTrue(fullCSV.contains("'-REF9999"), "Formula trigger '-' must be escaped with single quote")
        XCTAssertTrue(fullCSV.contains("\"Acme Technologies, Inc.\""), "Commas in merchant must be quoted")
        XCTAssertTrue(fullCSV.contains("\"Monthly Payroll \"\"Bonus Included\"\"\""), "Quotes in notes must be escaped")
    }
    
    // MARK: - 3. JSON Backup Export & Round-Trip Restoration Tests
    
    @MainActor
    func testJSONBackupExportAndRoundTripRestore() async throws {
        // 1. Seed Accounts
        let hdfcID = try await dependencyContainer.accountService.createAccount(
            name: "HDFC Salary Account",
            type: .bank,
            openingBalance: Decimal(120000),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: "9876"
        )
        let cashID = try await dependencyContainer.accountService.createAccount(
            name: "Pocket Cash",
            type: .cash,
            openingBalance: Decimal(3500),
            currencyCode: "INR",
            icon: "banknote.fill",
            colorToken: "green",
            lastFour: nil
        )
        
        // 2. Seed Categories
        try await dependencyContainer.categoryService.seedDefaultCategoriesIfNeeded()
        let customCatID = try await dependencyContainer.categoryService.createCategory(
            name: "Gadgets & Electronics",
            parentCategoryID: nil,
            icon: "laptopcomputer",
            colorToken: "indigo",
            type: .expense
        )
        
        // 3. Seed Transactions
        var tx1 = TransactionCandidate(
            type: .expense,
            amount: Decimal(45000),
            currencyCode: "INR",
            merchantName: "Apple Store BKC",
            categorySuggestion: "Gadgets & Electronics",
            accountSuggestion: "HDFC Salary Account",
            paymentMethod: .creditCard,
            transactionDate: Date(),
            notes: "iPad Air M2 purchase",
            tags: ["electronics", "work"],
            source: .manual
        )
        try await dependencyContainer.transactionService.saveTransaction(candidate: tx1)
        
        // 4. Seed Budget
        try await dependencyContainer.budgetService.saveBudget(
            categoryID: customCatID,
            limitAmount: Decimal(50000),
            month: Date(),
            alertThresholdPercent: 85
        )
        
        // 5. Seed Merchant Rule
        try await dependencyContainer.merchantRuleService?.saveRule(
            merchant: "apple store",
            categoryID: customCatID,
            accountID: hdfcID,
            tags: ["electronics"],
            pattern: "apple store.*",
            confidence: 0.98
        )
        
        // Export JSON Backup
        let backupData = try await exportService.exportJSONBackup()
        XCTAssertFalse(backupData.isEmpty)
        
        // Validate Payload Structure & SHA-256 Checksum
        let payload = try exportService.validateBackupPayload(backupData)
        XCTAssertEqual(payload.schemaVersion, 1)
        XCTAssertEqual(payload.appVersion, "1.0.0")
        XCTAssertFalse(payload.checksum.isEmpty)
        XCTAssertEqual(payload.data.accounts.count, 2)
        XCTAssertEqual(payload.data.transactions.count, 1)
        XCTAssertEqual(payload.data.budgets.count, 1)
        XCTAssertEqual(payload.data.merchantRules.count, 1)
        
        // Modify Database State (simulate data loss or purge)
        try await exportService.purgeAllData(restoreDefaultCategories: false)
        
        let accountsAfterPurge = try await dependencyContainer.accountService.fetchAccounts(includeArchived: true)
        XCTAssertTrue(accountsAfterPurge.isEmpty)
        
        // Restore from Backup
        let restoreResult = try await exportService.restoreJSONBackup(from: backupData)
        XCTAssertEqual(restoreResult.accountsRestored, 2)
        XCTAssertEqual(restoreResult.transactionsRestored, 1)
        XCTAssertEqual(restoreResult.budgetsRestored, 1)
        XCTAssertEqual(restoreResult.rulesRestored, 1)
        
        // Verify restored records
        let restoredAccounts = try await dependencyContainer.accountService.fetchAccounts(includeArchived: true)
        XCTAssertEqual(restoredAccounts.count, 2)
        XCTAssertTrue(restoredAccounts.contains(where: { $0.name == "HDFC Salary Account" && $0.balance == Decimal(120000) }))
        XCTAssertTrue(restoredAccounts.contains(where: { $0.name == "Pocket Cash" && $0.balance == Decimal(3500) }))
        
        let restoredTxs = try await dependencyContainer.transactionService.fetchRecentTransactions(limit: 10)
        XCTAssertEqual(restoredTxs.count, 1)
        XCTAssertEqual(restoredTxs.first?.merchantName, "Apple Store BKC")
        XCTAssertEqual(restoredTxs.first?.amount, Decimal(45000))
        XCTAssertEqual(restoredTxs.first?.notes, "iPad Air M2 purchase")
    }
    
    // MARK: - 4. SHA-256 Tampering Detection Tests
    
    @MainActor
    func testJSONBackupChecksumTamperingDetection() async throws {
        // Seed sample data and export
        try await dependencyContainer.accountService.createAccount(
            name: "Axis Bank",
            type: .bank,
            openingBalance: Decimal(10000),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "red",
            lastFour: "1122"
        )
        
        let originalBackupData = try await exportService.exportJSONBackup()
        
        // Decode to modify data without updating the checksum
        var payload = try DataExportService.createJSONDecoder().decode(BackupPayload.self, from: originalBackupData)
        
        // Create tampered data with manipulated account balance (fraudulent modification)
        let tamperedAccounts = payload.data.accounts.map { acc in
            AccountBackupDTO(
                id: acc.id,
                name: acc.name,
                type: acc.type,
                currencyCode: acc.currencyCode,
                openingBalance: Decimal(999999999), // Tampered balance!
                currentBalance: Decimal(999999999),
                icon: acc.icon,
                colorToken: acc.colorToken,
                lastFour: acc.lastFour,
                isArchived: acc.isArchived,
                createdAt: acc.createdAt
            )
        }
        
        let tamperedData = BackupData(
            accounts: tamperedAccounts,
            categories: payload.data.categories,
            tags: payload.data.tags,
            transactions: payload.data.transactions,
            budgets: payload.data.budgets,
            merchantRules: payload.data.merchantRules
        )
        
        // Rebuild payload with original (stale) checksum
        let tamperedPayload = BackupPayload(
            schemaVersion: payload.schemaVersion,
            appVersion: payload.appVersion,
            exportedAt: payload.exportedAt,
            checksum: payload.checksum, // Stale checksum
            data: tamperedData
        )
        
        let tamperedJSONData = try DataExportService.createJSONEncoder().encode(tamperedPayload)
        
        // Validate must throw checksum mismatch
        XCTAssertThrowsError(try exportService.validateBackupPayload(tamperedJSONData)) { error in
            guard case DataExportError.checksumMismatch = error else {
                XCTFail("Expected checksumMismatch error, got \(error)")
                return
            }
        }
        
        // Restore must fail
        do {
            _ = try await exportService.restoreJSONBackup(from: tamperedJSONData)
            XCTFail("Restoring tampered backup should have thrown an error")
        } catch {
            // Expected
            XCTAssertTrue(error is DataExportError)
        }
    }
    
    // MARK: - 5. Database Purge / Factory Reset Tests
    
    @MainActor
    func testDatabasePurgeAndDefaultCategoriesRestoration() async throws {
        // Seed custom accounts, transactions, and custom categories
        let accID = try await dependencyContainer.accountService.createAccount(
            name: "SBI Savings",
            type: .bank,
            openingBalance: Decimal(25000),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: "5555"
        )
        
        let customCatID = try await dependencyContainer.categoryService.createCategory(
            name: "Custom Hobby",
            parentCategoryID: nil,
            icon: "paintbrush.fill",
            colorToken: "purple",
            type: .expense
        )
        
        var tx = TransactionCandidate(
            type: .expense,
            amount: Decimal(2000),
            currencyCode: "INR",
            merchantName: "Art Store",
            categorySuggestion: "Custom Hobby",
            accountSuggestion: "SBI Savings",
            source: .manual
        )
        try await dependencyContainer.transactionService.saveTransaction(candidate: tx)
        
        // Verify records exist before purge
        let preTxs = try await dependencyContainer.transactionService.fetchRecentTransactions(limit: 10)
        let preAccounts = try await dependencyContainer.accountService.fetchAccounts(includeArchived: true)
        XCTAssertEqual(preTxs.count, 1)
        XCTAssertEqual(preAccounts.count, 1)
        
        // Execute Factory Reset
        try await exportService.purgeAllData(restoreDefaultCategories: true)
        
        // Verify user data is wiped
        let postTxs = try await dependencyContainer.transactionService.fetchRecentTransactions(limit: 10)
        let postAccounts = try await dependencyContainer.accountService.fetchAccounts(includeArchived: true)
        XCTAssertTrue(postTxs.isEmpty)
        XCTAssertTrue(postAccounts.isEmpty)
        
        // Verify default system categories are restored
        let categories = try await dependencyContainer.categoryService.fetchCategories(type: nil)
        XCTAssertEqual(categories.count, 10)
        XCTAssertTrue(categories.allSatisfy { $0.isSystem })
        XCTAssertTrue(categories.contains(where: { $0.name == "Food & Dining" }))
        XCTAssertTrue(categories.contains(where: { $0.name == "Groceries" }))
        XCTAssertTrue(categories.contains(where: { $0.name == "Salary" }))
    }
    
    // MARK: - 6. SettingsViewModel Workflow Tests
    
    @MainActor
    func testSettingsViewModelExportAndRestoreWorkflows() async throws {
        let mockService = MockDataExportService()
        let viewModel = SettingsViewModel(exportService: mockService)
        
        // Test CSV Export
        await viewModel.exportCSV(appState: appState)
        XCTAssertNotNil(viewModel.csvExportURL)
        XCTAssertEqual(appState.activeToast?.title, "CSV Export Ready")
        
        // Test JSON Backup Export
        await viewModel.exportJSONBackup(appState: appState)
        XCTAssertNotNil(viewModel.backupExportURL)
        XCTAssertEqual(appState.activeToast?.title, "Backup Created")
        
        // Test Restore Execution
        let backupData = try await mockService.exportJSONBackup()
        viewModel.selectedRestoreData = backupData
        await viewModel.executeRestore(appState: appState)
        XCTAssertEqual(appState.activeToast?.title, "Restore Complete")
        
        // Test Purge Execution
        await viewModel.executePurge(appState: appState)
        XCTAssertTrue(mockService.purged)
        XCTAssertEqual(appState.activeToast?.title, "Database Reset")
    }
}
