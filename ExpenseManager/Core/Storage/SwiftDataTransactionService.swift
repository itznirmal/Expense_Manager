//
//  SwiftDataTransactionService.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  SwiftData Implementation of TransactionServiceProtocol.
//

import Foundation
import SwiftData

/// Error types thrown during transaction service operations.
public enum TransactionServiceError: LocalizedError, Sendable {
    case transactionNotFound(id: String)
    case transactionIdentifierAlreadyExists(id: String)
    case contextSaveFailed(String)
    case transactionMissingSourceAccount
    case transferMissingDestination
    case transferSourceAndDestinationMustBeDistinct
    case cashWithdrawalMissingCashAccount
    case accountCurrencyMismatch(accountID: String, expectedCurrencyCode: String, actualCurrencyCode: String)
    case ambiguousAccountSuggestion(String)
    case splitAmountsMustEqualParent
    case cannotSplitPendingOrTransfer
    case transactionTypeRequiresReview
    
    public var errorDescription: String? {
        switch self {
        case .transactionNotFound(let id):
            return "Transaction with identifier '\(id)' was not found."
        case .transactionIdentifierAlreadyExists:
            return "A transaction with this identifier already exists. Edit the existing entry instead."
        case .contextSaveFailed(let message):
            return "Failed to save transaction data: \(message)"
        case .transactionMissingSourceAccount:
            return "Transactions requiring a balance effect must have a valid source account."
        case .transferMissingDestination:
            return "Transfers require a valid destination account."
        case .transferSourceAndDestinationMustBeDistinct:
            return "Transfers require a valid and distinct destination account."
        case .cashWithdrawalMissingCashAccount:
            return "Cash withdrawals require an active Cash account as their destination."
        case .accountCurrencyMismatch(let accountID, let expectedCurrencyCode, let actualCurrencyCode):
            return "Account '\(accountID)' uses \(actualCurrencyCode), but the transaction uses \(expectedCurrencyCode)."
        case .ambiguousAccountSuggestion(let suggestion):
            return "Account suggestion '\(suggestion)' matches more than one account."
        case .splitAmountsMustEqualParent:
            return "Split line amounts must exactly equal the original transaction amount."
        case .cannotSplitPendingOrTransfer:
            return "Pending reviews and transfers cannot be split."
        case .transactionTypeRequiresReview:
            return "Unknown transaction types must remain in review until they are classified."
        }
    }
}

/// SwiftData persistent implementation of the Transaction Ledger Service.
@MainActor
public final class SwiftDataTransactionService: TransactionServiceProtocol, Sendable {
    
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }
    
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    // MARK: - TransactionServiceProtocol
    
    public func fetchRecentTransactions(limit: Int) async throws -> [TransactionCandidate] {
        let descriptor = FetchDescriptor<TransactionRecord>(
            sortBy: [SortDescriptor(\.transactionDate, order: .reverse)]
        )
        let records = try modelContext.fetch(descriptor)
        return Array(records.filter(\.isPosted).prefix(max(0, limit))).map { $0.toCandidate() }
    }
    
    public func fetchPendingReviewTransactions() async throws -> [TransactionCandidate] {
        let descriptor = FetchDescriptor<TransactionRecord>(
            sortBy: [SortDescriptor(\.transactionDate, order: .reverse)]
        )
        let records = try modelContext.fetch(descriptor)
        return records.filter { $0.isPendingReview && !$0.isPosted }.map { $0.toCandidate() }
    }
    
    public func fetchTransactions(
        startDate: Date?,
        endDate: Date?,
        categoryID: String?,
        accountID: String?
    ) async throws -> [TransactionCandidate] {
        let descriptor = FetchDescriptor<TransactionRecord>(
            sortBy: [SortDescriptor(\.transactionDate, order: .reverse)]
        )
        let records = try modelContext.fetch(descriptor)
        
        return records
            .filter { record in
                if let start = startDate, record.transactionDate < start { return false }
                if let end = endDate, record.transactionDate > end { return false }
                if !record.isPosted { return false }
                if let cat = categoryID, record.category?.id != cat && record.category?.name != cat { return false }
                if let acc = accountID,
                   record.account?.id != acc &&
                   record.account?.name != acc &&
                   record.destinationAccount?.id != acc &&
                   record.destinationAccount?.name != acc {
                    return false
                }
                return true
            }
            .map { $0.toCandidate() }
    }
    
    @discardableResult
    public func createTransaction(_ candidate: TransactionCandidate) async throws -> String {
        try validatePostingType(candidate.type, needsReview: candidate.needsReview)
        let record = try insertTransaction(candidate)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw TransactionServiceError.contextSaveFailed(error.localizedDescription)
        }

        return record.id
    }

    public func createTransactionAndFingerprint(
        _ candidate: TransactionCandidate,
        sourceHash: String,
        accountLastFour: String?,
        source: String
    ) async throws -> TransactionImportResult {
        try validatePostingType(candidate.type, needsReview: candidate.needsReview)
        try MoneyValidation.validate(amount: candidate.amount, currencyCode: candidate.currencyCode)
        if try hasDuplicateFingerprint(
            sourceHash: sourceHash,
            amount: candidate.amount,
            merchant: candidate.merchantName,
            accountLastFour: accountLastFour,
            referenceNumber: candidate.sourceReference,
            timestamp: candidate.transactionDate
        ) {
            return .duplicate
        }

        let record: TransactionRecord
        do {
            record = try insertTransaction(candidate)
        } catch {
            modelContext.rollback()
            throw error
        }

        do {
            let fingerprint = ImportFingerprintRecord(
                sourceHash: sourceHash,
                amount: candidate.amount,
                normalizedMerchant: candidate.merchantName.trimmingCharacters(in: .whitespacesAndNewlines),
                accountLastFour: accountLastFour,
                transactionReference: candidate.sourceReference,
                approximateTimestamp: candidate.transactionDate,
                source: source
            )
            modelContext.insert(fingerprint)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            if (try? hasFingerprint(sourceHash: sourceHash)) == true {
                return .duplicate
            }
            throw TransactionServiceError.contextSaveFailed(error.localizedDescription)
        }

        return .saved(transactionID: record.id)
    }
    
    public func updateTransaction(id: String, candidate: TransactionCandidate) async throws {
        guard let record = try fetchRecord(by: id) else {
            throw TransactionServiceError.transactionNotFound(id: id)
        }
        
        // Resolve and validate BEFORE mutating balances so failures leave the ledger intact.
        try validatePostingType(candidate.type, needsReview: candidate.needsReview)
        try MoneyValidation.validate(amount: candidate.amount, currencyCode: candidate.currencyCode)
        let normalizedAmount = candidate.amount
        let oldType = record.transactionType
        let oldAmount = record.amount
        let oldAccount = record.account
        let oldDestAccount = record.destinationAccount
        let hadAcceptedEffect = record.isPosted

        // Resolve and validate every replacement relationship before touching the old effect.
        let resolvedCategory = try resolveCategory(for: candidate.categorySuggestion)
        let resolvedAccount = try resolveAccountSuggestion(
            for: candidate.accountSuggestion,
            accountLastFour: candidate.accountLastFour
        )

        var resolvedDestinationAccount: AccountRecord?
        if candidate.type == .transfer {
            guard resolvedAccount != nil else {
                throw TransactionServiceError.transactionMissingSourceAccount
            }
            guard let dest = try resolveAccount(for: candidate.destinationAccountSuggestion) else {
                throw TransactionServiceError.transferMissingDestination
            }
            resolvedDestinationAccount = dest
        } else if candidate.type == .cashWithdrawal {
            guard let source = resolvedAccount else {
                throw TransactionServiceError.transactionMissingSourceAccount
            }
            try validateCurrency(of: source, expected: candidate.currencyCode)
            resolvedDestinationAccount = try resolveCashAccount(currencyCode: candidate.currencyCode)
        } else {
            resolvedDestinationAccount = try resolveAccount(for: candidate.destinationAccountSuggestion)
        }

        try validateBalanceEffectRelationships(
            for: candidate.type,
            currencyCode: candidate.currencyCode,
            account: resolvedAccount,
            destinationAccount: resolvedDestinationAccount
        )

        let isPending = candidate.needsReview

        // Reverse the old balance effect only after replacement validation succeeds.
        if hadAcceptedEffect {
            rollbackBalanceEffect(for: oldType, amount: oldAmount, account: oldAccount, destinationAccount: oldDestAccount)
        }
        
        record.transactionType = candidate.type
        record.amount = normalizedAmount
        record.currencyCode = candidate.currencyCode
        record.merchantName = candidate.merchantName
        record.category = resolvedCategory
        record.account = resolvedAccount
        record.destinationAccount = resolvedDestinationAccount
        record.resolvedPaymentMethod = candidate.paymentMethod
        record.transactionDate = candidate.transactionDate
        record.notes = candidate.notes
        record.tags = candidate.tags
        record.inputSource = candidate.source
        record.sourceReference = candidate.sourceReference
        record.confidence = candidate.confidence.value
        record.isPendingReview = isPending
        record.isAccepted = !isPending
        record.reviewReasons = candidate.warnings
        record.updatedAt = Date()
        
        if record.isPosted {
            try applyBalanceEffect(for: candidate.type, amount: normalizedAmount, account: resolvedAccount, destinationAccount: resolvedDestinationAccount)
        }
        
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw TransactionServiceError.contextSaveFailed(error.localizedDescription)
        }
    }
    
    public func acceptTransaction(id: String) async throws {
        guard let record = try fetchRecord(by: id) else {
            throw TransactionServiceError.transactionNotFound(id: id)
        }
        guard record.isPendingReview else { return }

        guard record.transactionType != .unknown else {
            throw TransactionServiceError.transactionTypeRequiresReview
        }

        try MoneyValidation.validate(amount: record.amount, currencyCode: record.currencyCode)
        try validateBalanceEffectRelationships(
            for: record.transactionType,
            currencyCode: record.currencyCode,
            account: record.account,
            destinationAccount: record.destinationAccount
        )
        
        if record.transactionType == .transfer {
            guard let dest = record.destinationAccount else {
                throw TransactionServiceError.transferMissingDestination
            }
            if record.account?.id == dest.id {
                throw TransactionServiceError.transferSourceAndDestinationMustBeDistinct
            }
        } else if record.transactionType == .cashWithdrawal, record.destinationAccount == nil {
            record.destinationAccount = try resolveCashAccount(currencyCode: record.currencyCode)
        }

        record.isPendingReview = false
        record.isAccepted = true

        try applyBalanceEffect(for: record.transactionType, amount: record.amount, account: record.account, destinationAccount: record.destinationAccount)
        
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw TransactionServiceError.contextSaveFailed(error.localizedDescription)
        }
    }

    public func splitTransaction(id: String, splits: [TransactionSplitLine]) async throws -> [String] {
        guard let parent = try fetchRecord(by: id) else {
            throw TransactionServiceError.transactionNotFound(id: id)
        }
        guard !parent.isPendingReview else {
            throw TransactionServiceError.cannotSplitPendingOrTransfer
        }
        guard parent.transactionType == .expense || parent.transactionType == .income || parent.transactionType == .refund else {
            throw TransactionServiceError.cannotSplitPendingOrTransfer
        }

        guard parent.isPosted else {
            throw TransactionServiceError.cannotSplitPendingOrTransfer
        }
        try MoneyValidation.validate(amount: parent.amount, currencyCode: parent.currencyCode)
        guard splits.count >= 2 else {
            throw TransactionServiceError.splitAmountsMustEqualParent
        }
        for split in splits {
            try MoneyValidation.validate(amount: split.amount, currencyCode: parent.currencyCode)
        }
        let splitTotal = splits.reduce(Decimal.zero) { $0 + $1.amount }
        guard splitTotal == parent.amount else {
            throw TransactionServiceError.splitAmountsMustEqualParent
        }
        let resolvedCategories = try splits.map {
            try resolveCategory(for: $0.categoryName) ?? parent.category
        }
        
        let oldType = parent.transactionType
        let oldAmount = parent.amount
        let oldAccount = parent.account
        let oldDest = parent.destinationAccount

        rollbackBalanceEffect(for: oldType, amount: oldAmount, account: oldAccount, destinationAccount: oldDest)

        let groupID = UUID().uuidString
        var createdIDs: [String] = []

        for (line, category) in zip(splits, resolvedCategories) {
            let child = TransactionRecord(
                id: UUID().uuidString,
                type: parent.transactionType,
                amount: line.amount,
                currencyCode: parent.currencyCode,
                merchantName: line.merchantName.isEmpty ? parent.merchantName : line.merchantName,
                category: category,
                account: parent.account,
                destinationAccount: parent.destinationAccount,
                paymentMethod: parent.resolvedPaymentMethod,
                transactionDate: parent.transactionDate,
                notes: line.notes ?? parent.notes,
                tags: parent.tags,
                source: parent.inputSource,
                sourceReference: parent.sourceReference,
                confidence: parent.confidence,
                createdAt: Date(),
                updatedAt: Date()
            )
            child.parentTransactionID = parent.id
            child.splitGroupID = groupID
            child.isPendingReview = false
            child.isAccepted = true
            try applyBalanceEffect(
                for: child.transactionType,
                amount: child.amount,
                account: child.account,
                destinationAccount: child.destinationAccount
            )
            modelContext.insert(child)
            createdIDs.append(child.id)
        }

        modelContext.delete(parent)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw TransactionServiceError.contextSaveFailed(error.localizedDescription)
        }

        return createdIDs
    }

    public func deleteTransaction(id: String) async throws {
        guard let record = try fetchRecord(by: id) else {
            throw TransactionServiceError.transactionNotFound(id: id)
        }
        
        let oldType = record.transactionType
        let oldAmount = record.amount
        let oldAccount = record.account
        let oldDestAccount = record.destinationAccount
        // Roll back balance effect prior to deletion ONLY if it was accepted
        if record.isPosted {
            rollbackBalanceEffect(for: oldType, amount: oldAmount, account: oldAccount, destinationAccount: oldDestAccount)
        }
        
        modelContext.delete(record)
        
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw TransactionServiceError.contextSaveFailed(error.localizedDescription)
        }
    }
    
    public func calculateTotals(startDate: Date, endDate: Date, currencyCode: String) async throws -> (income: Decimal, expense: Decimal) {
        let descriptor = FetchDescriptor<TransactionRecord>()
        let records = try modelContext.fetch(descriptor)
        
        var totalIncome: Decimal = .zero
        var totalExpense: Decimal = .zero
        
        for record in records where record.transactionDate >= startDate && record.transactionDate <= endDate && record.isPosted && record.currencyCode == currencyCode {
            switch record.transactionType {
            case .income:
                totalIncome += record.amount
            case .refund:
                totalExpense -= record.amount
            case .expense:
                totalExpense += record.amount
            case .transfer, .cashWithdrawal, .unknown:
                // Transfers and cash withdrawals must NOT inflate income or expense totals
                break
            }
        }
        
        return (totalIncome, totalExpense)
    }

    public func calculateSpendingTotals(
        startDate: Date,
        endDate: Date,
        currencyCode: String
    ) async throws -> TransactionTotals {
        let records = try modelContext.fetch(FetchDescriptor<TransactionRecord>())
        var income: Decimal = .zero
        var grossExpense: Decimal = .zero
        var refunds: Decimal = .zero

        for record in records where
            record.transactionDate >= startDate &&
            record.transactionDate <= endDate &&
            record.isPosted &&
            record.currencyCode == currencyCode {
            switch record.transactionType {
            case .income:
                income += record.amount
            case .expense:
                grossExpense += record.amount
            case .refund:
                refunds += record.amount
            case .transfer, .cashWithdrawal, .unknown:
                break
            }
        }

        return TransactionTotals(income: income, grossExpense: grossExpense, refunds: refunds)
    }
    
    // MARK: - Private Balance Invariant Helpers

    private func validateBalanceEffectRelationships(
        for type: TransactionType,
        currencyCode: String,
        account: AccountRecord?,
        destinationAccount: AccountRecord?
    ) throws {
        switch type {
        case .transfer:
            guard let source = account else {
                throw TransactionServiceError.transactionMissingSourceAccount
            }
            try validateCurrency(of: source, expected: currencyCode)

            guard let destination = destinationAccount else {
                throw TransactionServiceError.transferMissingDestination
            }
            guard source.id != destination.id else {
                throw TransactionServiceError.transferSourceAndDestinationMustBeDistinct
            }
            try validateCurrency(of: destination, expected: currencyCode)

        case .cashWithdrawal:
            guard let source = account else {
                throw TransactionServiceError.transactionMissingSourceAccount
            }
            try validateCurrency(of: source, expected: currencyCode)

            guard let destination = destinationAccount,
                  destination.accountType == .cash,
                  !destination.isArchived else {
                throw TransactionServiceError.cashWithdrawalMissingCashAccount
            }
            guard source.id != destination.id else {
                throw TransactionServiceError.transferSourceAndDestinationMustBeDistinct
            }
            try validateCurrency(of: destination, expected: currencyCode)

        case .expense, .income, .refund:
            if let account {
                try validateCurrency(of: account, expected: currencyCode)
            }
        case .unknown:
            break
        }
    }

    private func validateCurrency(of account: AccountRecord, expected currencyCode: String) throws {
        guard account.currencyCode == currencyCode else {
            throw TransactionServiceError.accountCurrencyMismatch(
                accountID: account.id,
                expectedCurrencyCode: currencyCode,
                actualCurrencyCode: account.currencyCode
            )
        }
    }
    
    private func applyBalanceEffect(
        for type: TransactionType,
        amount: Decimal,
        account: AccountRecord?,
        destinationAccount: AccountRecord?
    ) throws {
        guard let account = account else { return }
        
        switch type {
        case .expense:
            account.currentBalance -= amount
        case .income, .refund:
            account.currentBalance += amount
        case .transfer, .cashWithdrawal:
            guard let destinationAccount else {
                throw TransactionServiceError.transferMissingDestination
            }
            guard destinationAccount.id != account.id else {
                throw TransactionServiceError.transferSourceAndDestinationMustBeDistinct
            }
            account.currentBalance -= amount
            destinationAccount.currentBalance += amount
        case .unknown:
            break
        }
    }
    
    private func rollbackBalanceEffect(
        for type: TransactionType,
        amount: Decimal,
        account: AccountRecord?,
        destinationAccount: AccountRecord?
    ) {
        guard let account = account else { return }
        
        switch type {
        case .expense:
            account.currentBalance += amount
        case .income, .refund:
            account.currentBalance -= amount
        case .transfer, .cashWithdrawal:
            account.currentBalance += amount
            destinationAccount?.currentBalance -= amount
        case .unknown:
            break
        }
    }

    /// Builds and inserts a transaction without saving the context.
    /// Callers use this to compose a larger atomic persistence operation.
    private func insertTransaction(_ candidate: TransactionCandidate) throws -> TransactionRecord {
        try validatePostingType(candidate.type, needsReview: candidate.needsReview)
        try MoneyValidation.validate(amount: candidate.amount, currencyCode: candidate.currencyCode)
        guard try fetchRecord(by: candidate.id.uuidString) == nil else {
            throw TransactionServiceError.transactionIdentifierAlreadyExists(id: candidate.id.uuidString)
        }
        let normalizedAmount = candidate.amount
        let resolvedCategory = try resolveCategory(for: candidate.categorySuggestion)
        let resolvedAccount = try resolveAccountSuggestion(
            for: candidate.accountSuggestion,
            accountLastFour: candidate.accountLastFour
        )
        var resolvedDestinationAccount: AccountRecord?

        if candidate.type == .transfer {
            guard resolvedAccount != nil else {
                throw TransactionServiceError.transactionMissingSourceAccount
            }
            guard let destination = try resolveAccount(for: candidate.destinationAccountSuggestion) else {
                throw TransactionServiceError.transferMissingDestination
            }
            resolvedDestinationAccount = destination
        } else if candidate.type == .cashWithdrawal {
            guard let source = resolvedAccount else {
                throw TransactionServiceError.transactionMissingSourceAccount
            }
            try validateCurrency(of: source, expected: candidate.currencyCode)
            resolvedDestinationAccount = try resolveCashAccount(currencyCode: candidate.currencyCode)
        } else {
            resolvedDestinationAccount = try resolveAccount(for: candidate.destinationAccountSuggestion)
        }

        try validateBalanceEffectRelationships(
            for: candidate.type,
            currencyCode: candidate.currencyCode,
            account: resolvedAccount,
            destinationAccount: resolvedDestinationAccount
        )

        let isPending = candidate.needsReview
        let record = TransactionRecord(
            id: candidate.id.uuidString,
            type: candidate.type,
            amount: normalizedAmount,
            currencyCode: candidate.currencyCode,
            merchantName: candidate.merchantName,
            category: resolvedCategory,
            account: resolvedAccount,
            destinationAccount: resolvedDestinationAccount,
            paymentMethod: candidate.paymentMethod,
            transactionDate: candidate.transactionDate,
            notes: candidate.notes,
            tags: candidate.tags,
            source: candidate.source,
            sourceReference: candidate.sourceReference,
            confidence: candidate.confidence.value,
            createdAt: Date(),
            updatedAt: Date()
        )

        record.isPendingReview = isPending
        record.isAccepted = !isPending

        if record.isPosted {
            try applyBalanceEffect(
                for: candidate.type,
                amount: normalizedAmount,
                account: resolvedAccount,
                destinationAccount: resolvedDestinationAccount
            )
        }

        modelContext.insert(record)
        return record
    }

    private func validatePostingType(_ type: TransactionType, needsReview: Bool) throws {
        guard type != .unknown || needsReview else {
            throw TransactionServiceError.transactionTypeRequiresReview
        }
    }

    private func hasDuplicateFingerprint(
        sourceHash: String,
        amount: Decimal,
        merchant: String,
        accountLastFour: String?,
        referenceNumber: String?,
        timestamp: Date
    ) throws -> Bool {
        let exactDescriptor = FetchDescriptor<ImportFingerprintRecord>(
            predicate: #Predicate { $0.sourceHash == sourceHash }
        )
        if try modelContext.fetch(exactDescriptor).isEmpty == false {
            return true
        }

        let normalizedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let windowStart = timestamp.addingTimeInterval(-300)
        let windowEnd = timestamp.addingTimeInterval(300)
        let records = try modelContext.fetch(FetchDescriptor<ImportFingerprintRecord>())

        return records.contains { item in
            if let referenceNumber,
               let itemReference = item.transactionReference,
               !referenceNumber.isEmpty,
               referenceNumber == itemReference {
                return true
            }

            guard item.amount == amount,
                  item.approximateTimestamp >= windowStart,
                  item.approximateTimestamp <= windowEnd else {
                return false
            }

            let itemMerchant = item.normalizedMerchant
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let merchantMatches = itemMerchant == normalizedMerchant ||
                itemMerchant.contains(normalizedMerchant) ||
                normalizedMerchant.contains(itemMerchant)
            guard merchantMatches else { return false }

            if let accountLastFour, let itemAccountLastFour = item.accountLastFour {
                return accountLastFour == itemAccountLastFour
            }
            return true
        }
    }

    private func hasFingerprint(sourceHash: String) throws -> Bool {
        let descriptor = FetchDescriptor<ImportFingerprintRecord>(
            predicate: #Predicate { $0.sourceHash == sourceHash }
        )
        return try modelContext.fetch(descriptor).isEmpty == false
    }
    
    // MARK: - Private Lookups
    
    private func fetchRecord(by id: String) throws -> TransactionRecord? {
        let descriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    private func resolveAccount(
        for identifierOrName: String?,
        accountLastFour: String? = nil
    ) throws -> AccountRecord? {
        let descriptor = FetchDescriptor<AccountRecord>()
        let accounts = try modelContext.fetch(descriptor)
        let explicitLastFour = accountLastFour.flatMap(Self.normalizedLastFour)

        guard let identifierOrName = identifierOrName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !identifierOrName.isEmpty else {
            guard let explicitLastFour else { return nil }
            let maskMatches = accounts.filter {
                Self.normalizedLastFour($0.lastFour) == explicitLastFour
            }
            if maskMatches.count == 1 {
                return maskMatches[0]
            }
            if maskMatches.count > 1 {
                throw TransactionServiceError.ambiguousAccountSuggestion(explicitLastFour)
            }
            return nil
        }

        // Stable IDs are always preferred over display names or hints.
        if let directIDMatch = accounts.first(where: { $0.id == identifierOrName }) {
            if let explicitLastFour,
               Self.normalizedLastFour(directIDMatch.lastFour) != explicitLastFour {
                throw TransactionServiceError.ambiguousAccountSuggestion(identifierOrName)
            }
            return directIDMatch
        }

        let exactNameMatches = accounts.filter {
            $0.name.localizedCaseInsensitiveCompare(identifierOrName) == .orderedSame
        }
        if exactNameMatches.count == 1 {
            if let explicitLastFour,
               Self.normalizedLastFour(exactNameMatches[0].lastFour) != explicitLastFour {
                throw TransactionServiceError.ambiguousAccountSuggestion(identifierOrName)
            }
            return exactNameMatches[0]
        }
        if exactNameMatches.count > 1 {
            throw TransactionServiceError.ambiguousAccountSuggestion(identifierOrName)
        }

        let hintedDigits = identifierOrName.filter(\.isNumber)
        let hintedLastFour = hintedDigits.count >= 4 ? String(hintedDigits.suffix(4)) : nil
        let requestedLastFour = explicitLastFour ?? hintedLastFour

        if let requestedLastFour {
            let lastFourMatches = accounts.filter {
                Self.normalizedLastFour($0.lastFour) == requestedLastFour
            }
            if lastFourMatches.count == 1 {
                return lastFourMatches[0]
            }
            if lastFourMatches.count > 1 {
                throw TransactionServiceError.ambiguousAccountSuggestion(identifierOrName)
            }
            // An explicit mask that matches no account must not fall through to
            // fuzzy matching and select an arbitrary same-bank account.
            if explicitLastFour != nil {
                return nil
            }
        }

        let fuzzyMatches = accounts.filter {
            $0.name.localizedCaseInsensitiveContains(identifierOrName)
        }
        if fuzzyMatches.count == 1 {
            return fuzzyMatches[0]
        }
        if fuzzyMatches.count > 1 {
            throw TransactionServiceError.ambiguousAccountSuggestion(identifierOrName)
        }

        return nil
    }

    private func resolveAccountSuggestion(
        for suggestion: String?,
        accountLastFour: String? = nil
    ) throws -> AccountRecord? {
        let resolvedAccount = try resolveAccount(for: suggestion, accountLastFour: accountLastFour)
        guard resolvedAccount == nil else { return resolvedAccount }
        guard let suggestion,
              !suggestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if accountLastFour != nil {
                throw TransactionServiceError.transactionMissingSourceAccount
            }
            return nil
        }
        throw TransactionServiceError.transactionMissingSourceAccount
    }

    private static func normalizedLastFour(_ value: String?) -> String? {
        guard let value else { return nil }
        let digits = value.filter(\.isNumber)
        guard digits.count >= 4 else { return nil }
        return String(digits.suffix(4))
    }
    
    private func resolveCategory(for identifierOrName: String?) throws -> CategoryRecord? {
        guard let identifierOrName = identifierOrName?.trimmingCharacters(in: .whitespacesAndNewlines), !identifierOrName.isEmpty else { return nil }
        
        let descriptor = FetchDescriptor<CategoryRecord>()
        let categories = try modelContext.fetch(descriptor)
        
        // 1. Direct ID match
        if let directIDMatch = categories.first(where: { $0.id == identifierOrName }) {
            return directIDMatch
        }
        
        // 2. Exact name match
        if let exactNameMatch = categories.first(where: { $0.name.localizedCaseInsensitiveCompare(identifierOrName) == .orderedSame }) {
            return exactNameMatch
        }
        
        // 3. Substring match
        if let fuzzyMatch = categories.first(where: {
            $0.name.localizedCaseInsensitiveContains(identifierOrName) ||
            identifierOrName.localizedCaseInsensitiveContains($0.name)
        }) {
            return fuzzyMatch
        }
        
        return nil
    }

    private func resolveCashAccount(currencyCode: String) throws -> AccountRecord {
        let descriptor = FetchDescriptor<AccountRecord>()
        let accounts = try modelContext.fetch(descriptor)
        if let cashAccount = accounts.first(where: {
            !$0.isArchived &&
            $0.accountType == .cash &&
            $0.currencyCode == currencyCode
        }) {
            return cashAccount
        }
        
        let newCashAccount = AccountRecord(
            id: UUID().uuidString,
            name: "Cash",
            type: .cash,
            currencyCode: currencyCode,
            openingBalance: .zero,
            currentBalance: .zero,
            icon: "banknote",
            colorToken: "brandPrimary",
            lastFour: nil,
            isArchived: false,
            createdAt: Date()
        )
        modelContext.insert(newCashAccount)
        return newCashAccount
    }
}
