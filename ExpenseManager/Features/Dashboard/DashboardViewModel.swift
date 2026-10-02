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
    public let grossExpense: Decimal
    public let refundAmount: Decimal
    public let amount: Decimal
    public let percentage: Double
    public let colorToken: String
    public let icon: String

    public init(
        id: String,
        category: String,
        amount: Decimal,
        percentage: Double,
        colorToken: String,
        icon: String,
        grossExpense: Decimal? = nil,
        refundAmount: Decimal = .zero
    ) {
        self.id = id
        self.category = category
        self.grossExpense = grossExpense ?? (amount + refundAmount)
        self.refundAmount = refundAmount
        self.amount = amount
        self.percentage = percentage
        self.colorToken = colorToken
        self.icon = icon
    }

    public var netAmount: Decimal { amount }
    public var amountLabel: String { refundAmount > .zero ? "Net spending" : "Spending" }
}

@Observable
@MainActor
public final class DashboardViewModel {

    // MARK: - Financial Summary Metrics

    public var netWorth: Decimal = .zero
    public var totalAssets: Decimal = .zero
    public var totalLiabilities: Decimal = .zero

    public var monthlyIncome: Decimal = .zero
    public var grossMonthlyExpense: Decimal = .zero
    public var monthlyRefunds: Decimal = .zero
    public var monthlyExpense: Decimal = .zero
    public var selectedCurrencyCode: String = CurrencyFormatter.defaultCurrencyCode
    public var availableCurrencyCodes: [String] = []

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
        let savingsRatio = (monthlyIncome - monthlyExpense) / monthlyIncome
        let savingsRatioDouble = NSDecimalNumber(decimal: savingsRatio).doubleValue
        return max(-100.0, min(100.0, savingsRatioDouble * 100.0))
    }

    public var budgetProgressPercent: Double {
        guard overallBudgetLimit > .zero else { return 0.0 }
        let progressRatio = overallBudgetSpent / overallBudgetLimit
        let progressRatioDouble = NSDecimalNumber(decimal: progressRatio).doubleValue
        return min(1.0, max(0.0, progressRatioDouble))
    }

    public init() {}

    public var categoryBreakdown: [DashboardCategorySpending] { topCategories }

    public var monthlyExpenseLabel: String {
        monthlyRefunds > .zero ? "Net spending" : "Spending"
    }

    public var remainingBudget: Decimal {
        overallBudgetLimit - overallBudgetSpent
    }

    public func selectCurrency(
        _ currencyCode: String,
        container: DependencyContainer,
        appState: AppState
    ) async {
        guard availableCurrencyCodes.contains(currencyCode) else { return }
        appState.preferredCurrencyCode = currencyCode
        await loadDashboardData(container: container, appState: appState)
    }

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
            async let fetchedBudgets = container.budgetService.fetchBudgets(for: now, currencyCode: nil)

            let (accounts, recents, monthTransactions, budgets) = try await (fetchedAccounts, fetchedRecent, fetchedMonthTx, fetchedBudgets)
            let preferredCurrency = appState.preferredCurrencyCode
            let allCurrencies = Set(
                accounts.map(\.currencyCode) +
                monthTransactions.map(\.currencyCode) +
                budgets.map(\.currencyCode) +
                recents.map(\.currencyCode)
            )
            self.availableCurrencyCodes = Array(
                Set(CurrencyFormatter.supportedCurrencyCodes).union(allCurrencies)
            ).sorted()
            self.selectedCurrencyCode = preferredCurrency
            let baseCurrency = preferredCurrency
            let selectedMonthTransactions = monthTransactions.filter { $0.currencyCode == baseCurrency }

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
            var grossExp: Decimal = .zero
            var refunds: Decimal = .zero
            for tx in selectedMonthTransactions {
                switch tx.type {
                case .income:
                    inc += tx.amount
                case .refund:
                    refunds += tx.amount
                case .expense:
                    grossExp += tx.amount
                case .transfer, .cashWithdrawal, .unknown:
                    break
                }
            }
            self.monthlyIncome = inc
            self.grossMonthlyExpense = grossExp
            self.monthlyRefunds = refunds
            self.monthlyExpense = grossExp - refunds

            // 3. Budgets & Pace
            let selectedBudgets = budgets.filter { $0.currencyCode == baseCurrency }
            if let overall = selectedBudgets.first(where: { $0.categoryID == nil }) {
                self.overallBudgetLimit = overall.limitAmount
                self.overallBudgetSpent = overall.spentAmount
            } else if !selectedBudgets.isEmpty {
                self.overallBudgetLimit = selectedBudgets.reduce(Decimal.zero) { $0 + $1.limitAmount }
                self.overallBudgetSpent = selectedBudgets.reduce(Decimal.zero) { $0 + $1.spentAmount }
            } else {
                self.overallBudgetLimit = .zero
                self.overallBudgetSpent = .zero
            }

            if let range = calendar.range(of: .day, in: .month, for: now), range.count > 0 {
                let day = Double(calendar.component(.day, from: now))
                self.monthPacePercent = min(1.0, max(0.0, day / Double(range.count)))
            }

            // 4. Top Spending Categories, with refunds netted and labeled.
            let spendingTx = selectedMonthTransactions.filter {
                ($0.type == .expense || $0.type == .refund) && $0.amount > .zero
            }
            let grouped = Dictionary(grouping: spendingTx) { tx in
                tx.categorySuggestion ?? "General"
            }

            var catList: [DashboardCategorySpending] = []
            for (catName, items) in grouped {
                let catGross = items.filter { $0.type == .expense }.reduce(Decimal.zero) { $0 + $1.amount }
                let catRefunds = items.filter { $0.type == .refund }.reduce(Decimal.zero) { $0 + $1.amount }
                let catTotal = catGross - catRefunds
                let pct = self.monthlyExpense > .zero
                    ? NSDecimalNumber(decimal: catTotal / self.monthlyExpense).doubleValue
                    : 0.0
                catList.append(
                    DashboardCategorySpending(
                        id: catName,
                        category: catName,
                        amount: catTotal,
                        percentage: pct,
                        colorToken: Self.colorToken(for: catName),
                        icon: Self.icon(for: catName),
                        grossExpense: catGross,
                        refundAmount: catRefunds
                    )
                )
            }
            self.topCategories = Array(catList.sorted(by: { $0.amount > $1.amount }).prefix(5))

            // 5. Recent Transactions
            self.recentTransactions = recents.filter { $0.currencyCode == baseCurrency }

            // 6. Merchant Intelligence: Subscriptions & Anomalies
            let allFetchedExpenses = try await container.transactionService.fetchTransactions(
                startDate: nil,
                endDate: nil,
                categoryID: nil,
                accountID: nil
            )
            let allExpenses = allFetchedExpenses.filter { $0.currencyCode == baseCurrency }
            self.recurringSubscriptions = container.merchantIntelligenceService.detectRecurringSubscriptions(from: allExpenses)
            self.anomalousAlerts = container.merchantIntelligenceService.identifyAnomalies(in: allExpenses, historicalDays: 90)

            // 7. Review count + home-screen widget snapshot
            let pending = try await container.transactionService.fetchPendingReviewTransactions()
            appState.pendingReviewCount = pending.count

            let remainingDays = max(1, calendar.range(of: .day, in: .month, for: now).map { $0.count - calendar.component(.day, from: now) + 1 } ?? 1)
            let remainingBudget = max(.zero, overallBudgetLimit - overallBudgetSpent)
            let daily = remainingBudget / Decimal(remainingDays)
            WidgetSnapshotStore.save(WidgetFinanceSnapshot(
                monthExpense: self.monthlyExpense,
                monthIncome: inc,
                remainingBudget: remainingBudget,
                dailyAllowance: daily,
                currencyCode: baseCurrency,
                pendingReviewCount: pending.count,
                updatedAt: Date()
            ))

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
