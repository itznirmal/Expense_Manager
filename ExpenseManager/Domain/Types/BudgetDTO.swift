//
//  BudgetDTO.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Domain Layer Budget Limit Data Transfer Object.
//

import Foundation

/// Domain representation of a monthly category or global budget limit.
public struct BudgetDTO: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var categoryID: String? // nil represents an overall/global monthly budget
    public var categoryName: String?
    public var limitAmount: Decimal
    public var spentAmount: Decimal
    public var month: Date
    public var alertThresholdPercent: Int // e.g., 80 for 80%
    
    public init(
        id: String = UUID().uuidString,
        categoryID: String? = nil,
        categoryName: String? = nil,
        limitAmount: Decimal,
        spentAmount: Decimal = .zero,
        month: Date = Date(),
        alertThresholdPercent: Int = 80
    ) {
        self.id = id
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.limitAmount = limitAmount
        self.spentAmount = spentAmount
        self.month = month
        self.alertThresholdPercent = alertThresholdPercent
    }
    
    public var remainingAmount: Decimal {
        limitAmount - spentAmount
    }
    
    public var progressPercent: Double {
        guard limitAmount > 0 else { return 0 }
        let spent = NSDecimalNumber(decimal: spentAmount).doubleValue
        let limit = NSDecimalNumber(decimal: limitAmount).doubleValue
        return min(1.0, max(0.0, spent / limit))
    }
    
    public var isExceeded: Bool {
        spentAmount > limitAmount
    }
}
