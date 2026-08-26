//
//  AccountDTO.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Domain Layer Account Data Transfer Object.
//

import Foundation

/// Domain representation of a financial account.
public struct AccountDTO: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var name: String
    public var type: AccountType
    public var currencyCode: String
    public var balance: Decimal
    public var icon: String
    public var colorToken: String
    public var lastFour: String?
    public var isArchived: Bool
    public var createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        type: AccountType,
        currencyCode: String = CurrencyFormatter.defaultCurrencyCode,
        balance: Decimal = .zero,
        icon: String = "building.columns.fill",
        colorToken: String = "blue",
        lastFour: String? = nil,
        isArchived: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.currencyCode = currencyCode
        self.balance = balance
        self.icon = icon
        self.colorToken = colorToken
        self.lastFour = lastFour
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}
