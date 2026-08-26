//
//  CategoryType.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Category Classification Scope.
//

import Foundation

/// Defines whether a category applies to Expenses, Income, or Both.
public enum CategoryType: String, Codable, CaseIterable, Sendable {
    case expense
    case income
    case both
    
    public var displayName: String {
        switch self {
        case .expense: return "Expense"
        case .income: return "Income"
        case .both: return "Expense & Income"
        }
    }
}
