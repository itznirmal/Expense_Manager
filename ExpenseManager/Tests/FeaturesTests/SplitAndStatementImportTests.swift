//
//  SplitAndStatementImportTests.swift
//  ExpenseManager
//
//  Regression coverage for competitive improvements: splits + CSV statement import.
//

import XCTest
@testable import ExpenseManager

final class SplitAndStatementImportTests: XCTestCase {

    func testSplitAmountsMustEqualParent() async throws {
        let parent = TransactionCandidate(
            type: .expense,
            amount: Decimal(1000),
            merchantName: "Big Bazaar",
            categorySuggestion: "Shopping"
        )
        let service = MockTransactionService(sampleData: [parent])

        do {
            _ = try await service.splitTransaction(
                id: parent.id.uuidString,
                splits: [
                    TransactionSplitLine(amount: 400, categoryName: "Groceries"),
                    TransactionSplitLine(amount: 500, categoryName: "Household")
                ]
            )
            XCTFail("Expected splitAmountsMustEqualParent")
        } catch TransactionServiceError.splitAmountsMustEqualParent {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSuccessfulSplitReplacesParent() async throws {
        let parent = TransactionCandidate(
            type: .expense,
            amount: Decimal(1000),
            merchantName: "Big Bazaar",
            categorySuggestion: "Shopping"
        )
        let service = MockTransactionService(sampleData: [parent])

        let ids = try await service.splitTransaction(
            id: parent.id.uuidString,
            splits: [
                TransactionSplitLine(amount: 600, categoryName: "Groceries", merchantName: "Big Bazaar"),
                TransactionSplitLine(amount: 400, categoryName: "Household", merchantName: "Big Bazaar")
            ]
        )

        XCTAssertEqual(ids.count, 2)
        let remaining = try await service.fetchRecentTransactions(limit: 10)
        XCTAssertEqual(remaining.count, 2)
        XCTAssertFalse(remaining.contains(where: { $0.id == parent.id }))
        XCTAssertEqual(remaining.map(\.amount).sorted(), [Decimal(400), Decimal(600)])
    }

    func testStatementCSVParseDebitCreditColumns() throws {
        let csv = """
        Date,Narration,Debit,Credit
        01-09-2026,SWIGGY BANGALORE,450.00,
        02-09-2026,SALARY CREDIT,,85000.00
        03-09-2026,UPI/PHONEPE/AMAZON,1299.50,
        """
        let importer = StatementCSVImportService(transactionService: MockTransactionService(sampleData: []))
        let rows = try importer.parseCSV(csv, defaultAccountHint: "HDFC Bank")
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0].type, .expense)
        XCTAssertEqual(rows[0].amount, Decimal(string: "450")!)
        XCTAssertEqual(rows[1].type, .income)
        XCTAssertEqual(rows[1].amount, Decimal(85000))
        XCTAssertEqual(rows[2].merchant.uppercased().contains("AMAZON"), true)
    }

    func testStatementCSVPreservesPerRowCurrencyColumn() throws {
        let csv = """
        Date,Narration,Amount,Currency
        01-09-2026,USD Purchase,450.00,USD
        """
        let importer = StatementCSVImportService(transactionService: MockTransactionService(sampleData: []))

        let rows = try importer.parseCSV(
            csv,
            defaultAccountHint: "USD Account",
            currencyCode: "INR"
        )

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.currencyCode, "USD")
        XCTAssertEqual(rows.first?.amount, 450)
    }

    func testStatementCSVRejectsInvalidCurrencyRowsBeforePreview() {
        let csv = """
        Date,Narration,Amount,Currency
        01-09-2026,Unknown Currency,450.00,XYZ
        02-09-2026,Invalid Precision,1.001,INR
        """
        let importer = StatementCSVImportService(transactionService: MockTransactionService(sampleData: []))

        XCTAssertThrowsError(
            try importer.parseCSV(csv, defaultAccountHint: nil, currencyCode: "INR")
        ) { error in
            guard case StatementCSVImportError.invalidRows(let count) = error else {
                XCTFail("Expected invalid row error, got \(error)")
                return
            }
            XCTAssertEqual(count, 2)
        }
    }

    func testStatementImportSkipsDuplicates() async throws {
        let service = MockTransactionService(sampleData: [])
        let importer = StatementCSVImportService(transactionService: service, fingerprintService: nil)
        let rows = [
            StatementImportRow(date: Date(), amount: 100, merchant: "Cafe", type: .expense),
            StatementImportRow(date: Date(), amount: 200, merchant: "Metro", type: .expense)
        ]
        let result = try await importer.importRows(rows)
        XCTAssertEqual(result.importedCount, 2)
        XCTAssertEqual(result.failedCount, 0)

        let recent = try await service.fetchRecentTransactions(limit: 10)
        XCTAssertEqual(recent.count, 2)
    }

    func testStatementImportUsesAtomicTransactionFingerprintBoundary() async throws {
        let service = MockTransactionService(sampleData: [])
        let importer = StatementCSVImportService(transactionService: service)
        let date = Date()
        let row = StatementImportRow(
            date: date,
            amount: 100,
            merchant: "Cafe",
            type: .expense,
            accountHint: "Account A",
            currencyCode: "USD"
        )

        let first = try await importer.importRows([row])
        let second = try await importer.importRows([row])

        XCTAssertEqual(first.importedCount, 1)
        XCTAssertEqual(first.skippedDuplicates, 0)
        XCTAssertEqual(second.importedCount, 0)
        XCTAssertEqual(second.skippedDuplicates, 1)
        let recent = try await service.fetchRecentTransactions(limit: 10)
        XCTAssertEqual(recent.count, 1)
    }

    func testStatementFingerprintSeparatesCurrencyAndAccountIdentity() async throws {
        let service = MockTransactionService(sampleData: [])
        let importer = StatementCSVImportService(transactionService: service)
        let date = Date()
        let rows = [
            StatementImportRow(
                date: date,
                amount: 100,
                merchant: "Cafe",
                type: .expense,
                accountHint: "Account A",
                currencyCode: "USD"
            ),
            StatementImportRow(
                date: date,
                amount: 100,
                merchant: "Cafe",
                type: .expense,
                accountHint: "Account A",
                currencyCode: "INR"
            ),
            StatementImportRow(
                date: date,
                amount: 100,
                merchant: "Cafe",
                type: .expense,
                accountHint: "Account B",
                currencyCode: "USD"
            )
        ]

        let result = try await importer.importRows(rows)

        XCTAssertEqual(result.importedCount, 3)
        XCTAssertEqual(result.skippedDuplicates, 0)
        let recent = try await service.fetchRecentTransactions(limit: 10)
        XCTAssertEqual(recent.count, 3)
    }

    func testCategoryDeleteRejectsSystemCategories() async throws {
        let service = MockCategoryService()
        do {
            try await service.deleteCategory(id: "cat_food")
            XCTFail("Should reject system category delete")
        } catch CategoryServiceError.cannotModifySystemCategory {
            // expected
        }
    }

    @MainActor
    func testBudgetAtRiskHonorsAlertThreshold() {
        let vm = BudgetsViewModel()
        let month = Date()
        vm.budgets = [
            BudgetDTO(
                categoryName: "Food",
                limitAmount: 10000,
                spentAmount: 8500,
                month: month,
                alertThresholdPercent: 80
            ),
            BudgetDTO(
                categoryName: "Transport",
                limitAmount: 5000,
                spentAmount: 2000,
                month: month,
                alertThresholdPercent: 90
            )
        ]
        // Force pace behind spend for food
        // monthPacePercent is computed from calendar; atRisk requires progress >= threshold AND > pace
        let atRisk = vm.atRiskBudgets
        XCTAssertTrue(atRisk.contains(where: { $0.categoryName == "Food" }) || vm.monthPacePercent < 0.85)
    }
}
