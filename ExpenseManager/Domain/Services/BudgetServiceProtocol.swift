//
//  BudgetServiceProtocol.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Budget Limit and Tracking Service Protocol.
//

import Foundation

/// Service protocol defining budget limits and pace evaluation.
public protocol BudgetServiceProtocol: Sendable {
    
    /// Fetches all active budgets configured for a specific month.
    func fetchBudgets(for month: Date) async throws -> [BudgetDTO]
    
    /// Sets or updates a budget limit for a category or global overall budget.
    func setBudget(
        categoryID: String?,
        limitAmount: Decimal,
        month: Date,
        alertThresholdPercent: Int
    ) async throws -> String
    
    /// Calculates the projected spending pace for the given category in the month.
    func calculateBudgetPace(categoryID: String?, month: Date) async throws -> Decimal
}
