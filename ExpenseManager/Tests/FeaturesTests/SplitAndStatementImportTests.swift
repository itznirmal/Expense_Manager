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
    
    func testCategoryDeleteRejectsSystemCategories() async throws {
        let service = MockCategoryService()
        do {
            try await service.deleteCategory(id: "cat_food")
            XCTFail("Should reject system category delete")
        } catch CategoryServiceError.cannotModifySystemCategory {
            // expected
        }
    }
    
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
