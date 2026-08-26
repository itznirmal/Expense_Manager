//
//  AnalyticsViewModel.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Observable ViewModel for Time-Series Financial Analytics & Chart Visualizations.
//

import SwiftUI
import Observation

/// Time horizon intervals for analytics aggregation.
public enum AnalyticsTimeHorizon: String, CaseIterable, Identifiable, Sendable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .oneMonth: return "1 Month"
        case .threeMonths: return "3 Months"
        case .sixMonths: return "6 Months"
        case .oneYear: return "1 Year"
        }
    }
    
    public var monthsCount: Int {
        switch self {
        case .oneMonth: return 1
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .oneYear: return 12
        }
    }
}

/// Monthly cash flow entry for time-series charts.
public struct MonthlyCashFlowItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let monthDate: Date
    public let monthLabel: String
    public let income: Decimal
    public let expense: Decimal
    
    public var incomeDouble: Double { NSDecimalNumber(decimal: income).doubleValue }
    public var expenseDouble: Double { NSDecimalNumber(decimal: expense).doubleValue }
    public var netSavings: Decimal { income - expense }
}

/// Category spending breakdown entry for donut/pie charts.
public struct CategorySpendingItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let categoryName: String
    public let totalAmount: Decimal
    public let percentage: Double
    public let colorToken: String
    public let icon: String
    
    public var totalAmountDouble: Double { NSDecimalNumber(decimal: totalAmount).doubleValue }
}

/// Daily expense time-series point with moving average.
public struct DailySpendItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let date: Date
    public let dayLabel: String
    public let amount: Decimal
    public let movingAverage: Decimal
    
    public var amountDouble: Double { NSDecimalNumber(decimal: amount).doubleValue }
    public var movingAverageDouble: Double { NSDecimalNumber(decimal: movingAverage).doubleValue }
}

/// Top merchant spending aggregate.
public struct TopMerchantItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let merchantName: String
    public let totalAmount: Decimal
    public let transactionCount: Int
    public let categorySuggestion: String?
}

@Observable
@MainActor
public final class AnalyticsViewModel {
    
    // MARK: - State Properties
    
    public var selectedHorizon: AnalyticsTimeHorizon = .oneMonth
    public var totalIncome: Decimal = .zero
    public var totalExpense: Decimal = .zero
    public var monthlyCashFlows: [MonthlyCashFlowItem] = []
    public var categoryBreakdowns: [CategorySpendingItem] = []
    public var dailySpendingTrend: [DailySpendItem] = []
    public var topMerchants: [TopMerchantItem] = []
    
    public var isLoading: Bool = false
    public var errorMessage: String? = nil
    
    // MARK: - Computed Properties
    
    public var netSavings: Decimal {
        totalIncome - totalExpense
    }
    
    public var savingsRate: Double {
        guard totalIncome > .zero else { return 0.0 }
        let inc = NSDecimalNumber(decimal: totalIncome).doubleValue
        let exp = NSDecimalNumber(decimal: totalExpense).doubleValue
        return max(-100.0, min(100.0, ((inc - exp) / inc) * 100.0))
    }
    
    public var averageDailyExpense: Decimal {
        guard !dailySpendingTrend.isEmpty else { return .zero }
        let total = dailySpendingTrend.reduce(Decimal.zero) { $0 + $1.amount }
        return total / Decimal(dailySpendingTrend.count)
    }
    
    public init() {}
    
    // MARK: - Aggregation & Computation
    
    public func loadAnalytics(container: DependencyContainer) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate date range based on selected time horizon
        let months = selectedHorizon.monthsCount
        guard let startDateRaw = calendar.date(byAdding: .month, value: -(months - 1), to: now) else { return }
        let startDate = DateFormatterHelper.shared.startOfMonth(for: startDateRaw, calendar: calendar)
        let endDate = DateFormatterHelper.shared.endOfMonth(for: now, calendar: calendar)
        
        do {
            let transactions = try await container.transactionService.fetchTransactions(
                startDate: startDate,
                endDate: endDate,
                categoryID: nil,
                accountID: nil
            )
            
            // 1. Calculate Summary Totals
            var inc: Decimal = .zero
            var exp: Decimal = .zero
            for tx in transactions {
                switch tx.type {
                case .income, .refund:
                    inc += tx.amount
                case .expense:
                    exp += tx.amount
                case .transfer, .cashWithdrawal, .unknown:
                    break
                }
            }
            self.totalIncome = inc
            self.totalExpense = exp
            
            // 2. Monthly Cash Flow Time Series
            var cashFlowMap: [String: (date: Date, label: String, inc: Decimal, exp: Decimal)] = [:]
            for m in 0..<months {
                if let mDate = calendar.date(byAdding: .month, value: -m, to: now) {
                    let key = DateFormatterHelper.shared.monthYear(for: mDate)
                    let monthStart = DateFormatterHelper.shared.startOfMonth(for: mDate, calendar: calendar)
                    let label = calendar.shortMonthSymbols[calendar.component(.month, from: mDate) - 1]
                    cashFlowMap[key] = (monthStart, label, .zero, .zero)
                }
            }
            
            for tx in transactions {
                let key = DateFormatterHelper.shared.monthYear(for: tx.transactionDate)
                if var existing = cashFlowMap[key] {
                    if tx.type == .income || tx.type == .refund {
                        existing.inc += tx.amount
                    } else if tx.type == .expense {
                        existing.exp += tx.amount
                    }
                    cashFlowMap[key] = existing
                }
            }
            
            self.monthlyCashFlows = cashFlowMap.values
                .sorted(by: { $0.date < $1.date })
                .map { MonthlyCashFlowItem(id: $0.label, monthDate: $0.date, monthLabel: $0.label, income: $0.inc, expense: $0.exp) }
            
            // 3. Category Spending Breakdown
            let expenseTransactions = transactions.filter { $0.type == .expense && $0.amount > .zero }
            let categoryGrouped = Dictionary(grouping: expenseTransactions) { tx in
                tx.categorySuggestion ?? "General"
            }
            
            var breakdowns: [CategorySpendingItem] = []
            for (catName, txList) in categoryGrouped {
                let catTotal = txList.reduce(Decimal.zero) { $0 + $1.amount }
                let pct = exp > .zero ? (NSDecimalNumber(decimal: catTotal).doubleValue / NSDecimalNumber(decimal: exp).doubleValue) : 0.0
                
                breakdowns.append(
                    CategorySpendingItem(
                        id: catName,
                        categoryName: catName,
                        totalAmount: catTotal,
                        percentage: pct,
                        colorToken: Self.colorToken(for: catName),
                        icon: Self.icon(for: catName)
                    )
                )
            }
            self.categoryBreakdowns = breakdowns.sorted(by: { $0.totalAmount > $1.totalAmount })
            
            // 4. Daily Spending Trend (Last 14-30 days)
            let trendDays = min(30, max(14, months * 10))
            var dailyMap: [Date: Decimal] = [:]
            for d in 0..<trendDays {
                if let dDate = calendar.date(byAdding: .day, value: -d, to: now) {
                    let start = calendar.startOfDay(for: dDate)
                    dailyMap[start] = .zero
                }
            }
            
            for tx in expenseTransactions {
                let start = calendar.startOfDay(for: tx.transactionDate)
                if dailyMap[start] != nil {
                    dailyMap[start] = (dailyMap[start] ?? .zero) + tx.amount
                }
            }
            
            let sortedDaily = dailyMap.sorted(by: { $0.key < $1.key })
            var trendItems: [DailySpendItem] = []
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "d MMM"
            
            for i in 0..<sortedDaily.count {
                let (date, amt) = sortedDaily[i]
                // 7-day moving average
                let windowStart = max(0, i - 6)
                let windowSlice = sortedDaily[windowStart...i].map(\.value)
                let movingAvg = windowSlice.reduce(Decimal.zero, +) / Decimal(windowSlice.count)
                
                trendItems.append(
                    DailySpendItem(
                        id: date.ISO8601Format(),
                        date: date,
                        dayLabel: dayFormatter.string(from: date),
                        amount: amt,
                        movingAverage: movingAvg
                    )
                )
            }
            self.dailySpendingTrend = trendItems
            
            // 5. Top 5 Merchants
            let merchantGrouped = Dictionary(grouping: expenseTransactions) { tx in
                tx.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            var merchants: [TopMerchantItem] = []
            for (mName, txList) in merchantGrouped where !mName.isEmpty {
                let mTotal = txList.reduce(Decimal.zero) { $0 + $1.amount }
                merchants.append(
                    TopMerchantItem(
                        id: mName,
                        merchantName: mName,
                        totalAmount: mTotal,
                        transactionCount: txList.count,
                        categorySuggestion: txList.first?.categorySuggestion
                    )
                )
            }
            self.topMerchants = Array(merchants.sorted(by: { $0.totalAmount > $1.totalAmount }).prefix(5))
            
        } catch {
            errorMessage = "Failed to load analytics: \(error.localizedDescription)"
        }
    }
    
    public func setTimeHorizon(_ horizon: AnalyticsTimeHorizon, container: DependencyContainer) async {
        self.selectedHorizon = horizon
        await loadAnalytics(container: container)
    }
    
    // MARK: - Private Palette Helpers
    
    private static func colorToken(for category: String) -> String {
        let lower = category.lowercased()
        if lower.contains("food") || lower.contains("dining") || lower.contains("coffee") { return "orange" }
        if lower.contains("grocer") { return "green" }
        if lower.contains("transport") || lower.contains("fuel") || lower.contains("uber") { return "blue" }
        if lower.contains("shop") { return "purple" }
        if lower.contains("bill") || lower.contains("util") { return "yellow" }
        if lower.contains("entertain") || lower.contains("movie") { return "pink" }
        if lower.contains("health") || lower.contains("med") { return "red" }
        if lower.contains("invest") { return "teal" }
        if lower.contains("salary") { return "green" }
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
