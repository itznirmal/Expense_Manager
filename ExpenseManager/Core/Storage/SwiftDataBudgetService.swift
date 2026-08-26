//
//  SwiftDataBudgetService.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  SwiftData Implementation of BudgetServiceProtocol.
//

import Foundation
import SwiftData

/// SwiftData persistent implementation of the Budget Tracking & Pace Service.
@MainActor
public final class SwiftDataBudgetService: BudgetServiceProtocol, Sendable {
    
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }
    
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    // MARK: - BudgetServiceProtocol
    
    public func fetchBudgets(for month: Date) async throws -> [BudgetDTO] {
        let calendar = Calendar.current
        let startOfMonth = DateFormatterHelper.shared.startOfMonth(for: month, calendar: calendar)
        let endOfMonth = DateFormatterHelper.shared.endOfMonth(for: month, calendar: calendar)
        
        let budgetDescriptor = FetchDescriptor<BudgetRecord>()
        let budgetRecords = try modelContext.fetch(budgetDescriptor)
        
        let txDescriptor = FetchDescriptor<TransactionRecord>()
        let transactions = try modelContext.fetch(txDescriptor)
        
        let monthTransactions = transactions.filter { tx in
            tx.transactionDate >= startOfMonth && tx.transactionDate <= endOfMonth && tx.transactionType == .expense
        }
        
        let categoryDescriptor = FetchDescriptor<CategoryRecord>()
        let categories = try modelContext.fetch(categoryDescriptor)
        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        
        return budgetRecords
            .filter { calendar.isDate($0.month, equalTo: month, toGranularity: .month) }
            .map { record in
                let spent: Decimal
                let categoryName: String?
                
                if let catID = record.categoryID {
                    spent = monthTransactions
                        .filter { $0.category?.id == catID || $0.category?.name == catID }
                        .reduce(Decimal.zero) { $0 + $1.amount }
                    categoryName = categoryMap[catID] ?? catID
                } else {
                    spent = monthTransactions.reduce(Decimal.zero) { $0 + $1.amount }
                    categoryName = "Overall Monthly Budget"
                }
                
                return BudgetDTO(
                    id: record.id,
                    categoryID: record.categoryID,
                    categoryName: categoryName,
                    limitAmount: record.limitAmount,
                    spentAmount: spent,
                    month: record.month,
                    alertThresholdPercent: record.alertThresholdPercent
                )
            }
    }
    
    @discardableResult
    public func setBudget(
        categoryID: String?,
        limitAmount: Decimal,
        month: Date,
        alertThresholdPercent: Int
    ) async throws -> String {
        let calendar = Calendar.current
        let descriptor = FetchDescriptor<BudgetRecord>()
        let existingBudgets = try modelContext.fetch(descriptor)
        
        if let existing = existingBudgets.first(where: {
            $0.categoryID == categoryID && calendar.isDate($0.month, equalTo: month, toGranularity: .month)
        }) {
            existing.limitAmount = limitAmount
            existing.alertThresholdPercent = alertThresholdPercent
            existing.updatedAt = Date()
            try modelContext.save()
            return existing.id
        } else {
            let record = BudgetRecord(
                id: UUID().uuidString,
                categoryID: categoryID,
                limitAmount: limitAmount,
                month: month,
                alertThresholdPercent: alertThresholdPercent,
                createdAt: Date(),
                updatedAt: Date()
            )
            modelContext.insert(record)
            try modelContext.save()
            return record.id
        }
    }
    
    public func calculateBudgetPace(categoryID: String?, month: Date) async throws -> Decimal {
        let budgets = try await fetchBudgets(for: month)
        guard let budget = budgets.first(where: { $0.categoryID == categoryID }) else {
            return .zero
        }
        
        let calendar = Calendar.current
        let now = Date()
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return .zero }
        let totalDays = range.count
        
        let dayOfMonth: Int
        if calendar.isDate(now, equalTo: month, toGranularity: .month) {
            dayOfMonth = calendar.component(.day, from: now)
        } else if now > month {
            dayOfMonth = totalDays
        } else {
            dayOfMonth = 1
        }
        
        guard totalDays > 0 else { return .zero }
        let expectedSpend = (budget.limitAmount / Decimal(totalDays)) * Decimal(dayOfMonth)
        return budget.spentAmount - expectedSpend
    }
}
