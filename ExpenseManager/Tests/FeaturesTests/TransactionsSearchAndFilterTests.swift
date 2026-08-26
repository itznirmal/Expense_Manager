//
//  TransactionsSearchAndFilterTests.swift
//  ExpenseManagerTests
//
//  Created for Expense Manager iOS.
//  Unit Tests for Multi-Attribute Predicate Search, Sorting & Bulk Ledger Operations.
//

import XCTest
import SwiftData
@testable import ExpenseManager

final class TransactionsSearchAndFilterTests: XCTestCase {
    
    private var modelContainer: ModelContainer!
    private var dependencyContainer: DependencyContainer!
    private var appState: AppState!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        modelContainer = try DatabaseContainer.inMemory()
        dependencyContainer = DependencyContainer.live(modelContainer: modelContainer)
        appState = AppState()
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        dependencyContainer = nil
        appState = nil
        try await super.tearDown()
    }
    
    // MARK: - 1. Search Query Filtering Test
    
    @MainActor
    func testSearchQueryFiltering() async throws {
        let now = Date()
        
        let tx1 = TransactionCandidate(
            type: .expense,
            amount: Decimal(520),
            currencyCode: "INR",
            merchantName: "Swiggy Bangalore",
            categorySuggestion: "Food & Dining",
            transactionDate: now,
            notes: "Lunch with team"
        )
        
        let tx2 = TransactionCandidate(
            type: .expense,
            amount: Decimal(1800),
            currencyCode: "INR",
            merchantName: "Shell Petrol Station",
            categorySuggestion: "Fuel",
            transactionDate: now,
            notes: "Highway ride"
        )
        
        let tx3 = TransactionCandidate(
            type: .income,
            amount: Decimal(75000),
            currencyCode: "INR",
            merchantName: "Acme Corp",
            categorySuggestion: "Salary",
            transactionDate: now,
            sourceReference: "NEFT/489102"
        )
        
        try await dependencyContainer.transactionService.createTransaction(tx1)
        try await dependencyContainer.transactionService.createTransaction(tx2)
        try await dependencyContainer.transactionService.createTransaction(tx3)
        
        let vm = TransactionsListViewModel()
        await vm.loadData(container: dependencyContainer)
        XCTAssertEqual(vm.allTransactions.count, 3)
        
        // Search by merchant name
        vm.searchQuery = "swiggy"
        XCTAssertEqual(vm.filteredTransactions.count, 1)
        XCTAssertEqual(vm.filteredTransactions.first?.merchantName, "Swiggy Bangalore")
        
        // Search by note content
        vm.searchQuery = "Highway"
        XCTAssertEqual(vm.filteredTransactions.count, 1)
        XCTAssertEqual(vm.filteredTransactions.first?.merchantName, "Shell Petrol Station")
        
        // Search by reference code
        vm.searchQuery = "489102"
        XCTAssertEqual(vm.filteredTransactions.count, 1)
        XCTAssertEqual(vm.filteredTransactions.first?.merchantName, "Acme Corp")
        
        // Reset search
        vm.searchQuery = ""
        XCTAssertEqual(vm.filteredTransactions.count, 3)
    }
    
    // MARK: - 2. Sorting Orders Test
    
    @MainActor
    func testSortingOptions() async throws {
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let twoDaysAgo = now.addingTimeInterval(-86400 * 2)
        
        try await dependencyContainer.transactionService.createTransaction(
            TransactionCandidate(type: .expense, amount: Decimal(100), merchantName: "Small", transactionDate: twoDaysAgo)
        )
        try await dependencyContainer.transactionService.createTransaction(
            TransactionCandidate(type: .expense, amount: Decimal(5000), merchantName: "Large", transactionDate: yesterday)
        )
        try await dependencyContainer.transactionService.createTransaction(
            TransactionCandidate(type: .expense, amount: Decimal(500), merchantName: "Medium", transactionDate: now)
        )
        
        let vm = TransactionsListViewModel()
        await vm.loadData(container: dependencyContainer)
        
        // Date Descending (Newest first)
        vm.sortOption = .dateDesc
        XCTAssertEqual(vm.filteredTransactions.first?.merchantName, "Medium")
        
        // Date Ascending (Oldest first)
        vm.sortOption = .dateAsc
        XCTAssertEqual(vm.filteredTransactions.first?.merchantName, "Small")
        
        // Amount Descending (Highest amount first)
        vm.sortOption = .amountDesc
        XCTAssertEqual(vm.filteredTransactions.first?.amount, Decimal(5000))
        
        // Amount Ascending (Lowest amount first)
        vm.sortOption = .amountAsc
        XCTAssertEqual(vm.filteredTransactions.first?.amount, Decimal(100))
    }
    
    // MARK: - 3. Bulk Selection, Deletion & Re-Categorization Test
    
    @MainActor
    func testBulkOperations() async throws {
        let id1 = try await dependencyContainer.transactionService.createTransaction(
            TransactionCandidate(type: .expense, amount: Decimal(200), merchantName: "Tea Stall", categorySuggestion: "Other")
        )
        let id2 = try await dependencyContainer.transactionService.createTransaction(
            TransactionCandidate(type: .expense, amount: Decimal(350), merchantName: "Bakery", categorySuggestion: "Other")
        )
        let id3 = try await dependencyContainer.transactionService.createTransaction(
            TransactionCandidate(type: .expense, amount: Decimal(1200), merchantName: "Stationery", categorySuggestion: "Office")
        )
        
        let vm = TransactionsListViewModel()
        await vm.loadData(container: dependencyContainer)
        XCTAssertEqual(vm.allTransactions.count, 3)
        
        // 1. Select id1 and id2
        vm.isBulkSelecting = true
        vm.toggleSelection(for: id1)
        vm.toggleSelection(for: id2)
        XCTAssertEqual(vm.selectedTransactionIDs.count, 2)
        
        // 2. Bulk Re-categorize to "Food & Dining"
        await vm.bulkCategorizeSelected(categoryName: "Food & Dining", container: dependencyContainer, appState: appState)
        
        let updatedList = try await dependencyContainer.transactionService.fetchTransactions(startDate: nil, endDate: nil, categoryID: nil, accountID: nil)
        let t1 = updatedList.first(where: { $0.id.uuidString == id1 })
        let t2 = updatedList.first(where: { $0.id.uuidString == id2 })
        let t3 = updatedList.first(where: { $0.id.uuidString == id3 })
        
        XCTAssertEqual(t1?.categorySuggestion, "Food & Dining")
        XCTAssertEqual(t2?.categorySuggestion, "Food & Dining")
        XCTAssertEqual(t3?.categorySuggestion, "Office")
        
        // 3. Bulk Delete id3
        vm.isBulkSelecting = true
        vm.toggleSelection(for: id3)
        await vm.bulkDeleteSelected(container: dependencyContainer, appState: appState)
        
        let finalCount = try await dependencyContainer.transactionService.fetchTransactions(startDate: nil, endDate: nil, categoryID: nil, accountID: nil)
        XCTAssertEqual(finalCount.count, 2)
        XCTAssertFalse(finalCount.contains(where: { $0.id.uuidString == id3 }))
    }
}
