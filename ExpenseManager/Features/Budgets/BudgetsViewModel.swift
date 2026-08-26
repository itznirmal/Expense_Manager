//
//  BudgetsViewModel.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Observable ViewModel for Budget Engine, Projections & Daily Allowances.
//

import SwiftUI
import Observation

@Observable
@MainActor
public final class BudgetsViewModel {
    
    // MARK: - State Properties
    
    public var budgets: [BudgetDTO] = []
    public var selectedMonth: Date = Date()
    public var isLoading: Bool = false
    public var errorMessage: String? = nil
    
    public var selectedBudgetForEdit: BudgetDTO? = nil
    public var isComposerPresented: Bool = false
    
    // MARK: - Computed Properties
    
    public var overallBudget: BudgetDTO? {
        budgets.first(where: { $0.categoryID == nil })
    }
    
    public var categoryBudgets: [BudgetDTO] {
        budgets.filter { $0.categoryID != nil }
    }
    
    public var totalLimit: Decimal {
        if let overall = overallBudget {
            return overall.limitAmount
        }
        return categoryBudgets.reduce(Decimal.zero) { $0 + $1.limitAmount }
    }
    
    public var totalSpent: Decimal {
        if let overall = overallBudget {
            return overall.spentAmount
        }
        return categoryBudgets.reduce(Decimal.zero) { $0 + $1.spentAmount }
    }
    
    public var remainingTotalBudget: Decimal {
        max(Decimal.zero, totalLimit - totalSpent)
    }
    
    public var overallProgressPercent: Double {
        guard totalLimit > .zero else { return 0 }
        let spent = NSDecimalNumber(decimal: totalSpent).doubleValue
        let limit = NSDecimalNumber(decimal: totalLimit).doubleValue
        return min(1.0, max(0.0, spent / limit))
    }
    
    // MARK: - Month Pace Calculations
    
    /// Returns the percentage of the current month that has elapsed (e.g. Day 18 of 30 = 60.0%).
    public var monthPacePercent: Double {
        let calendar = Calendar.current
        let now = Date()
        guard let range = calendar.range(of: .day, in: .month, for: selectedMonth) else { return 1.0 }
        let totalDays = Double(range.count)
        guard totalDays > 0 else { return 1.0 }
        
        if calendar.isDate(now, equalTo: selectedMonth, toGranularity: .month) {
            let day = Double(calendar.component(.day, from: now))
            return min(1.0, max(0.0, day / totalDays))
        } else if now > selectedMonth {
            return 1.0
        } else {
            return 0.0
        }
    }
    
    /// Projected end-of-month spending based on current burn rate: (spentSoFar / dayOfMonth) * daysInMonth.
    public var projectedMonthSpend: Decimal {
        let calendar = Calendar.current
        let now = Date()
        guard let range = calendar.range(of: .day, in: .month, for: selectedMonth) else { return totalSpent }
        let totalDays = range.count
        guard totalDays > 0 else { return totalSpent }
        
        let dayOfMonth: Int
        if calendar.isDate(now, equalTo: selectedMonth, toGranularity: .month) {
            dayOfMonth = max(1, calendar.component(.day, from: now))
        } else if now > selectedMonth {
            dayOfMonth = totalDays
        } else {
            dayOfMonth = 1
        }
        
        let dailyBurn = totalSpent / Decimal(dayOfMonth)
        return dailyBurn * Decimal(totalDays)
    }
    
    /// Number of days remaining in the selected month.
    public var remainingDaysInMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let range = calendar.range(of: .day, in: .month, for: selectedMonth) else { return 0 }
        let totalDays = range.count
        
        if calendar.isDate(now, equalTo: selectedMonth, toGranularity: .month) {
            let currentDay = calendar.component(.day, from: now)
            return max(1, totalDays - currentDay + 1)
        } else if now > selectedMonth {
            return 0
        } else {
            return totalDays
        }
    }
    
    /// Daily budget allowance for the remaining days of the month: remainingBudget / remainingDays.
    public var dailyAllowance: Decimal {
        let days = remainingDaysInMonth
        guard days > 0, remainingTotalBudget > .zero else { return .zero }
        return remainingTotalBudget / Decimal(days)
    }
    
    /// Budgets that are exceeding or pacing significantly faster than month elapsed percentage.
    public var atRiskBudgets: [BudgetDTO] {
        let pace = monthPacePercent
        return budgets.filter { budget in
            guard budget.limitAmount > .zero else { return false }
            if budget.isExceeded { return true }
            // If spend % exceeds elapsed month % by > 15%, mark as at-risk
            return (budget.progressPercent - pace) > 0.15
        }
    }
    
    public init() {}
    
    // MARK: - Actions
    
    public func loadBudgets(container: DependencyContainer) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            budgets = try await container.budgetService.fetchBudgets(for: selectedMonth)
        } catch {
            errorMessage = "Failed to load budgets: \(error.localizedDescription)"
        }
    }
    
    public func selectPreviousMonth(container: DependencyContainer) async {
        if let prev = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = prev
            await loadBudgets(container: container)
        }
    }
    
    public func selectNextMonth(container: DependencyContainer) async {
        if let next = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = next
            await loadBudgets(container: container)
        }
    }
    
    public func saveBudget(
        categoryID: String?,
        limitAmount: Decimal,
        threshold: Int,
        container: DependencyContainer
    ) async -> Bool {
        guard limitAmount > .zero else {
            errorMessage = "Budget limit must be greater than zero."
            return false
        }
        
        do {
            try await container.budgetService.setBudget(
                categoryID: categoryID,
                limitAmount: limitAmount,
                month: selectedMonth,
                alertThresholdPercent: threshold
            )
            await loadBudgets(container: container)
            return true
        } catch {
            errorMessage = "Failed to save budget: \(error.localizedDescription)"
            return false
        }
    }
}
