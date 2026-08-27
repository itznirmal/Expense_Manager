//
//  TransactionLedgerInvariantTests.swift
//  ExpenseManagerTests
//
//  Focused public-interface regressions for ISS-017 transaction ledger invariants.
//

import XCTest
import SwiftData
@testable import ExpenseManager

final class TransactionLedgerInvariantTests: XCTestCase {

    private var modelContainer: ModelContainer!
    private var transactionService: SwiftDataTransactionService!
    private var accountService: SwiftDataAccountService!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        modelContainer = try DatabaseContainer.inMemory()
        transactionService = SwiftDataTransactionService(modelContainer: modelContainer)
        accountService = SwiftDataAccountService(modelContainer: modelContainer)
    }

    @MainActor
    override func tearDown() async throws {
        modelContainer = nil
        transactionService = nil
        accountService = nil
        try await super.tearDown()
    }

    @MainActor
    func testDeletingPendingReviewDoesNotChangeBalance() async throws {
        let accountID = try await makeAccount(name: "Pending Bank", balance: 10_000, currencyCode: "INR")
        let pending = TransactionCandidate(
            type: .expense,
            amount: 2_000,
            currencyCode: "INR",
            merchantName: "Unverified Merchant",
            accountSuggestion: accountID,
            source: .sms,
            needsReview: true
        )

        let transactionID = try await transactionService.createTransaction(pending)
        let balanceBeforeDelete = try await accountService.getAccount(id: accountID)?.balance
        XCTAssertEqual(balanceBeforeDelete, 10_000)

        try await transactionService.deleteTransaction(id: transactionID)

        let balanceAfterDelete = try await accountService.getAccount(id: accountID)?.balance
        XCTAssertEqual(balanceAfterDelete, 10_000)
        let pendingTransactions = try await transactionService.fetchPendingReviewTransactions()
        XCTAssertTrue(pendingTransactions.isEmpty)
    }

    @MainActor
    func testInvalidUpdateLeavesAcceptedBalanceAndRecordUnchanged() async throws {
        let accountID = try await makeAccount(name: "Checking", balance: 10_000, currencyCode: "INR")
        let original = TransactionCandidate(
            type: .expense,
            amount: 2_000,
            currencyCode: "INR",
            merchantName: "Original Expense",
            accountSuggestion: accountID,
            source: .manual
        )
        let transactionID = try await transactionService.createTransaction(original)
        let balanceBeforeUpdate = try await accountService.getAccount(id: accountID)?.balance
        XCTAssertEqual(balanceBeforeUpdate, 8_000)

        var replacement = original
        replacement.accountSuggestion = "missing-source"
        try await assertThrows {
            try await self.transactionService.updateTransaction(id: transactionID, candidate: replacement)
        }

        let balanceAfterUpdate = try await accountService.getAccount(id: accountID)?.balance
        XCTAssertEqual(balanceAfterUpdate, 8_000)
        let transactions = try await transactionService.fetchTransactions(
            startDate: nil,
            endDate: nil,
            categoryID: nil,
            accountID: nil
        )
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions.first?.type, .expense)
        XCTAssertEqual(transactions.first?.amount, 2_000)
        XCTAssertEqual(transactions.first?.accountSuggestion, "Checking")
    }

    @MainActor
    func testInvalidTransferUpdateLeavesBothPriorBalancesUnchanged() async throws {
        let sourceID = try await makeAccount(name: "Source", balance: 10_000, currencyCode: "INR")
        let destinationID = try await makeAccount(name: "Destination", balance: 5_000, currencyCode: "INR")
        let original = TransactionCandidate(
            type: .expense,
            amount: 1_000,
            currencyCode: "INR",
            merchantName: "Original Expense",
            accountSuggestion: sourceID,
            source: .manual
        )
        let transactionID = try await transactionService.createTransaction(original)

        var missingDestination = original
        missingDestination.type = .transfer
        missingDestination.destinationAccountSuggestion = "missing-destination"
        try await assertThrows {
            try await self.transactionService.updateTransaction(id: transactionID, candidate: missingDestination)
        }
        let sourceBalanceAfterMissingDestination = try await accountService.getAccount(id: sourceID)?.balance
        let destinationBalanceAfterMissingDestination = try await accountService.getAccount(id: destinationID)?.balance
        XCTAssertEqual(sourceBalanceAfterMissingDestination, 9_000)
        XCTAssertEqual(destinationBalanceAfterMissingDestination, 5_000)

        var sameAccountTransfer = original
        sameAccountTransfer.type = .transfer
        sameAccountTransfer.destinationAccountSuggestion = sourceID
        try await assertThrows {
            try await self.transactionService.updateTransaction(id: transactionID, candidate: sameAccountTransfer)
        }
        let sourceBalanceAfterSameAccount = try await accountService.getAccount(id: sourceID)?.balance
        let destinationBalanceAfterSameAccount = try await accountService.getAccount(id: destinationID)?.balance
        XCTAssertEqual(sourceBalanceAfterSameAccount, 9_000)
        XCTAssertEqual(destinationBalanceAfterSameAccount, 5_000)
    }

    @MainActor
    func testCashWithdrawalUpdateValidatesSourceBeforeCreatingCashDestination() async throws {
        let accountID = try await makeAccount(name: "Checking", balance: 10_000, currencyCode: "INR")
        let original = TransactionCandidate(
            type: .expense,
            amount: 2_000,
            currencyCode: "INR",
            merchantName: "Original Expense",
            accountSuggestion: accountID,
            source: .manual
        )
        let transactionID = try await transactionService.createTransaction(original)

        var replacement = original
        replacement.type = .cashWithdrawal
        replacement.amount = 1_000
        replacement.accountSuggestion = "missing-source"
        try await assertThrows {
            try await self.transactionService.updateTransaction(id: transactionID, candidate: replacement)
        }

        let balanceAfterUpdate = try await accountService.getAccount(id: accountID)?.balance
        XCTAssertEqual(balanceAfterUpdate, 8_000)
        let accounts = try await accountService.fetchAccounts(includeArchived: true)
        XCTAssertFalse(accounts.contains { $0.type == .cash && $0.currencyCode == "INR" })
    }

    @MainActor
    func testTransferAndCashWithdrawalRequireResolvedSourceBeforePersistence() async throws {
        let destinationID = try await makeAccount(name: "Destination", balance: 5_000, currencyCode: "INR")
        let transfer = TransactionCandidate(
            type: .transfer,
            amount: 1_000,
            currencyCode: "INR",
            merchantName: "Transfer",
            accountSuggestion: "missing-source",
            destinationAccountSuggestion: destinationID,
            source: .manual
        )
        try await assertThrows {
            try await self.transactionService.createTransaction(transfer)
        }
        let destinationBalance = try await accountService.getAccount(id: destinationID)?.balance
        XCTAssertEqual(destinationBalance, 5_000)

        let withdrawal = TransactionCandidate(
            type: .cashWithdrawal,
            amount: 1_000,
            currencyCode: "INR",
            merchantName: "ATM",
            accountSuggestion: "missing-source",
            source: .manual
        )
        try await assertThrows {
            try await self.transactionService.createTransaction(withdrawal)
        }
        let accounts = try await accountService.fetchAccounts(includeArchived: true)
        XCTAssertFalse(accounts.contains { $0.type == .cash && $0.currencyCode == "INR" })

        let transactions = try await transactionService.fetchTransactions(
            startDate: nil,
            endDate: nil,
            categoryID: nil,
            accountID: nil
        )
        XCTAssertTrue(transactions.isEmpty)
    }

    @MainActor
    func testCashWithdrawalUsesCashAccountMatchingTransactionCurrency() async throws {
        let bankID = try await makeAccount(name: "INR Bank", balance: 10_000, currencyCode: "INR")
        _ = try await makeAccount(name: "USD Cash", type: .cash, balance: 700, currencyCode: "USD")

        let firstWithdrawal = TransactionCandidate(
            type: .cashWithdrawal,
            amount: 1_250,
            currencyCode: "INR",
            merchantName: "INR ATM",
            accountSuggestion: bankID,
            source: .manual
        )
        try await transactionService.createTransaction(firstWithdrawal)

        let secondWithdrawal = TransactionCandidate(
            type: .cashWithdrawal,
            amount: 500,
            currencyCode: "INR",
            merchantName: "Another INR ATM",
            accountSuggestion: bankID,
            source: .manual
        )
        try await transactionService.createTransaction(secondWithdrawal)

        let bankBalance = try await accountService.getAccount(id: bankID)?.balance
        XCTAssertEqual(bankBalance, 8_250)
        let accounts = try await accountService.fetchAccounts(includeArchived: true)
        let usdCash = accounts.first { $0.type == .cash && $0.currencyCode == "USD" }
        let inrCash = accounts.first { $0.type == .cash && $0.currencyCode == "INR" }
        XCTAssertEqual(usdCash?.balance, 700)
        XCTAssertEqual(inrCash?.balance, 1_750)
        XCTAssertEqual(accounts.filter { $0.type == .cash }.count, 2)
    }

    @MainActor
    private func makeAccount(
        name: String,
        type: AccountType = .bank,
        balance: Decimal,
        currencyCode: String
    ) async throws -> String {
        try await accountService.createAccount(
            name: name,
            type: type,
            openingBalance: balance,
            currencyCode: currencyCode,
            icon: type.iconName,
            colorToken: "blue",
            lastFour: nil
        )
    }

    @MainActor
    private func assertThrows(
        _ operation: @escaping @MainActor () async throws -> Void
    ) async throws {
        do {
            try await operation()
            XCTFail("Expected operation to throw")
        } catch {
            // The public contract is failure without a ledger mutation.
        }
    }
}
