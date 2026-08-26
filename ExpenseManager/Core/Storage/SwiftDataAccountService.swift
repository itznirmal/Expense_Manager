//
//  SwiftDataAccountService.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  SwiftData Implementation of AccountServiceProtocol.
//

import Foundation
import SwiftData

/// Error types thrown during account service operations.
public enum AccountServiceError: LocalizedError, Sendable {
    case accountNotFound(id: String)
    case contextSaveFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .accountNotFound(let id):
            return "Account with identifier '\(id)' was not found."
        case .contextSaveFailed(let message):
            return "Failed to save account data: \(message)"
        }
    }
}

/// SwiftData persistent implementation of the Account Management Service.
@MainActor
public final class SwiftDataAccountService: AccountServiceProtocol, Sendable {
    
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }
    
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    // MARK: - AccountServiceProtocol
    
    public func fetchAccounts(includeArchived: Bool) async throws -> [AccountDTO] {
        let descriptor = FetchDescriptor<AccountRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let records = try modelContext.fetch(descriptor)
        return records
            .filter { includeArchived || !$0.isArchived }
            .map { $0.toDTO() }
    }
    
    public func getAccount(id: String) async throws -> AccountDTO? {
        let record = try fetchRecord(by: id)
        return record?.toDTO()
    }
    
    @discardableResult
    public func createAccount(
        name: String,
        type: AccountType,
        openingBalance: Decimal,
        currencyCode: String,
        icon: String,
        colorToken: String,
        lastFour: String?
    ) async throws -> String {
        let record = AccountRecord(
            id: UUID().uuidString,
            name: name,
            type: type,
            currencyCode: currencyCode,
            openingBalance: openingBalance,
            currentBalance: openingBalance,
            icon: icon,
            colorToken: colorToken,
            lastFour: lastFour,
            isArchived: false,
            createdAt: Date()
        )
        
        modelContext.insert(record)
        try modelContext.save()
        
        return record.id
    }
    
    public func updateAccount(_ account: AccountDTO) async throws {
        guard let record = try fetchRecord(by: account.id) else {
            throw AccountServiceError.accountNotFound(id: account.id)
        }
        
        record.name = account.name
        record.accountType = account.type
        record.currencyCode = account.currencyCode
        record.currentBalance = account.balance
        record.openingBalance = account.balance
        record.icon = account.icon
        record.colorToken = account.colorToken
        record.lastFour = account.lastFour
        record.isArchived = account.isArchived
        
        try modelContext.save()
    }
    
    public func setArchived(accountID: String, isArchived: Bool) async throws {
        guard let record = try fetchRecord(by: accountID) else {
            throw AccountServiceError.accountNotFound(id: accountID)
        }
        
        record.isArchived = isArchived
        try modelContext.save()
    }
    
    /// Calculates the net total balance across active accounts in base currency, grouping or filtering by default currency to prevent cross-currency blind summation (GT-67).
    public func calculateNetWorth() async throws -> Decimal {
        let descriptor = FetchDescriptor<AccountRecord>()
        let records = try modelContext.fetch(descriptor)
        
        let activeRecords = records.filter { !$0.isArchived }
        
        // Group balances by currency to prevent cross-currency blind summation
        var balancesByCurrency: [String: Decimal] = [:]
        for account in activeRecords {
            let code = account.currencyCode
            balancesByCurrency[code, default: .zero] += account.currentBalance
        }
        
        // Primary net worth calculation for the default/base currency
        let defaultCode = CurrencyFormatter.defaultCurrencyCode
        if let primaryNetWorth = balancesByCurrency[defaultCode] {
            return primaryNetWorth
        } else if let firstEntry = balancesByCurrency.first {
            return firstEntry.value
        }
        
        return .zero
    }
    
    /// Calculates net worth grouped per currency code.
    public func calculateNetWorthByCurrency() async throws -> [String: Decimal] {
        let descriptor = FetchDescriptor<AccountRecord>()
        let records = try modelContext.fetch(descriptor)
        
        var netWorthMap: [String: Decimal] = [:]
        for account in records where !account.isArchived {
            netWorthMap[account.currencyCode, default: .zero] += account.currentBalance
        }
        return netWorthMap
    }
    
    // MARK: - Private Helpers
    
    private func fetchRecord(by id: String) throws -> AccountRecord? {
        let descriptor = FetchDescriptor<AccountRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
}
