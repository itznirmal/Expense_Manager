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
        let paddedEquals = "  =SUM(A1:A10)"
        
        XCTAssertEqual(CSVFormulaSanitizer.neutralize(equalsInput), "'=SUM(A1:A10)")
        XCTAssertEqual(CSVFormulaSanitizer.neutralize(cmdInput), "'+cmd|' /C calc'!A0")
        XCTAssertEqual(CSVFormulaSanitizer.neutralize(atInput), "'@SUM(B1:B5)")
        XCTAssertEqual(CSVFormulaSanitizer.neutralize(minusInput), "'-12345")
        XCTAssertEqual(CSVFormulaSanitizer.neutralize(tabInput), "'\tTabbedMerchant")
        XCTAssertEqual(CSVFormulaSanitizer.neutralize(carriageInput), "'\rCarriageMerchant")
        XCTAssertEqual(CSVFormulaSanitizer.neutralize(normalInput), "Starbucks Coffee")
        XCTAssertEqual(CSVFormulaSanitizer.neutralize(paddedEquals), "'  =SUM(A1:A10)")
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
        let _ = try await dependencyContainer.accountService.createAccount(
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
        let tx1 = TransactionCandidate(
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
        try await dependencyContainer.transactionService.createTransaction(tx1)
        
        // Seed Transaction 2: Normal transaction
        let tx2 = TransactionCandidate(
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
        try await dependencyContainer.transactionService.createTransaction(tx2)
        
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
        let _ = try await dependencyContainer.accountService.createAccount(
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
        let tx1 = TransactionCandidate(
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
        try await dependencyContainer.transactionService.createTransaction(tx1)
        
        // 4. Seed Budget
        try await dependencyContainer.budgetService.setBudget(
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

    @MainActor
    func testPendingReviewStateRoundTripsThroughJSONBackup() async throws {
        try await dependencyContainer.categoryService.seedDefaultCategoriesIfNeeded()

        let transactionID = UUID()
        let pendingCandidate = TransactionCandidate(
            id: transactionID,
            type: .expense,
            amount: Decimal(725),
            currencyCode: "INR",
            merchantName: "Unknown Merchant",
            categorySuggestion: "Food & Dining",
            source: .smartText,
            confidence: ConfidenceScore(0.42),
            needsReview: true,
            warnings: ["Low confidence"]
        )
        try await dependencyContainer.transactionService.createTransaction(pendingCandidate)

        let records = try modelContainer.mainContext.fetch(FetchDescriptor<TransactionRecord>())
        let pendingRecord = try XCTUnwrap(records.first(where: { $0.id == transactionID.uuidString }))
        pendingRecord.reviewReasons = ["Low confidence", "Account not identified"]
        try modelContainer.mainContext.save()

        let backupData = try await exportService.exportJSONBackup()
        let payload = try exportService.validateBackupPayload(backupData)
        let exportedTransaction = try XCTUnwrap(payload.data.transactions.first)
        XCTAssertTrue(exportedTransaction.isPendingReview)
        XCTAssertFalse(exportedTransaction.isAccepted)
        XCTAssertEqual(exportedTransaction.reviewReasons, ["Low confidence", "Account not identified"])

        try await exportService.purgeAllData(restoreDefaultCategories: false)
        _ = try await exportService.restoreJSONBackup(from: backupData)

        let restoredRecords = try modelContainer.mainContext.fetch(FetchDescriptor<TransactionRecord>())
        let restoredRecord = try XCTUnwrap(restoredRecords.first(where: { $0.id == transactionID.uuidString }))
        XCTAssertTrue(restoredRecord.isPendingReview)
        XCTAssertFalse(restoredRecord.isAccepted)
        XCTAssertEqual(restoredRecord.reviewReasons, ["Low confidence", "Account not identified"])
    }

    @MainActor
    func testLegacyBackupWithoutReviewStateDefaultsSafely() async throws {
        let timestamp = Date(timeIntervalSince1970: 1_730_000_000)
        // This fixture intentionally models the pre-ISS-018 wire format instead of
        // using TransactionBackupDTO, whose encoder now owns review-state compatibility.
        let legacyTransaction = LegacyTransactionBackupDTO(
            id: "legacy-tx",
            type: "expense",
            amount: Decimal(250),
            currencyCode: "INR",
            merchantName: "Legacy Merchant",
            categoryID: "legacy-category",
            accountID: nil,
            destinationAccountID: nil,
            paymentMethod: nil,
            transactionDate: timestamp,
            notes: nil,
            tags: [],
            source: "manual",
            sourceReference: nil,
            confidence: 1.0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let legacyData = LegacyBackupData(
            accounts: [],
            categories: [
                CategoryBackupDTO(
                    id: "legacy-category",
                    name: "Legacy",
                    parentCategoryID: nil,
                    icon: "tag.fill",
                    colorToken: "blue",
                    type: "expense",
                    isSystem: false,
                    sortOrder: 1
                )
            ],
            tags: [],
            transactions: [legacyTransaction],
            budgets: [],
            merchantRules: [],
            importFingerprints: nil
        )

        // Keep the legacy bytes independent of DataExportService's current encoder.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let legacyDataBytes = try encoder.encode(legacyData)
        let legacyObject = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: legacyDataBytes) as? [String: Any]
        )
        let legacyTransactions = try XCTUnwrap(legacyObject["transactions"] as? [[String: Any]])
        let legacyTransactionObject = try XCTUnwrap(legacyTransactions.first)
        XCTAssertNil(legacyTransactionObject["isPendingReview"])
        XCTAssertNil(legacyTransactionObject["isAccepted"])
        XCTAssertNil(legacyTransactionObject["reviewReasons"])

        let legacyPayload = LegacyBackupPayload(
            checksum: DataExportService.computeSHA256(for: legacyDataBytes),
            data: legacyData
        )
        let legacyPayloadData = try encoder.encode(legacyPayload)

        let decodedPayload = try exportService.validateBackupPayload(legacyPayloadData)
        let decodedTransaction = try XCTUnwrap(decodedPayload.data.transactions.first)
        XCTAssertFalse(decodedTransaction.isPendingReview)
        XCTAssertTrue(decodedTransaction.isAccepted)
        XCTAssertTrue(decodedTransaction.reviewReasons.isEmpty)

        let restoreResult = try await exportService.restoreJSONBackup(from: legacyPayloadData)
        XCTAssertEqual(restoreResult.categoriesRestored, 1)
        XCTAssertEqual(restoreResult.transactionsRestored, 1)
        let restoredRecords = try modelContainer.mainContext.fetch(FetchDescriptor<TransactionRecord>())
        let restoredRecord = try XCTUnwrap(restoredRecords.first(where: { $0.id == "legacy-tx" }))
        XCTAssertFalse(restoredRecord.isPendingReview)
        XCTAssertTrue(restoredRecord.isAccepted)
        XCTAssertTrue(restoredRecord.reviewReasons.isEmpty)
    }
    
    // MARK: - 4. SHA-256 Tampering Detection Tests
    
    @MainActor
    func testJSONBackupChecksumTamperingDetection() async throws {
        // Seed sample data and export
        let _ = try await dependencyContainer.accountService.createAccount(
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
        let payload = try DataExportService.createJSONDecoder().decode(BackupPayload.self, from: originalBackupData)
        
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
            merchantRules: payload.data.merchantRules,
            importFingerprints: payload.data.importFingerprints
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

    @MainActor
    func testBackupValidationRejectsUnsupportedVersionAndInvalidGraph() async throws {
        let sourceData = try await MockDataExportService().exportJSONBackup()
        let sourcePayload = try DataExportService.createJSONDecoder().decode(BackupPayload.self, from: sourceData)

        let unsupportedVersion = try encodePayload(
            data: sourcePayload.data,
            schemaVersion: 0,
            exportedAt: sourcePayload.exportedAt
        )
        XCTAssertThrowsError(try exportService.validateBackupPayload(unsupportedVersion)) { error in
            XCTAssertEqual(error as? DataExportError, .unsupportedSchemaVersion(0))
        }

        let duplicateAccount = try XCTUnwrap(sourcePayload.data.accounts.first)
        let duplicateIDData = BackupData(
            accounts: sourcePayload.data.accounts + [duplicateAccount],
            categories: sourcePayload.data.categories,
            tags: sourcePayload.data.tags,
            transactions: sourcePayload.data.transactions,
            budgets: sourcePayload.data.budgets,
            merchantRules: sourcePayload.data.merchantRules,
            importFingerprints: sourcePayload.data.importFingerprints
        )
        XCTAssertThrowsError(try exportService.validateBackupPayload(try encodePayload(data: duplicateIDData))) { error in
            guard case .backupDecodingFailed(let reason) = error as? DataExportError else {
                return XCTFail("Expected structural validation failure, got \(error)")
            }
            XCTAssertTrue(reason.contains("Duplicate identifier"))
        }

        let existingAccount = AccountRecord(id: "existing-account", name: "Keep Me")
        modelContainer.mainContext.insert(existingAccount)
        try modelContainer.mainContext.save()
        do {
            _ = try await exportService.restoreJSONBackup(from: try encodePayload(data: duplicateIDData))
            XCTFail("Invalid graph must not restore")
        } catch {
            XCTAssertTrue(error is DataExportError)
        }
        let survivingAccounts = try modelContainer.mainContext.fetch(FetchDescriptor<AccountRecord>())
        XCTAssertTrue(survivingAccounts.contains(where: { $0.id == "existing-account" }))

        let danglingTransaction = try XCTUnwrap(sourcePayload.data.transactions.first)
        let invalidTransaction = TransactionBackupDTO(
            id: danglingTransaction.id,
            type: danglingTransaction.type,
            amount: danglingTransaction.amount,
            currencyCode: danglingTransaction.currencyCode,
            merchantName: danglingTransaction.merchantName,
            categoryID: "missing-category",
            accountID: danglingTransaction.accountID,
            destinationAccountID: danglingTransaction.destinationAccountID,
            paymentMethod: danglingTransaction.paymentMethod,
            transactionDate: danglingTransaction.transactionDate,
            notes: danglingTransaction.notes,
            tags: danglingTransaction.tags,
            source: danglingTransaction.source,
            sourceReference: danglingTransaction.sourceReference,
            confidence: danglingTransaction.confidence,
            createdAt: danglingTransaction.createdAt,
            updatedAt: danglingTransaction.updatedAt,
            isPendingReview: danglingTransaction.isPendingReview,
            isAccepted: danglingTransaction.isAccepted,
            reviewReasons: danglingTransaction.reviewReasons,
            parentTransactionID: danglingTransaction.parentTransactionID,
            splitGroupID: danglingTransaction.splitGroupID
        )
        let danglingReferenceData = BackupData(
            accounts: sourcePayload.data.accounts,
            categories: sourcePayload.data.categories,
            tags: sourcePayload.data.tags,
            transactions: [invalidTransaction],
            budgets: sourcePayload.data.budgets,
            merchantRules: sourcePayload.data.merchantRules,
            importFingerprints: sourcePayload.data.importFingerprints
        )
        XCTAssertThrowsError(try exportService.validateBackupPayload(try encodePayload(data: danglingReferenceData))) { error in
            guard case .backupDecodingFailed(let reason) = error as? DataExportError else {
                return XCTFail("Expected foreign-key validation failure, got \(error)")
            }
            XCTAssertTrue(reason.contains("unknown category"))
        }

        let inconsistentReviewData = BackupData(
            accounts: sourcePayload.data.accounts,
            categories: sourcePayload.data.categories,
            tags: sourcePayload.data.tags,
            transactions: [TransactionBackupDTO(
                id: danglingTransaction.id,
                type: danglingTransaction.type,
                amount: danglingTransaction.amount,
                currencyCode: danglingTransaction.currencyCode,
                merchantName: danglingTransaction.merchantName,
                categoryID: danglingTransaction.categoryID,
                accountID: danglingTransaction.accountID,
                destinationAccountID: danglingTransaction.destinationAccountID,
                paymentMethod: danglingTransaction.paymentMethod,
                transactionDate: danglingTransaction.transactionDate,
                notes: danglingTransaction.notes,
                tags: danglingTransaction.tags,
                source: danglingTransaction.source,
                sourceReference: danglingTransaction.sourceReference,
                confidence: danglingTransaction.confidence,
                createdAt: danglingTransaction.createdAt,
                updatedAt: danglingTransaction.updatedAt,
                isPendingReview: true,
                isAccepted: true,
                reviewReasons: ["needs review"],
                parentTransactionID: danglingTransaction.parentTransactionID,
                splitGroupID: danglingTransaction.splitGroupID
            )],
            budgets: sourcePayload.data.budgets,
            merchantRules: sourcePayload.data.merchantRules,
            importFingerprints: sourcePayload.data.importFingerprints
        )
        XCTAssertThrowsError(try exportService.validateBackupPayload(try encodePayload(data: inconsistentReviewData))) { error in
            guard case .backupDecodingFailed(let reason) = error as? DataExportError else {
                return XCTFail("Expected review-state validation failure, got \(error)")
            }
            XCTAssertTrue(reason.contains("Review state"))
        }
    }

    @MainActor
    func testBackupValidationAcceptsISOCodeOutsideUIDisplayListAndTrailingZeros() throws {
        let amount = try XCTUnwrap(Decimal(string: "12.3400", locale: Locale(identifier: "en_US_POSIX")))
        let timestamp = Date(timeIntervalSince1970: 1_730_000_000)
        let account = AccountBackupDTO(
            id: "bhd-account",
            name: "Bahrain Account",
            type: AccountType.bank.rawValue,
            currencyCode: "BHD",
            openingBalance: amount,
            currentBalance: amount,
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: nil,
            isArchived: false,
            createdAt: timestamp
        )
        let data = BackupData(accounts: [account])

        XCTAssertFalse(CurrencyFormatter.supportedCurrencyCodes.contains("BHD"))
        XCTAssertTrue(Locale.commonISOCurrencyCodes.contains("BHD"))
        XCTAssertNoThrow(try exportService.validateBackupPayload(try encodePayload(data: data)))
    }

    @MainActor
    func testSplitTransactionsRoundTripAfterOriginalParentIsDeleted() async throws {
        let accountID = try await dependencyContainer.accountService.createAccount(
            name: "Split Account",
            type: .bank,
            openingBalance: Decimal(100),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: nil
        )
        try await dependencyContainer.categoryService.seedDefaultCategoriesIfNeeded()

        let parentID = try await dependencyContainer.transactionService.createTransaction(
            TransactionCandidate(
                amount: Decimal(100),
                currencyCode: "INR",
                merchantName: "Household Purchase",
                categorySuggestion: "Shopping",
                accountSuggestion: accountID,
                source: .manual
            )
        )
        let childIDs = try await dependencyContainer.transactionService.splitTransaction(
            id: parentID,
            splits: [
                TransactionSplitLine(amount: Decimal(40), categoryName: "Food & Dining", merchantName: "Groceries"),
                TransactionSplitLine(amount: Decimal(60), categoryName: "Shopping", merchantName: "Household Supplies")
            ]
        )

        let splitRecords = try modelContainer.mainContext.fetch(FetchDescriptor<TransactionRecord>())
        XCTAssertEqual(splitRecords.count, 2)
        XCTAssertFalse(splitRecords.contains(where: { $0.id == parentID }))
        XCTAssertTrue(splitRecords.allSatisfy { $0.parentTransactionID == parentID })
        XCTAssertEqual(Set(splitRecords.compactMap(\.splitGroupID)).count, 1)
        XCTAssertEqual(Set(splitRecords.map(\.id)), Set(childIDs))

        let backupData = try await exportService.exportJSONBackup()
        try await exportService.purgeAllData(restoreDefaultCategories: false)
        let restoreResult = try await exportService.restoreJSONBackup(from: backupData)

        XCTAssertEqual(restoreResult.transactionsRestored, 2)
        let restoredRecords = try modelContainer.mainContext.fetch(FetchDescriptor<TransactionRecord>())
        XCTAssertEqual(restoredRecords.count, 2)
        XCTAssertFalse(restoredRecords.contains(where: { $0.id == parentID }))
        XCTAssertTrue(restoredRecords.allSatisfy { $0.parentTransactionID == parentID })
        XCTAssertEqual(Set(restoredRecords.compactMap(\.splitGroupID)).count, 1)
        XCTAssertEqual(restoredRecords.map(\.amount).reduce(Decimal.zero, +), Decimal(100))
    }

    func testBudgetCurrencyPreservesLegacyINRWireAndEncodesExplicitCurrency() throws {
        let legacy = BudgetBackupDTO(
            id: "budget-inr",
            categoryID: nil,
            limitAmount: Decimal(1000),
            month: Date(timeIntervalSince1970: 1_730_000_000),
            alertThresholdPercent: 80,
            createdAt: Date(timeIntervalSince1970: 1_730_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_730_000_000)
        )
        let legacyObject = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: DataExportService.createJSONEncoder().encode(legacy)) as? [String: Any]
        )
        XCTAssertNil(legacyObject["currencyCode"])

        let decodedLegacy = try DataExportService.createJSONDecoder().decode(
            BudgetBackupDTO.self,
            from: DataExportService.createJSONEncoder().encode(legacy)
        )
        XCTAssertEqual(decodedLegacy.currencyCode, "INR")

        let usd = BudgetBackupDTO(
            id: "budget-usd",
            categoryID: nil,
            currencyCode: "USD",
            limitAmount: Decimal(1000),
            month: legacy.month,
            alertThresholdPercent: 80,
            createdAt: legacy.createdAt,
            updatedAt: legacy.updatedAt
        )
        let usdObject = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: DataExportService.createJSONEncoder().encode(usd)) as? [String: Any]
        )
        XCTAssertEqual(usdObject["currencyCode"] as? String, "USD")
    }
    
    // MARK: - 5. Database Purge / Factory Reset Tests
    
    @MainActor
    func testDatabasePurgeAndDefaultCategoriesRestoration() async throws {
        // Seed custom accounts, transactions, and custom categories
        let _ = try await dependencyContainer.accountService.createAccount(
            name: "SBI Savings",
            type: .bank,
            openingBalance: Decimal(25000),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: "5555"
        )
        
        let _ = try await dependencyContainer.categoryService.createCategory(
            name: "Custom Hobby",
            parentCategoryID: nil,
            icon: "paintbrush.fill",
            colorToken: "purple",
            type: .expense
        )
        
        let tx = TransactionCandidate(
            type: .expense,
            amount: Decimal(2000),
            currencyCode: "INR",
            merchantName: "Art Store",
            categorySuggestion: "Custom Hobby",
            accountSuggestion: "SBI Savings",
            source: .manual
        )
        try await dependencyContainer.transactionService.createTransaction(tx)
        
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

    private func encodePayload(
        data: BackupData,
        schemaVersion: Int = 1,
        exportedAt: Date = Date(timeIntervalSince1970: 1_730_000_000)
    ) throws -> Data {
        let encoder = DataExportService.createJSONEncoder()
        let checksum = DataExportService.computeSHA256(for: try encoder.encode(data))
        return try encoder.encode(BackupPayload(
            schemaVersion: schemaVersion,
            appVersion: "1.0.0",
            exportedAt: exportedAt,
            checksum: checksum,
            data: data
        ))
    }
}

// MARK: - Pre-ISS-018 Backup Fixture

/// The schema-version-1 transaction shape written before review-state fields existed.
/// Keep this DTO separate from TransactionBackupDTO so the compatibility test cannot
/// accidentally derive its legacy bytes from the current production encoder.
private struct LegacyTransactionBackupDTO: Encodable {
    let id: String
    let type: String
    let amount: Decimal
    let currencyCode: String
    let merchantName: String
    let categoryID: String?
    let accountID: String?
    let destinationAccountID: String?
    let paymentMethod: String?
    let transactionDate: Date
    let notes: String?
    let tags: [String]
    let source: String
    let sourceReference: String?
    let confidence: Double
    let createdAt: Date
    let updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case amount
        case currencyCode
        case merchantName
        case categoryID
        case accountID
        case destinationAccountID
        case paymentMethod
        case transactionDate
        case notes
        case tags
        case source
        case sourceReference
        case confidence
        case createdAt
        case updatedAt
    }
}

private struct LegacyBackupData: Encodable {
    let accounts: [AccountBackupDTO]
    let categories: [CategoryBackupDTO]
    let tags: [TagBackupDTO]
    let transactions: [LegacyTransactionBackupDTO]
    let budgets: [BudgetBackupDTO]
    let merchantRules: [MerchantRuleBackupDTO]
    let importFingerprints: [ImportFingerprintBackupDTO]?
}

private struct LegacyBackupPayload: Encodable {
    let schemaVersion: Int
    let appVersion: String
    let exportedAt: Date
    let checksum: String
    let data: LegacyBackupData

    init(
        schemaVersion: Int = 1,
        appVersion: String = "1.0.0",
        exportedAt: Date = Date(timeIntervalSince1970: 1_730_000_000),
        checksum: String,
        data: LegacyBackupData
    ) {
        self.schemaVersion = schemaVersion
        self.appVersion = appVersion
        self.exportedAt = exportedAt
        self.checksum = checksum
        self.data = data
    }
}
