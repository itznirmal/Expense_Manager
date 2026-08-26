//
//  AccountsListViewModel.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Observable ViewModel for Financial Accounts Management.
//

import SwiftUI
import Observation

@Observable
@MainActor
public final class AccountsListViewModel {
    
    // MARK: - State Properties
    
    public var allAccounts: [AccountDTO] = []
    public var showArchived: Bool = false
    public var isLoading: Bool = false
    public var errorMessage: String? = nil
    
    public var selectedAccountForEdit: AccountDTO? = nil
    public var isComposerPresented: Bool = false
    
    // MARK: - Computed Groupings & Metrics
    
    public var activeAccounts: [AccountDTO] {
        allAccounts.filter { !$0.isArchived }
    }
    
    public var bankAccounts: [AccountDTO] {
        allAccounts.filter { ($0.type == .bank || $0.type == .savings || $0.type == .investment) && (showArchived || !$0.isArchived) }
    }
    
    public var creditCardAccounts: [AccountDTO] {
        allAccounts.filter { $0.type == .creditCard && (showArchived || !$0.isArchived) }
    }
    
    public var walletAndCashAccounts: [AccountDTO] {
        allAccounts.filter { ($0.type == .cash || $0.type == .wallet) && (showArchived || !$0.isArchived) }
    }
    
    public var archivedAccounts: [AccountDTO] {
        allAccounts.filter { $0.isArchived }
    }
    
    /// Total Assets: Sum of all positive balances across checking, savings, wallets, cash, and investments.
    public var totalAssets: Decimal {
        activeAccounts
            .filter { $0.type != .creditCard && $0.currencyCode == CurrencyFormatter.defaultCurrencyCode }
            .reduce(Decimal.zero) { sum, acc in
                acc.balance > .zero ? sum + acc.balance : sum
            }
    }
    
    /// Total Liabilities: Total outstanding credit card debt or negative balances.
    public var totalLiabilities: Decimal {
        let ccDebt = activeAccounts
            .filter { $0.type == .creditCard && $0.currencyCode == CurrencyFormatter.defaultCurrencyCode }
            .reduce(Decimal.zero) { sum, acc in
                // If credit card balance is negative (e.g. -₹12,450), the liability magnitude is ₹12,450
                acc.balance < .zero ? sum + abs(acc.balance) : sum
            }
        
        let otherNegative = activeAccounts
            .filter { $0.type != .creditCard && $0.balance < .zero && $0.currencyCode == CurrencyFormatter.defaultCurrencyCode }
            .reduce(Decimal.zero) { sum, acc in
                sum + abs(acc.balance)
            }
        
        return ccDebt + otherNegative
    }
    
    /// Net Worth = Total Assets - Total Liabilities.
    public var netWorth: Decimal {
        totalAssets - totalLiabilities
    }
    
    public init() {}
    
    // MARK: - Actions
    
    public func loadAccounts(container: DependencyContainer) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            allAccounts = try await container.accountService.fetchAccounts(includeArchived: true)
        } catch {
            errorMessage = "Failed to load accounts: \(error.localizedDescription)"
        }
    }
    
    public func toggleArchive(account: AccountDTO, container: DependencyContainer) async {
        do {
            let newStatus = !account.isArchived
            try await container.accountService.setArchived(accountID: account.id, isArchived: newStatus)
            await loadAccounts(container: container)
        } catch {
            errorMessage = "Failed to update account archive status: \(error.localizedDescription)"
        }
    }
}
