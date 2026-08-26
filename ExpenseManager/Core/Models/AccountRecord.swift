//
//  AccountRecord.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  SwiftData Canonical Account Entity.
//

import Foundation
import SwiftData

/// Canonical persistent account entity stored in SwiftData.
@Model
public final class AccountRecord {
    @Attribute(.unique) public var id: String
    public var name: String
    public var type: String
    public var currencyCode: String
    public var openingBalance: Decimal
    public var currentBalance: Decimal
    public var icon: String
    public var colorToken: String
    public var lastFour: String?
    public var isArchived: Bool
    public var createdAt: Date
    
    @Relationship(deleteRule: .nullify, inverse: \TransactionRecord.account)
    public var transactions: [TransactionRecord]?
    
    @Relationship(deleteRule: .nullify, inverse: \TransactionRecord.destinationAccount)
    public var destinationTransactions: [TransactionRecord]?
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        type: AccountType = .bank,
        currencyCode: String = CurrencyFormatter.defaultCurrencyCode,
        openingBalance: Decimal = .zero,
        currentBalance: Decimal = .zero,
        icon: String = "building.columns.fill",
        colorToken: String = "blue",
        lastFour: String? = nil,
        isArchived: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type.rawValue
        self.currencyCode = currencyCode
        self.openingBalance = openingBalance
        self.currentBalance = currentBalance
        self.icon = icon
        self.colorToken = colorToken
        self.lastFour = lastFour
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.transactions = []
        self.destinationTransactions = []
    }
    
    // MARK: - Computed Properties for Enums
    
    public var accountType: AccountType {
        get { AccountType(rawValue: type) ?? .bank }
        set { type = newValue.rawValue }
    }
    
    // MARK: - DTO Conversion
    
    public func toDTO() -> AccountDTO {
        AccountDTO(
            id: id,
            name: name,
            type: accountType,
            currencyCode: currencyCode,
            balance: currentBalance,
            icon: icon,
            colorToken: colorToken,
            lastFour: lastFour,
            isArchived: isArchived,
            createdAt: createdAt
        )
    }
}
