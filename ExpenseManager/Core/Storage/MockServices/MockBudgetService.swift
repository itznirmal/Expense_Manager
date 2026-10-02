//
//  MockBudgetService.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  In-Memory Mock Budget Service.
//

import Foundation

public final class MockBudgetService: BudgetServiceProtocol, @unchecked Sendable {
    private var budgets: [BudgetDTO] = []
    private let lock = NSLock()
    
    public init(sampleData: [BudgetDTO]? = nil) {
        if let sampleData = sampleData {
            self.budgets = sampleData
        } else {
            self.budgets = Self.defaultSampleBudgets()
        }
    }
    
    public func fetchBudgets(for month: Date, currencyCode: String?) async throws -> [BudgetDTO] {
        return lock.withLock {
            let calendar = Calendar.current
            return budgets.filter {
                calendar.isDate($0.month, equalTo: month, toGranularity: .month) &&
                (currencyCode == nil || $0.currencyCode == currencyCode)
            }
        }
    }
    
    public func setBudget(
        categoryID: String?,
        limitAmount: Decimal,
        month: Date,
        alertThresholdPercent: Int,
        currencyCode: String
    ) async throws -> String {
        try MoneyValidation.validate(amount: limitAmount, currencyCode: currencyCode)
        return lock.withLock {
            let calendar = Calendar.current
            if let index = budgets.firstIndex(where: {
                $0.categoryID == categoryID &&
                $0.currencyCode == currencyCode &&
                calendar.isDate($0.month, equalTo: month, toGranularity: .month)
            }) {
                budgets[index].limitAmount = limitAmount
                budgets[index].alertThresholdPercent = alertThresholdPercent
                return budgets[index].id
            } else {
                let newBudget = BudgetDTO(
                    id: UUID().uuidString,
                    categoryID: categoryID,
                    categoryName: categoryID == nil ? "Overall Monthly Budget" : "Category Budget",
                    currencyCode: currencyCode,
                    limitAmount: limitAmount,
                    spentAmount: .zero,
                    month: month,
                    alertThresholdPercent: alertThresholdPercent
                )
                budgets.append(newBudget)
                return newBudget.id
            }
        }
    }
    
    public func calculateBudgetPace(categoryID: String?, month: Date, currencyCode: String) async throws -> Decimal {
        return lock.withLock {
            let calendar = Calendar.current
            guard let budget = budgets.first(where: {
                $0.categoryID == categoryID &&
                $0.currencyCode == currencyCode &&
                calendar.isDate($0.month, equalTo: month, toGranularity: .month)
            }) else {
                return .zero
            }
            let dayOfMonth = calendar.component(.day, from: Date())
            guard let range = calendar.range(of: .day, in: .month, for: month) else { return .zero }
            let totalDays = range.count

            let expectedSpend = (budget.limitAmount / Decimal(totalDays)) * Decimal(dayOfMonth)
            return budget.spentAmount - expectedSpend
        }
    }
    
    public static func defaultSampleBudgets() -> [BudgetDTO] {
        [
            BudgetDTO(
                id: "b_overall",
                categoryID: nil,
                categoryName: "Overall Monthly Budget",
                currencyCode: "INR",
                limitAmount: Decimal(60000),
                spentAmount: Decimal(42500),
                month: Date(),
                alertThresholdPercent: 80
            ),
            BudgetDTO(
                id: "b_dining",
                categoryID: "cat_food",
                categoryName: "Food & Dining",
                currencyCode: "INR",
                limitAmount: Decimal(15000),
                spentAmount: Decimal(11200),
                month: Date(),
                alertThresholdPercent: 80
            ),
            BudgetDTO(
                id: "b_groceries",
                categoryID: "cat_groceries",
                categoryName: "Groceries",
                currencyCode: "INR",
                limitAmount: Decimal(12000),
                spentAmount: Decimal(7450),
                month: Date(),
                alertThresholdPercent: 80
            )
        ]
    }
}
