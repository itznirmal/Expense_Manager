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
    /// ISO 4217 code for the budget's ledger. This is persisted independently
    /// from the user's current display-currency preference.
    public var currencyCode: String
    public var limitAmount: Decimal
    /// Gross posted expenses before refunds for this budget scope.
    public var grossExpenseAmount: Decimal
    /// Posted refunds attributed to this budget scope.
    public var refundAmount: Decimal
    /// Net spending is exposed through `spentAmount` for existing callers.
    public var spentAmount: Decimal
    public var month: Date
    public var alertThresholdPercent: Int // e.g., 80 for 80%
    
    public init(
        id: String = UUID().uuidString,
        categoryID: String? = nil,
        categoryName: String? = nil,
        currencyCode: String = "INR",
        limitAmount: Decimal,
        spentAmount: Decimal = .zero,
        grossExpenseAmount: Decimal? = nil,
        refundAmount: Decimal = .zero,
        month: Date = Date(),
        alertThresholdPercent: Int = 80
    ) {
        self.id = id
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.currencyCode = currencyCode
        self.limitAmount = limitAmount
        self.grossExpenseAmount = grossExpenseAmount ?? (spentAmount + refundAmount)
        self.refundAmount = refundAmount
        self.spentAmount = spentAmount
        self.month = month
        self.alertThresholdPercent = alertThresholdPercent
    }
    
    public var remainingAmount: Decimal {
        limitAmount - spentAmount
    }

    public var netSpentAmount: Decimal { spentAmount }

    public var spentLabel: String {
        refundAmount > .zero ? "Net spending" : "Spent"
    }
    
    public var progressPercent: Double {
        guard limitAmount > 0 else { return 0 }
        let ratio = spentAmount / limitAmount
        let ratioDouble = NSDecimalNumber(decimal: ratio).doubleValue
        return min(1.0, max(0.0, ratioDouble))
    }
    
    public var isExceeded: Bool {
        spentAmount > limitAmount
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case categoryID
        case categoryName
        case currencyCode
        case limitAmount
        case grossExpenseAmount
        case refundAmount
        case spentAmount
        case month
        case alertThresholdPercent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        categoryID = try container.decodeIfPresent(String.self, forKey: .categoryID)
        categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
        currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode) ?? "INR"
        limitAmount = try container.decode(Decimal.self, forKey: .limitAmount)
        spentAmount = try container.decodeIfPresent(Decimal.self, forKey: .spentAmount) ?? .zero
        refundAmount = try container.decodeIfPresent(Decimal.self, forKey: .refundAmount) ?? .zero
        grossExpenseAmount = try container.decodeIfPresent(Decimal.self, forKey: .grossExpenseAmount) ?? (spentAmount + refundAmount)
        month = try container.decode(Date.self, forKey: .month)
        alertThresholdPercent = try container.decodeIfPresent(Int.self, forKey: .alertThresholdPercent) ?? 80
    }
}
