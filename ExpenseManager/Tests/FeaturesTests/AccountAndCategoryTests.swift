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
        modelContainer = try DatabaseContainer.inMemory()
        dependencyContainer = DependencyContainer.live(modelContainer: modelContainer)
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        dependencyContainer = nil
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

    @MainActor
    func testAccountBalancesValidateSignedZeroAndFractionalValuesWithoutMutation() async throws {
        let liabilityID = try await dependencyContainer.accountService.createAccount(
            name: "Liability",
            type: .creditCard,
            openingBalance: -250.50,
            currencyCode: "INR",
            icon: "creditcard.fill",
            colorToken: "purple",
            lastFour: nil
        )
        let zeroID = try await dependencyContainer.accountService.createAccount(
            name: "Zero",
            type: .bank,
            openingBalance: .zero,
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: nil
        )

        let liability = try await dependencyContainer.accountService.getAccount(id: liabilityID)
        let zero = try await dependencyContainer.accountService.getAccount(id: zeroID)
        XCTAssertEqual(liability?.balance, -250.50)
        XCTAssertEqual(zero?.balance, .zero)

        do {
            _ = try await dependencyContainer.accountService.createAccount(
                name: "Invalid Fraction",
                type: .bank,
                openingBalance: Decimal(string: "1.001")!,
                currencyCode: "INR",
                icon: "building.columns.fill",
                colorToken: "blue",
                lastFour: nil
            )
            XCTFail("Fractional balance beyond currency scale must be rejected")
        } catch {
            // Expected.
        }
        do {
            _ = try await dependencyContainer.accountService.createAccount(
                name: "Invalid NaN",
                type: .bank,
                openingBalance: NSDecimalNumber.notANumber.decimalValue,
                currencyCode: "INR",
                icon: "building.columns.fill",
                colorToken: "blue",
                lastFour: nil
            )
            XCTFail("Non-finite account balance must be rejected")
        } catch {
            // Expected.
        }
        do {
            _ = try await dependencyContainer.accountService.createAccount(
                name: "Invalid Currency",
                type: .bank,
                openingBalance: 1,
                currencyCode: "XYZ",
                icon: "building.columns.fill",
                colorToken: "blue",
                lastFour: nil
            )
            XCTFail("Unsupported account currency must be rejected")
        } catch {
            // Expected.
        }

        let accounts = try await dependencyContainer.accountService.fetchAccounts(includeArchived: true)
        XCTAssertEqual(accounts.count, 2)
    }

    @MainActor
    func testAccountCurrencyChangeWithExistingTransactionIsRejectedWithoutMutation() async throws {
        let accountID = try await dependencyContainer.accountService.createAccount(
            name: "Checking",
            type: .bank,
            openingBalance: 1_000,
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: nil
        )
        let candidate = TransactionCandidate(
            type: .expense,
            amount: 100,
            currencyCode: "INR",
            merchantName: "Existing Purchase",
            accountSuggestion: accountID,
            source: .manual
        )
        _ = try await dependencyContainer.transactionService.createTransaction(candidate)

        guard var updated = try await dependencyContainer.accountService.getAccount(id: accountID) else {
            XCTFail("Account was not found after creation")
            return
        }
        updated.currencyCode = "USD"
        updated.balance = 900

        do {
            try await dependencyContainer.accountService.updateAccount(updated)
            XCTFail("Currency changes with existing transactions must be rejected")
        } catch let error as AccountServiceError {
            guard case .currencyChangeNotAllowed(_) = error else {
                XCTFail("Expected currencyChangeNotAllowed, got \(error)")
                return
            }
        } catch {
            XCTFail("Expected currencyChangeNotAllowed, got \(error)")
        }

        guard let accountAfter = try await dependencyContainer.accountService.getAccount(id: accountID) else {
            XCTFail("Account disappeared after rejected update")
            return
        }
        XCTAssertEqual(accountAfter.currencyCode, "INR")
        XCTAssertEqual(accountAfter.balance, 900)
        let transactions = try await dependencyContainer.transactionService.fetchTransactions(
            startDate: nil,
            endDate: nil,
            categoryID: nil,
            accountID: accountID
        )
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions.first?.currencyCode, "INR")

        var invalidBalance = accountAfter
        invalidBalance.balance = Decimal(string: "1.001")!
        do {
            try await dependencyContainer.accountService.updateAccount(invalidBalance)
            XCTFail("Fractional account balance beyond currency scale must be rejected")
        } catch {
            // Expected.
        }

        var invalidCurrency = accountAfter
        invalidCurrency.currencyCode = "XYZ"
        do {
            try await dependencyContainer.accountService.updateAccount(invalidCurrency)
            XCTFail("Unsupported account currency must be rejected")
        } catch {
            // Expected.
        }

        guard let accountAfterInvalidUpdates = try await dependencyContainer.accountService.getAccount(id: accountID) else {
            XCTFail("Account disappeared after rejected invalid updates")
            return
        }
        XCTAssertEqual(accountAfterInvalidUpdates.currencyCode, "INR")
        XCTAssertEqual(accountAfterInvalidUpdates.balance, 900)
    }
}
