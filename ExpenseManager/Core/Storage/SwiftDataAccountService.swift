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
    case invalidBalance
    case unsupportedCurrencyCode(String)
    case balanceHasTooManyFractionalDigits(currencyCode: String, maximum: Int)
    case currencyChangeNotAllowed(accountID: String)
    
    public var errorDescription: String? {
        switch self {
        case .accountNotFound(let id):
            return "Account with identifier '\(id)' was not found."
        case .contextSaveFailed(let message):
            return "Failed to save account data: \(message)"
        case .invalidBalance:
            return "Account balance must be a finite Decimal value."
        case .unsupportedCurrencyCode(let code):
            return "Currency code '\(code)' is not a supported ISO currency code."
        case .balanceHasTooManyFractionalDigits(let code, let maximum):
            return "Account balance for \(code) may have at most \(maximum) fractional digits."
        case .currencyChangeNotAllowed(let id):
            return "Account '\(id)' cannot change currency after transactions have been recorded."
        }
    }
}

/// Validates signed account balances without applying transaction-only positivity rules.
public enum AccountBalanceValidation {
    public static func validate(balance: Decimal, currencyCode: String) throws {
        guard !balance.isNaN else {
            throw AccountServiceError.invalidBalance
        }

        let scalars = Array(currencyCode.unicodeScalars)
        guard scalars.count == 3,
              scalars.allSatisfy({ $0.value >= 65 && $0.value <= 90 }),
              Locale.commonISOCurrencyCodes.contains(currencyCode) else {
            throw AccountServiceError.unsupportedCurrencyCode(currencyCode)
        }

        let scale = CurrencyFormatter.fractionDigits(for: currencyCode)
        var source = balance
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &source, scale, .plain)
        guard rounded == balance else {
            throw AccountServiceError.balanceHasTooManyFractionalDigits(
                currencyCode: currencyCode,
                maximum: scale
            )
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
        try AccountBalanceValidation.validate(balance: openingBalance, currencyCode: currencyCode)
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
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw AccountServiceError.contextSaveFailed(error.localizedDescription)
        }
        
        return record.id
    }
    
    public func updateAccount(_ account: AccountDTO) async throws {
        guard let record = try fetchRecord(by: account.id) else {
            throw AccountServiceError.accountNotFound(id: account.id)
        }

        try AccountBalanceValidation.validate(balance: account.balance, currencyCode: account.currencyCode)
        if record.currencyCode != account.currencyCode,
           try hasTransactions(for: record.id) {
            throw AccountServiceError.currencyChangeNotAllowed(accountID: record.id)
        }
        
        record.name = account.name
        record.accountType = account.type
        record.currencyCode = account.currencyCode
        
        // Preserve original openingBalance
        // If the balance is updated manually, update currentBalance, do not alter openingBalance.
        record.currentBalance = account.balance
        
        record.icon = account.icon
        record.colorToken = account.colorToken
        record.lastFour = account.lastFour
        record.isArchived = account.isArchived
        
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw AccountServiceError.contextSaveFailed(error.localizedDescription)
        }
    }
    
    public func setArchived(accountID: String, isArchived: Bool) async throws {
        guard let record = try fetchRecord(by: accountID) else {
            throw AccountServiceError.accountNotFound(id: accountID)
        }
        
        record.isArchived = isArchived
        
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw AccountServiceError.contextSaveFailed(error.localizedDescription)
        }
    }
    
    /// Calculates the net total balance across active accounts matching baseCurrency.
    public func calculateNetWorth(in baseCurrency: String) async throws -> Decimal {
        let descriptor = FetchDescriptor<AccountRecord>()
        let records = try modelContext.fetch(descriptor)
        
        let activeRecords = records.filter { !$0.isArchived && $0.currencyCode == baseCurrency }
        
        var total: Decimal = .zero
        for account in activeRecords {
            total += account.currentBalance
        }
        
        return total
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

    private func hasTransactions(for accountID: String) throws -> Bool {
        let records = try modelContext.fetch(FetchDescriptor<TransactionRecord>())
        return records.contains { record in
            record.account?.id == accountID || record.destinationAccount?.id == accountID
        }
    }
}
