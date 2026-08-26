//
//  AccountAndCategoryTests.swift
//  ExpenseManagerTests
//
//  Created for Expense Manager iOS.
//  Unit Tests for Account Management, Liability Tracking & Category Taxonomy.
//

import XCTest
import SwiftData
@testable import ExpenseManager

final class AccountAndCategoryTests: XCTestCase {
    
    private var modelContainer: ModelContainer!
    private var dependencyContainer: DependencyContainer!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        modelContainer = try DatabaseContainer.inMemory()
        dependencyContainer = DependencyContainer.live(modelContainer: modelContainer)
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        dependencyContainer = nil
        try await super.tearDown()
    }
    
    // MARK: - 1. Account Creation & Grouping Tests
    
    @MainActor
    func testAccountCreationAndGrouping() async throws {
        let bankId = try await dependencyContainer.accountService.createAccount(
            name: "HDFC Salary",
            type: .bank,
            openingBalance: Decimal(80000),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: "1234"
        )
        
        let ccId = try await dependencyContainer.accountService.createAccount(
            name: "ICICI Sapphiro",
            type: .creditCard,
            openingBalance: Decimal(-25000),
            currencyCode: "INR",
            icon: "creditcard.fill",
            colorToken: "purple",
            lastFour: "5678"
        )
        
        let cashId = try await dependencyContainer.accountService.createAccount(
            name: "Cash Wallet",
            type: .cash,
            openingBalance: Decimal(4500),
            currencyCode: "INR",
            icon: "banknote.fill",
            colorToken: "green",
            lastFour: nil
        )
        
        let vm = AccountsListViewModel()
        await vm.loadAccounts(container: dependencyContainer)
        
        XCTAssertEqual(vm.bankAccounts.count, 1)
        XCTAssertEqual(vm.creditCardAccounts.count, 1)
        XCTAssertEqual(vm.walletAndCashAccounts.count, 1)
        
        XCTAssertEqual(vm.totalAssets, Decimal(84500), "80,000 + 4,500 = 84,500")
        XCTAssertEqual(vm.totalLiabilities, Decimal(25000))
        XCTAssertEqual(vm.netWorth, Decimal(59500), "84,500 - 25,000 = 59,500")
    }
    
    // MARK: - 2. Account Archive Toggle Test
    
    @MainActor
    func testAccountArchiveToggle() async throws {
        let accId = try await dependencyContainer.accountService.createAccount(
            name: "Old Account",
            type: .bank,
            openingBalance: Decimal(1000),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "gray",
            lastFour: "9999"
        )
        
        let vm = AccountsListViewModel()
        await vm.loadAccounts(container: dependencyContainer)
        XCTAssertEqual(vm.activeAccounts.count, 1)
        
        guard let account = vm.allAccounts.first(where: { $0.id == accId }) else {
            XCTFail("Account not found")
            return
        }
        
        // Archive account
        await vm.toggleArchive(account: account, container: dependencyContainer)
        XCTAssertEqual(vm.activeAccounts.count, 0)
        XCTAssertEqual(vm.archivedAccounts.count, 1)
        
        // Unarchive account
        let archivedAccount = vm.archivedAccounts.first!
        await vm.toggleArchive(account: archivedAccount, container: dependencyContainer)
        XCTAssertEqual(vm.activeAccounts.count, 1)
        XCTAssertEqual(vm.archivedAccounts.count, 0)
    }
    
    // MARK: - 3. Category Taxonomy & Custom Category Creation Test
    
    @MainActor
    func testCategoryTaxonomyAndCustomCategoryCreation() async throws {
        let vm = CategoriesViewModel()
        await vm.loadCategories(container: dependencyContainer)
        
        // Default system categories seeded
        XCTAssertFalse(vm.systemCategories.isEmpty)
        XCTAssertEqual(vm.customCategories.count, 0)
        
        // Create custom category: "Pet Care"
        let success = await vm.createCategory(
            name: "Pet Care",
            icon: "pawprint.fill",
            colorToken: "pink",
            type: .expense,
            container: dependencyContainer
        )
        
        XCTAssertTrue(success)
        XCTAssertEqual(vm.customCategories.count, 1)
        XCTAssertEqual(vm.customCategories.first?.name, "Pet Care")
        XCTAssertEqual(vm.customCategories.first?.type, .expense)
        
        // Filter by Income
        vm.selectedType = .income
        let incomeCats = vm.filteredCategories
        XCTAssertTrue(incomeCats.allSatisfy { $0.type == .income || $0.type == .both })
    }
}
