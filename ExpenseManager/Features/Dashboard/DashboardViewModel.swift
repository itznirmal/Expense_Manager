//
//  DashboardViewModel.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Observable ViewModel for Glanceable Financial Dashboard.
//

import SwiftUI
import Observation

public struct CurrencyBalanceDTO: Identifiable, Sendable, Equatable {
    public var id: String { currencyCode }
    public let currencyCode: String
    public let netBalance: Decimal
}

public struct DashboardCategorySpending: Identifiable, Sendable, Equatable {
    public let id: String
    public let category: String
    public let amount: Decimal
    public let percentage: Double
    public let colorToken: String
    public let icon: String
}

@Observable
@MainActor
public final class DashboardViewModel {
    
    // MARK: - Financial Summary Metrics
    
    public var netWorth: Decimal = .zero
    public var totalAssets: Decimal = .zero
    public var totalLiabilities: Decimal = .zero
    
    public var monthlyIncome: Decimal = .zero
    public var monthlyExpense: Decimal = .zero
    
    public var overallBudgetLimit: Decimal = .zero
    public var overallBudgetSpent: Decimal = .zero
    public var monthPacePercent: Double = 0.0
    
    public var otherCurrencyBalances: [CurrencyBalanceDTO] = []
    
    public var topCategories: [DashboardCategorySpending] = []
    public var recentTransactions: [TransactionCandidate] = []
    public var recurringSubscriptions: [RecurringSubscription] = []
    public var anomalousAlerts: [AnomalousTransactionAlert] = []
    
    public var selectedDetailTransaction: TransactionCandidate? = nil
    public var selectedEditTransaction: TransactionCandidate? = nil
    
    public var isLoading: Bool = false
    public var errorMessage: String? = nil
    
    // MARK: - Computed Properties
    
    public var netSavings: Decimal {
        monthlyIncome - monthlyExpense
    }
    
    public var savingsRate: Double {
        guard monthlyIncome > .zero else { return 0.0 }
        let inc = NSDecimalNumber(decimal: monthlyIncome).doubleValue
        let exp = NSDecimalNumber(decimal: monthlyExpense).doubleValue
        return max(-100.0, min(100.0, ((inc - exp) / inc) * 100.0))
    }
    
    public var budgetProgressPercent: Double {
        guard overallBudgetLimit > .zero else { return 0.0 }
        let spent = NSDecimalNumber(decimal: overallBudgetSpent).doubleValue
        let limit = NSDecimalNumber(decimal: overallBudgetLimit).doubleValue
        return min(1.0, max(0.0, spent / limit))
    }
    
    public init() {}
    
    // MARK: - Data Ingestion & Computation
    
    public func loadDashboardData(container: DependencyContainer, appState: AppState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = DateFormatterHelper.shared.startOfMonth(for: now, calendar: calendar)
        let endOfMonth = DateFormatterHelper.shared.endOfMonth(for: now, calendar: calendar)
        
        do {
            async let fetchedAccounts = container.accountService.fetchAccounts(includeArchived: false)
            async let fetchedRecent = container.transactionService.fetchRecentTransactions(limit: 6)
            async let fetchedMonthTx = container.transactionService.fetchTransactions(startDate: startOfMonth, endDate: endOfMonth, categoryID: nil, accountID: nil)
            async let fetchedBudgets = container.budgetService.fetchBudgets(for: now)
            
            let (accounts, recents, monthTransactions, budgets) = try await (fetchedAccounts, fetchedRecent, fetchedMonthTx, fetchedBudgets)
            let baseCurrency = CurrencyFormatter.defaultCurrencyCode
            
            // 1. Account Assets & Liabilities (Base Currency)
            var assets: Decimal = .zero
            var liabilities: Decimal = .zero
            for acc in accounts where acc.currencyCode == baseCurrency {
                if acc.type == .creditCard {
                    if acc.balance < .zero {
                        liabilities += abs(acc.balance)
                    }
                } else {
                    if acc.balance > .zero {
                        assets += acc.balance
                    } else if acc.balance < .zero {
                        liabilities += abs(acc.balance)
                    }
                }
            }
            self.totalAssets = assets
            self.totalLiabilities = liabilities
            self.netWorth = assets - liabilities
            
            // 1.1 Non-Base Multi-Currency Balances (Separated without conversion)
            let otherCurrencies = Set(accounts.map(\.currencyCode)).filter { $0 != baseCurrency }.sorted()
            var otherBalances: [CurrencyBalanceDTO] = []
            for cur in otherCurrencies {
                let curAccounts = accounts.filter { $0.currencyCode == cur }
                let netCur = curAccounts.reduce(Decimal.zero) { $0 + $1.balance }
                otherBalances.append(CurrencyBalanceDTO(currencyCode: cur, netBalance: netCur))
            }
            self.otherCurrencyBalances = otherBalances
            
            // 2. Cash Flow Totals
            var inc: Decimal = .zero
            var exp: Decimal = .zero
            for tx in monthTransactions where tx.currencyCode == baseCurrency {
                switch tx.type {
                case .income, .refund:
                    inc += tx.amount
                case .expense:
                    exp += tx.amount
                case .transfer, .cashWithdrawal, .unknown:
                    break
                }
            }
            self.monthlyIncome = inc
            self.monthlyExpense = exp
            
            // 3. Budgets & Pace
            if let overall = budgets.first(where: { $0.categoryID == nil }) {
                self.overallBudgetLimit = overall.limitAmount
                self.overallBudgetSpent = overall.spentAmount
            } else if !budgets.isEmpty {
                self.overallBudgetLimit = budgets.reduce(Decimal.zero) { $0 + $1.limitAmount }
                self.overallBudgetSpent = budgets.reduce(Decimal.zero) { $0 + $1.spentAmount }
            } else {
                self.overallBudgetLimit = .zero
                self.overallBudgetSpent = exp
            }
            
            if let range = calendar.range(of: .day, in: .month, for: now), range.count > 0 {
                let day = Double(calendar.component(.day, from: now))
                self.monthPacePercent = min(1.0, max(0.0, day / Double(range.count)))
            }
            
            // 4. Top Spending Categories
            let expenseTx = monthTransactions.filter { $0.type == .expense && $0.amount > .zero }
            let grouped = Dictionary(grouping: expenseTx) { tx in
                tx.categorySuggestion ?? "General"
            }
            
            var catList: [DashboardCategorySpending] = []
            for (catName, items) in grouped {
                let catTotal = items.reduce(Decimal.zero) { $0 + $1.amount }
                let pct = exp > .zero ? (NSDecimalNumber(decimal: catTotal).doubleValue / NSDecimalNumber(decimal: exp).doubleValue) : 0.0
                catList.append(
                    DashboardCategorySpending(
                        id: catName,
                        category: catName,
                        amount: catTotal,
                        percentage: pct,
                        colorToken: Self.colorToken(for: catName),
                        icon: Self.icon(for: catName)
                    )
                )
            }
            self.topCategories = Array(catList.sorted(by: { $0.amount > $1.amount }).prefix(5))
            
            // 5. Recent Transactions
            self.recentTransactions = recents
            
            // 6. Merchant Intelligence: Subscriptions & Anomalies
            let allExpenses = try await container.transactionService.fetchTransactions(startDate: nil, endDate: nil, categoryID: nil, accountID: nil)
            self.recurringSubscriptions = container.merchantIntelligenceService.detectRecurringSubscriptions(from: allExpenses)
            self.anomalousAlerts = container.merchantIntelligenceService.identifyAnomalies(in: allExpenses, historicalDays: 90)
            
        } catch {
            errorMessage = "Failed to load dashboard data: \(error.localizedDescription)"
        }
    }
    
    public func deleteTransaction(id: String, container: DependencyContainer, appState: AppState) async {
        do {
            try await container.transactionService.deleteTransaction(id: id)
            recentTransactions.removeAll { $0.id.uuidString == id }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            appState.showToast(title: "Transaction Deleted", type: .info)
            await loadDashboardData(container: container, appState: appState)
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Private Styling Helpers
    
    private static func colorToken(for category: String) -> String {
        let lower = category.lowercased()
        if lower.contains("food") || lower.contains("dining") || lower.contains("coffee") { return "orange" }
        if lower.contains("grocer") { return "green" }
        if lower.contains("transport") || lower.contains("fuel") { return "blue" }
        if lower.contains("shop") { return "purple" }
        if lower.contains("bill") { return "yellow" }
        if lower.contains("entertain") { return "pink" }
        if lower.contains("health") { return "red" }
        if lower.contains("invest") { return "teal" }
        return "indigo"
    }
    
    private static func icon(for category: String) -> String {
        let lower = category.lowercased()
        if lower.contains("food") || lower.contains("dining") { return "fork.knife" }
        if lower.contains("grocer") { return "cart.fill" }
        if lower.contains("transport") || lower.contains("fuel") { return "car.fill" }
        if lower.contains("shop") { return "bag.fill" }
        if lower.contains("bill") { return "bolt.fill" }
        if lower.contains("entertain") { return "film.fill" }
        if lower.contains("health") { return "cross.fill" }
        return "tag.fill"
    }
}
