//
//  AccountServiceProtocol.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Account Ledger Service Protocol.
//

import Foundation

/// Service protocol defining account management and balance tracking operations.
public protocol AccountServiceProtocol: Sendable {
    
    /// Fetches all active non-archived accounts.
    func fetchAccounts(includeArchived: Bool) async throws -> [AccountDTO]
    
    /// Fetches a specific account by its identifier.
    func getAccount(id: String) async throws -> AccountDTO?
    
    /// Creates a new account in the ledger. Returns the generated account ID.
    @discardableResult
    func createAccount(
        name: String,
        type: AccountType,
        openingBalance: Decimal,
        currencyCode: String,
        icon: String,
        colorToken: String,
        lastFour: String?
    ) async throws -> String
    
    /// Updates account details.
    func updateAccount(_ account: AccountDTO) async throws
    
    /// Archives or restores an account.
    func setArchived(accountID: String, isArchived: Bool) async throws
    
    /// Calculates the net total balance across all active accounts in base currency.
    func calculateNetWorth() async throws -> Decimal
}
