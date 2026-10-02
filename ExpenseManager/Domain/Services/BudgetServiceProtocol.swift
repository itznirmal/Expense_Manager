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
    
    /// Fetches active budgets for a month. Passing nil returns every stored
    /// currency so the caller can expose a visible currency selector.
    func fetchBudgets(for month: Date, currencyCode: String?) async throws -> [BudgetDTO]
    
    /// Sets or updates a budget limit for a category or global overall budget.
    func setBudget(
        categoryID: String?,
        limitAmount: Decimal,
        month: Date,
        alertThresholdPercent: Int,
        currencyCode: String
    ) async throws -> String
    
    /// Calculates the projected spending pace for the given category in the month.
    func calculateBudgetPace(categoryID: String?, month: Date, currencyCode: String) async throws -> Decimal
}

public extension BudgetServiceProtocol {
    /// Compatibility entry point for existing callers. It intentionally loads
    /// all currencies instead of silently narrowing the result to the current
    /// display preference.
    func fetchBudgets(for month: Date) async throws -> [BudgetDTO] {
        try await fetchBudgets(for: month, currencyCode: nil)
    }

    func setBudget(
        categoryID: String?,
        limitAmount: Decimal,
        month: Date,
        alertThresholdPercent: Int
    ) async throws -> String {
        try await setBudget(
            categoryID: categoryID,
            limitAmount: limitAmount,
            month: month,
            alertThresholdPercent: alertThresholdPercent,
            currencyCode: CurrencyFormatter.defaultCurrencyCode
        )
    }

    func calculateBudgetPace(categoryID: String?, month: Date) async throws -> Decimal {
        try await calculateBudgetPace(
            categoryID: categoryID,
            month: month,
            currencyCode: CurrencyFormatter.defaultCurrencyCode
        )
    }
}
