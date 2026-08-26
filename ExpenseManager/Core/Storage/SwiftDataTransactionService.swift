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
    case contextSaveFailed(String)
    case transferMissingDestination
    
    public var errorDescription: String? {
        switch self {
        case .transactionNotFound(let id):
            return "Transaction with identifier '\(id)' was not found."
        case .contextSaveFailed(let message):
            return "Failed to save transaction data: \(message)"
        case .transferMissingDestination:
            return "Transfers require a valid and distinct destination account."
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
        var descriptor = FetchDescriptor<TransactionRecord>(
            sortBy: [SortDescriptor(\.transactionDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        let records = try modelContext.fetch(descriptor)
        return records.map { $0.toCandidate() }
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
        let normalizedAmount = abs(candidate.amount)
        let resolvedCategory = try resolveCategory(for: candidate.categorySuggestion)
        let resolvedAccount = try resolveAccount(for: candidate.accountSuggestion)
        let resolvedDestinationAccount = try resolveAccount(for: candidate.destinationAccountSuggestion)
        
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
        
        // Apply balance adjustment invariant
        applyBalanceEffect(for: candidate.type, amount: normalizedAmount, account: resolvedAccount, destinationAccount: resolvedDestinationAccount)
        
        modelContext.insert(record)
        
        do {
            try modelContext.save()
        } catch {
            // Rollback balance modification if save fails
            rollbackBalanceEffect(for: candidate.type, amount: normalizedAmount, account: resolvedAccount, destinationAccount: resolvedDestinationAccount)
            modelContext.delete(record)
            throw TransactionServiceError.contextSaveFailed(error.localizedDescription)
        }
        
        return record.id
    }
    
    public func updateTransaction(id: String, candidate: TransactionCandidate) async throws {
        guard let record = try fetchRecord(by: id) else {
            throw TransactionServiceError.transactionNotFound(id: id)
        }
        
        let normalizedAmount = abs(candidate.amount)
        let oldType = record.transactionType
        let oldAmount = record.amount
        let oldAccount = record.account
        let oldDestAccount = record.destinationAccount
        
        // 1. Roll back old balance effect
        rollbackBalanceEffect(for: oldType, amount: oldAmount, account: oldAccount, destinationAccount: oldDestAccount)
        
        // 2. Resolve new relationships
        let resolvedCategory = try resolveCategory(for: candidate.categorySuggestion)
        let resolvedAccount = try resolveAccount(for: candidate.accountSuggestion)
        let resolvedDestinationAccount = try resolveAccount(for: candidate.destinationAccountSuggestion)
        
        // 3. Update record properties
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
        record.updatedAt = Date()
        
        // 4. Apply new balance effect
        applyBalanceEffect(for: candidate.type, amount: normalizedAmount, account: resolvedAccount, destinationAccount: resolvedDestinationAccount)
        
        do {
            try modelContext.save()
        } catch {
            // Rollback to old balance state if save fails
            rollbackBalanceEffect(for: candidate.type, amount: normalizedAmount, account: resolvedAccount, destinationAccount: resolvedDestinationAccount)
            applyBalanceEffect(for: oldType, amount: oldAmount, account: oldAccount, destinationAccount: oldDestAccount)
            throw TransactionServiceError.contextSaveFailed(error.localizedDescription)
        }
    }
    
    public func deleteTransaction(id: String) async throws {
        guard let record = try fetchRecord(by: id) else {
            throw TransactionServiceError.transactionNotFound(id: id)
        }
        
        let oldType = record.transactionType
        let oldAmount = record.amount
        let oldAccount = record.account
        let oldDestAccount = record.destinationAccount
        
        // Roll back balance effect prior to deletion
        rollbackBalanceEffect(for: oldType, amount: oldAmount, account: oldAccount, destinationAccount: oldDestAccount)
        
        modelContext.delete(record)
        
        do {
            try modelContext.save()
        } catch {
            // Reapply balance effect if delete fails
            applyBalanceEffect(for: oldType, amount: oldAmount, account: oldAccount, destinationAccount: oldDestAccount)
            throw TransactionServiceError.contextSaveFailed(error.localizedDescription)
        }
    }
    
    public func calculateTotals(startDate: Date, endDate: Date) async throws -> (income: Decimal, expense: Decimal) {
        let descriptor = FetchDescriptor<TransactionRecord>()
        let records = try modelContext.fetch(descriptor)
        
        var totalIncome: Decimal = .zero
        var totalExpense: Decimal = .zero
        
        for record in records where record.transactionDate >= startDate && record.transactionDate <= endDate {
            switch record.transactionType {
            case .income, .refund:
                totalIncome += record.amount
            case .expense:
                totalExpense += record.amount
            case .transfer, .cashWithdrawal, .unknown:
                // Transfers and cash withdrawals must NOT inflate income or expense totals
                break
            }
        }
        
        return (totalIncome, totalExpense)
    }
    
    // MARK: - Private Balance Invariant Helpers
    
    private func applyBalanceEffect(
        for type: TransactionType,
        amount: Decimal,
        account: AccountRecord?,
        destinationAccount: AccountRecord?
    ) {
        guard let account = account else { return }
        
        switch type {
        case .expense:
            account.currentBalance -= amount
        case .income, .refund:
            account.currentBalance += amount
        case .transfer, .cashWithdrawal:
            account.currentBalance -= amount
            destinationAccount?.currentBalance += amount
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
    
    // MARK: - Private Lookups
    
    private func fetchRecord(by id: String) throws -> TransactionRecord? {
        let descriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    private func resolveAccount(for identifierOrName: String?) throws -> AccountRecord? {
        guard let identifierOrName = identifierOrName?.trimmingCharacters(in: .whitespacesAndNewlines), !identifierOrName.isEmpty else { return nil }
        
        let descriptor = FetchDescriptor<AccountRecord>()
        let accounts = try modelContext.fetch(descriptor)
        
        // 1. Direct ID match
        if let directIDMatch = accounts.first(where: { $0.id == identifierOrName }) {
            return directIDMatch
        }
        
        // 2. Exact name match
        if let exactNameMatch = accounts.first(where: { $0.name.localizedCaseInsensitiveCompare(identifierOrName) == .orderedSame }) {
            return exactNameMatch
        }
        
        // 3. Last 4 digits match (e.g. "HDFC Bank •••• 8432" or "8432")
        let digits = identifierOrName.filter { $0.isNumber }
        if digits.count >= 4 {
            let lastFour = String(digits.suffix(4))
            if let lastFourMatch = accounts.first(where: { $0.lastFour == lastFour }) {
                return lastFourMatch
            }
        }
        
        // 4. Substring / fuzzy match
        if let fuzzyMatch = accounts.first(where: {
            $0.name.localizedCaseInsensitiveContains(identifierOrName) ||
            identifierOrName.localizedCaseInsensitiveContains($0.name)
        }) {
            return fuzzyMatch
        }
        
        return nil
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
}
