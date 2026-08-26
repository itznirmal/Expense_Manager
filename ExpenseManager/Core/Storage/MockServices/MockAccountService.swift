//
//  MockAccountService.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  In-Memory Mock Account Service.
//

import Foundation

public final class MockAccountService: AccountServiceProtocol, @unchecked Sendable {
    private var accounts: [AccountDTO] = []
    private let lock = NSLock()
    
    public init(sampleData: [AccountDTO]? = nil) {
        if let sampleData = sampleData {
            self.accounts = sampleData
        } else {
            self.accounts = Self.defaultSampleAccounts()
        }
    }
    
    public func fetchAccounts(includeArchived: Bool) async throws -> [AccountDTO] {
        lock.lock()
        defer { lock.unlock() }
        return accounts.filter { includeArchived || !$0.isArchived }
    }
    
    public func getAccount(id: String) async throws -> AccountDTO? {
        lock.lock()
        defer { lock.unlock() }
        return accounts.first(where: { $0.id == id })
    }
    
    public func createAccount(
        name: String,
        type: AccountType,
        openingBalance: Decimal,
        currencyCode: String,
        icon: String,
        colorToken: String,
        lastFour: String?
    ) async throws -> String {
        lock.lock()
        defer { lock.unlock() }
        let newAccount = AccountDTO(
            id: UUID().uuidString,
            name: name,
            type: type,
            currencyCode: currencyCode,
            balance: openingBalance,
            icon: icon,
            colorToken: colorToken,
            lastFour: lastFour,
            isArchived: false,
            createdAt: Date()
        )
        accounts.append(newAccount)
        return newAccount.id
    }
    
    public func updateAccount(_ account: AccountDTO) async throws {
        lock.lock()
        defer { lock.unlock() }
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
        }
    }
    
    public func setArchived(accountID: String, isArchived: Bool) async throws {
        lock.lock()
        defer { lock.unlock() }
        if let index = accounts.firstIndex(where: { $0.id == accountID }) {
            accounts[index].isArchived = isArchived
        }
    }
    
    public func calculateNetWorth() async throws -> Decimal {
        lock.lock()
        defer { lock.unlock() }
        return accounts
            .filter { !$0.isArchived }
            .reduce(Decimal.zero) { sum, acc in
                sum + acc.balance
            }
    }
    
    public static func defaultSampleAccounts() -> [AccountDTO] {
        [
            AccountDTO(
                id: "acc_hdfc_bank",
                name: "HDFC Salary Account",
                type: .bank,
                currencyCode: "INR",
                balance: Decimal(142500),
                icon: "building.columns.fill",
                colorToken: "blue",
                lastFour: "4321"
            ),
            AccountDTO(
                id: "acc_hdfc_cc",
                name: "HDFC Regalia Gold",
                type: .creditCard,
                currencyCode: "INR",
                balance: Decimal(-12450),
                icon: "creditcard.fill",
                colorToken: "purple",
                lastFour: "9876"
            ),
            AccountDTO(
                id: "acc_cash_wallet",
                name: "Physical Wallet",
                type: .cash,
                currencyCode: "INR",
                balance: Decimal(3200),
                icon: "banknote.fill",
                colorToken: "green"
            )
        ]
    }
}
