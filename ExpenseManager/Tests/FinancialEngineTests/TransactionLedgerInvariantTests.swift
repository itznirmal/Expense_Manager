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
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    @MainActor
    override func setUp() async throws {
        modelContainer = try DatabaseContainer.inMemory()
        transactionService = SwiftDataTransactionService(modelContainer: modelContainer)
        accountService = SwiftDataAccountService(modelContainer: modelContainer)
    }

    @MainActor
    override func tearDown() async throws {
        modelContainer = nil
        transactionService = nil
        accountService = nil
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
    func testDeletingNonPendingUnacceptedRecordDoesNotChangeBalance() async throws {
        let accountID = try await makeAccount(name: "Legacy Bank", balance: 10_000, currencyCode: "INR")
        let pending = TransactionCandidate(
            type: .expense,
            amount: 2_000,
            currencyCode: "INR",
            merchantName: "Legacy Expense",
            accountSuggestion: accountID,
            source: .sms,
            needsReview: true
        )

        let transactionID = try await transactionService.createTransaction(pending)
        let record = try XCTUnwrap(try fetchTransactionRecord(id: transactionID))
        record.isPendingReview = false
        record.isAccepted = false
        try modelContext.save()

        let balanceBeforeDelete = try await accountService.getAccount(id: accountID)?.balance
        XCTAssertEqual(balanceBeforeDelete, 10_000)
        try await transactionService.deleteTransaction(id: transactionID)

        let balanceAfterDelete = try await accountService.getAccount(id: accountID)?.balance
        XCTAssertEqual(balanceAfterDelete, 10_000)
        XCTAssertNil(try fetchTransactionRecord(id: transactionID))
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
        do {
            try await transactionService.updateTransaction(id: transactionID, candidate: replacement)
            XCTFail("Expected an unresolved account suggestion to throw")
        } catch TransactionServiceError.transactionMissingSourceAccount {
            // Expected: the prior accepted effect must remain untouched.
        } catch {
            XCTFail("Expected transactionMissingSourceAccount, got \(error)")
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
    func testOrdinaryAccountlessRecordRemainsEditable() async throws {
        let original = TransactionCandidate(
            type: .expense,
            amount: 2_000,
            currencyCode: "INR",
            merchantName: "Unassigned Expense",
            source: .manual
        )
        let transactionID = try await transactionService.createTransaction(original)

        var replacement = original
        replacement.type = .income
        replacement.amount = 500
        replacement.merchantName = "Unassigned Income"
        replacement.accountSuggestion = ""
        try await transactionService.updateTransaction(id: transactionID, candidate: replacement)

        let transactions = try await transactionService.fetchTransactions(
            startDate: nil,
            endDate: nil,
            categoryID: nil,
            accountID: nil
        )
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions.first?.type, .income)
        XCTAssertEqual(transactions.first?.amount, 500)
        XCTAssertEqual(transactions.first?.merchantName, "Unassigned Income")
        XCTAssertNil(transactions.first?.accountSuggestion)
    }

    @MainActor
    func testInvalidTransferUpdateLeavesBothPriorBalancesUnchanged() async throws {
        let sourceID = try await makeAccount(name: "Source", balance: 10_000, currencyCode: "INR")
        let destinationID = try await makeAccount(name: "Destination", balance: 5_000, currencyCode: "INR")
        let original = TransactionCandidate(
            type: .transfer,
            amount: 1_000,
            currencyCode: "INR",
            merchantName: "Original Transfer",
            accountSuggestion: sourceID,
            destinationAccountSuggestion: destinationID,
            source: .manual
        )
        let transactionID = try await transactionService.createTransaction(original)

        let sourceBalanceAfterCreate = try await accountService.getAccount(id: sourceID)?.balance
        let destinationBalanceAfterCreate = try await accountService.getAccount(id: destinationID)?.balance
        XCTAssertEqual(sourceBalanceAfterCreate, 9_000)
        XCTAssertEqual(destinationBalanceAfterCreate, 6_000)

        var missingDestination = original
        missingDestination.destinationAccountSuggestion = "missing-destination"
        try await assertThrows {
            try await self.transactionService.updateTransaction(id: transactionID, candidate: missingDestination)
        }
        let sourceBalanceAfterMissingDestination = try await accountService.getAccount(id: sourceID)?.balance
        let destinationBalanceAfterMissingDestination = try await accountService.getAccount(id: destinationID)?.balance
        XCTAssertEqual(sourceBalanceAfterMissingDestination, 9_000)
        XCTAssertEqual(destinationBalanceAfterMissingDestination, 6_000)

        var sameAccountTransfer = original
        sameAccountTransfer.type = .transfer
        sameAccountTransfer.destinationAccountSuggestion = sourceID
        try await assertThrows {
            try await self.transactionService.updateTransaction(id: transactionID, candidate: sameAccountTransfer)
        }
        let sourceBalanceAfterSameAccount = try await accountService.getAccount(id: sourceID)?.balance
        let destinationBalanceAfterSameAccount = try await accountService.getAccount(id: destinationID)?.balance
        XCTAssertEqual(sourceBalanceAfterSameAccount, 9_000)
        XCTAssertEqual(destinationBalanceAfterSameAccount, 6_000)

        var mismatchedCurrency = original
        mismatchedCurrency.currencyCode = "USD"
        try await assertThrows {
            try await self.transactionService.updateTransaction(id: transactionID, candidate: mismatchedCurrency)
        }
        let sourceBalanceAfterCurrencyMismatch = try await accountService.getAccount(id: sourceID)?.balance
        let destinationBalanceAfterCurrencyMismatch = try await accountService.getAccount(id: destinationID)?.balance
        XCTAssertEqual(sourceBalanceAfterCurrencyMismatch, 9_000)
        XCTAssertEqual(destinationBalanceAfterCurrencyMismatch, 6_000)
    }

    @MainActor
    func testCashWithdrawalToItsSourceLeavesExistingExpenseUnchanged() async throws {
        let bankID = try await makeAccount(name: "Checking", balance: 10_000, currencyCode: "INR")
        let cashID = try await makeAccount(name: "Cash", type: .cash, balance: 5_000, currencyCode: "INR")
        var candidate = TransactionCandidate(
            amount: 2_000, currencyCode: "INR", merchantName: "Original expense",
            accountSuggestion: bankID
        )
        let transactionID = try await transactionService.createTransaction(candidate)
        candidate.type = .cashWithdrawal
        candidate.accountSuggestion = cashID
        do {
            try await transactionService.updateTransaction(id: transactionID, candidate: candidate)
            XCTFail("A cash withdrawal must not use the same account for both legs.")
        } catch TransactionServiceError.transferSourceAndDestinationMustBeDistinct {
            // Validation must happen before reversing the existing expense.
        }
        let bankBalance = try await accountService.getAccount(id: bankID)?.balance
        let cashBalance = try await accountService.getAccount(id: cashID)?.balance
        XCTAssertEqual(bankBalance, 8_000)
        XCTAssertEqual(cashBalance, 5_000)
        let record = try XCTUnwrap(try fetchTransactionRecord(id: transactionID))
        XCTAssertEqual(record.transactionType, .expense)
        XCTAssertEqual(record.amount, 2_000)
        XCTAssertEqual(record.account?.id, bankID)
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

        var mismatchedCurrency = original
        mismatchedCurrency.type = .cashWithdrawal
        mismatchedCurrency.amount = 1_000
        mismatchedCurrency.currencyCode = "USD"
        mismatchedCurrency.accountSuggestion = accountID
        try await assertThrows {
            try await self.transactionService.updateTransaction(id: transactionID, candidate: mismatchedCurrency)
        }
        let balanceAfterCurrencyMismatch = try await accountService.getAccount(id: accountID)?.balance
        XCTAssertEqual(balanceAfterCurrencyMismatch, 8_000)
        let accountsAfterCurrencyMismatch = try await accountService.fetchAccounts(includeArchived: true)
        XCTAssertFalse(accountsAfterCurrencyMismatch.contains { $0.type == .cash && $0.currencyCode == "USD" })
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
    func testTransferRejectsCurrencyMismatchOnEitherParticipatingAccount() async throws {
        let inrSourceID = try await makeAccount(name: "INR Source", balance: 10_000, currencyCode: "INR")
        let usdDestinationID = try await makeAccount(name: "USD Destination", balance: 5_000, currencyCode: "USD")
        let destinationMismatch = TransactionCandidate(
            type: .transfer,
            amount: 1_000,
            currencyCode: "INR",
            merchantName: "Cross Currency Transfer",
            accountSuggestion: inrSourceID,
            destinationAccountSuggestion: usdDestinationID,
            source: .manual
        )
        try await assertThrows {
            try await self.transactionService.createTransaction(destinationMismatch)
        }

        let usdSourceID = try await makeAccount(name: "USD Source", balance: 8_000, currencyCode: "USD")
        let inrDestinationID = try await makeAccount(name: "INR Destination", balance: 4_000, currencyCode: "INR")
        let sourceMismatch = TransactionCandidate(
            type: .transfer,
            amount: 1_000,
            currencyCode: "INR",
            merchantName: "Cross Currency Transfer",
            accountSuggestion: usdSourceID,
            destinationAccountSuggestion: inrDestinationID,
            source: .manual
        )
        try await assertThrows {
            try await self.transactionService.createTransaction(sourceMismatch)
        }

        let inrSourceBalance = try await accountService.getAccount(id: inrSourceID)?.balance
        let usdDestinationBalance = try await accountService.getAccount(id: usdDestinationID)?.balance
        let usdSourceBalance = try await accountService.getAccount(id: usdSourceID)?.balance
        let inrDestinationBalance = try await accountService.getAccount(id: inrDestinationID)?.balance
        XCTAssertEqual(inrSourceBalance, 10_000)
        XCTAssertEqual(usdDestinationBalance, 5_000)
        XCTAssertEqual(usdSourceBalance, 8_000)
        XCTAssertEqual(inrDestinationBalance, 4_000)
        let transactions = try await transactionService.fetchTransactions(
            startDate: nil,
            endDate: nil,
            categoryID: nil,
            accountID: nil
        )
        XCTAssertTrue(transactions.isEmpty)
    }

    @MainActor
    func testCashWithdrawalRejectsSourceCurrencyMismatchBeforeCreatingCashAccount() async throws {
        let sourceID = try await makeAccount(name: "INR Bank", balance: 10_000, currencyCode: "INR")
        let withdrawal = TransactionCandidate(
            type: .cashWithdrawal,
            amount: 1_000,
            currencyCode: "USD",
            merchantName: "USD ATM",
            accountSuggestion: sourceID,
            source: .manual
        )

        try await assertThrows {
            try await self.transactionService.createTransaction(withdrawal)
        }

        let sourceBalance = try await accountService.getAccount(id: sourceID)?.balance
        XCTAssertEqual(sourceBalance, 10_000)
        let accounts = try await accountService.fetchAccounts(includeArchived: true)
        XCTAssertFalse(accounts.contains { $0.type == .cash && $0.currencyCode == "USD" })
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
    func testCashWithdrawalIgnoresArchivedAndNonCashAccountsNamedCash() async throws {
        let sourceID = try await makeAccount(name: "INR Bank", balance: 10_000, currencyCode: "INR")
        let misleadingCashID = try await makeAccount(name: "Cash", type: .bank, balance: 400, currencyCode: "INR")
        let archivedCashID = try await makeAccount(name: "Archived Wallet", type: .cash, balance: 700, currencyCode: "INR")
        try await accountService.setArchived(accountID: archivedCashID, isArchived: true)

        let withdrawal = TransactionCandidate(
            type: .cashWithdrawal,
            amount: 1_250,
            currencyCode: "INR",
            merchantName: "INR ATM",
            accountSuggestion: sourceID,
            source: .manual
        )
        try await transactionService.createTransaction(withdrawal)

        let sourceBalance = try await accountService.getAccount(id: sourceID)?.balance
        let misleadingCashBalance = try await accountService.getAccount(id: misleadingCashID)?.balance
        let archivedCashBalance = try await accountService.getAccount(id: archivedCashID)?.balance
        XCTAssertEqual(sourceBalance, 8_750)
        XCTAssertEqual(misleadingCashBalance, 400)
        XCTAssertEqual(archivedCashBalance, 700)

        let accounts = try await accountService.fetchAccounts(includeArchived: true)
        let activeINRCashAccounts = accounts.filter {
            $0.type == .cash && $0.currencyCode == "INR" && !$0.isArchived
        }
        XCTAssertEqual(activeINRCashAccounts.count, 1)
        XCTAssertEqual(activeINRCashAccounts.first?.balance, 1_250)
    }

    @MainActor
    func testAcceptRejectsLegacyPendingTransferCurrencyMismatchWithoutMutation() async throws {
        let sourceID = try await makeAccount(name: "INR Source", balance: 10_000, currencyCode: "INR")
        let destinationID = try await makeAccount(name: "USD Destination", balance: 5_000, currencyCode: "USD")
        let transactionID = try insertLegacyPendingTransaction(
            type: .transfer,
            amount: 1_000,
            currencyCode: "INR",
            accountID: sourceID,
            destinationAccountID: destinationID
        )

        try await assertThrows {
            try await self.transactionService.acceptTransaction(id: transactionID)
        }

        let sourceBalance = try await accountService.getAccount(id: sourceID)?.balance
        let destinationBalance = try await accountService.getAccount(id: destinationID)?.balance
        let record = try fetchTransactionRecord(id: transactionID)
        XCTAssertEqual(sourceBalance, 10_000)
        XCTAssertEqual(destinationBalance, 5_000)
        XCTAssertEqual(record?.isPendingReview, true)
        XCTAssertEqual(record?.isAccepted, false)
    }

    @MainActor
    func testAcceptRejectsLegacyPendingCashCurrencyMismatchWithoutMutation() async throws {
        let sourceID = try await makeAccount(name: "INR Bank", balance: 10_000, currencyCode: "INR")
        let cashID = try await makeAccount(name: "USD Cash", type: .cash, balance: 700, currencyCode: "USD")
        let transactionID = try insertLegacyPendingTransaction(
            type: .cashWithdrawal,
            amount: 1_000,
            currencyCode: "INR",
            accountID: sourceID,
            destinationAccountID: cashID
        )

        try await assertThrows {
            try await self.transactionService.acceptTransaction(id: transactionID)
        }

        let sourceBalance = try await accountService.getAccount(id: sourceID)?.balance
        let cashBalance = try await accountService.getAccount(id: cashID)?.balance
        let record = try fetchTransactionRecord(id: transactionID)
        XCTAssertEqual(sourceBalance, 10_000)
        XCTAssertEqual(cashBalance, 700)
        XCTAssertEqual(record?.isPendingReview, true)
        XCTAssertEqual(record?.isAccepted, false)
    }

    @MainActor
    func testIsPostedRequiresAcceptanceAndNotPendingReview() {
        let record = TransactionRecord(amount: 10, currencyCode: "INR")
        XCTAssertTrue(record.isPosted)

        record.isPendingReview = true
        XCTAssertFalse(record.isPosted)

        record.isPendingReview = false
        record.isAccepted = false
        XCTAssertFalse(record.isPosted)
    }

    @MainActor
    func testUnknownTransactionRemainsReviewOnlyAndCannotPost() async throws {
        let accountID = try await makeAccount(name: "Unknown Type Account", balance: 10_000, currencyCode: "INR")
        let unknownPending = TransactionCandidate(
            type: .unknown,
            amount: 250,
            currencyCode: "INR",
            merchantName: "Unclassified Import",
            accountSuggestion: accountID,
            source: .sms,
            needsReview: true
        )

        let transactionID = try await transactionService.createTransaction(unknownPending)
        let pending = try await transactionService.fetchPendingReviewTransactions()
        XCTAssertEqual(pending.map(\.id), [unknownPending.id])
        var balance = try await accountService.getAccount(id: accountID)?.balance
        XCTAssertEqual(balance, 10_000)

        do {
            try await transactionService.acceptTransaction(id: transactionID)
            XCTFail("Unknown transaction types must remain in review")
        } catch TransactionServiceError.transactionTypeRequiresReview {
            // Expected.
        } catch {
            XCTFail("Expected transactionTypeRequiresReview, got \(error)")
        }

        let record = try XCTUnwrap(try fetchTransactionRecord(id: transactionID))
        XCTAssertTrue(record.isPendingReview)
        XCTAssertFalse(record.isAccepted)
        XCTAssertFalse(record.isPosted)
        balance = try await accountService.getAccount(id: accountID)?.balance
        XCTAssertEqual(balance, 10_000)

        var postedUnknown = unknownPending
        postedUnknown.needsReview = false
        do {
            _ = try await transactionService.createTransaction(postedUnknown)
            XCTFail("Posted unknown transaction types must be rejected")
        } catch TransactionServiceError.transactionTypeRequiresReview {
            // Expected.
        } catch {
            XCTFail("Expected transactionTypeRequiresReview, got \(error)")
        }

        XCTAssertEqual(
            try modelContext.fetch(FetchDescriptor<TransactionRecord>()).count,
            1
        )
        balance = try await accountService.getAccount(id: accountID)?.balance
        XCTAssertEqual(balance, 10_000)
    }

    @MainActor
    func testOrdinaryPostingKindsRejectCurrencyMismatchBeforeMutation() async throws {
        for type in [TransactionType.expense, .income, .refund] {
            let accountID = try await makeAccount(
                name: "INR \(type.rawValue)",
                balance: 10_000,
                currencyCode: "INR"
            )
            let candidate = TransactionCandidate(
                type: type,
                amount: 100,
                currencyCode: "USD",
                merchantName: "Currency Mismatch",
                accountSuggestion: accountID,
                source: .manual
            )

            try await assertThrows {
                try await self.transactionService.createTransaction(candidate)
            }
            let balance = try await accountService.getAccount(id: accountID)?.balance
            XCTAssertEqual(balance, 10_000)
        }

        let transactions = try await transactionService.fetchTransactions(
            startDate: nil,
            endDate: nil,
            categoryID: nil,
            accountID: nil
        )
        XCTAssertTrue(transactions.isEmpty)
    }

    @MainActor
    func testInvalidFractionalAndNaNAmountsAreRejectedWithoutMutation() async throws {
        let accountID = try await makeAccount(name: "Money Validation", balance: 10_000, currencyCode: "INR")
        let fractional = TransactionCandidate(
            type: .expense,
            amount: Decimal(string: "1.001")!,
            currencyCode: "INR",
            merchantName: "Fractional Cent",
            accountSuggestion: accountID,
            source: .manual
        )
        try await assertThrows {
            try await self.transactionService.createTransaction(fractional)
        }

        let notANumber = NSDecimalNumber.notANumber.decimalValue
        let nanCandidate = TransactionCandidate(
            type: .expense,
            amount: notANumber,
            currencyCode: "INR",
            merchantName: "Not A Number",
            accountSuggestion: accountID,
            source: .manual
        )
        try await assertThrows {
            try await self.transactionService.createTransaction(nanCandidate)
        }

        let balance = try await accountService.getAccount(id: accountID)?.balance
        XCTAssertEqual(balance, 10_000)
    }

    @MainActor
    func testRefundTotalsKeepGrossAndNetSpendingSeparate() async throws {
        let accountID = try await makeAccount(name: "Totals", balance: 0, currencyCode: "INR")
        let expense = TransactionCandidate(
            type: .expense,
            amount: 200,
            currencyCode: "INR",
            merchantName: "Purchase",
            accountSuggestion: accountID,
            source: .manual
        )
        let refund = TransactionCandidate(
            type: .refund,
            amount: 50,
            currencyCode: "INR",
            merchantName: "Returned Purchase",
            accountSuggestion: accountID,
            source: .manual
        )
        let income = TransactionCandidate(
            type: .income,
            amount: 1_000,
            currencyCode: "INR",
            merchantName: "Pay",
            accountSuggestion: accountID,
            source: .manual
        )
        try await transactionService.createTransaction(expense)
        try await transactionService.createTransaction(refund)
        try await transactionService.createTransaction(income)

        let totals = try await transactionService.calculateSpendingTotals(
            startDate: .distantPast,
            endDate: .distantFuture,
            currencyCode: "INR"
        )
        XCTAssertEqual(totals.income, 1_000)
        XCTAssertEqual(totals.grossExpense, 200)
        XCTAssertEqual(totals.refunds, 50)
        XCTAssertEqual(totals.netSpending, 150)
    }

    @MainActor
    private func fetchTransactionRecord(id: String) throws -> TransactionRecord? {
        let records = try modelContext.fetch(FetchDescriptor<TransactionRecord>())
        return records.first { $0.id == id }
    }

    @MainActor
    private func insertLegacyPendingTransaction(
        type: TransactionType,
        amount: Decimal,
        currencyCode: String,
        accountID: String?,
        destinationAccountID: String?
    ) throws -> String {
        let accounts = try modelContext.fetch(FetchDescriptor<AccountRecord>())
        let account = accountID.flatMap { id in accounts.first { $0.id == id } }
        let destinationAccount = destinationAccountID.flatMap { id in accounts.first { $0.id == id } }
        let record = TransactionRecord(
            type: type,
            amount: amount,
            currencyCode: currencyCode,
            merchantName: "Legacy Pending",
            account: account,
            destinationAccount: destinationAccount,
            source: .manual
        )
        record.isPendingReview = true
        record.isAccepted = false
        modelContext.insert(record)
        try modelContext.save()
        return record.id
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
