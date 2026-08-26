//
//  MerchantIntelligenceService.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Merchant Intelligence, Recurring Subscription Detection & Spending Insights.
//

import Foundation

/// Supported frequencies for recurring charges.
public enum SubscriptionFrequency: String, Sendable, Codable, CaseIterable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
}

/// Domain representation of a detected recurring merchant subscription or bill.
public struct RecurringSubscription: Identifiable, Sendable, Equatable {
    public let id: String
    public let merchantName: String
    public let amount: Decimal
    public let currencyCode: String
    public let categorySuggestion: String?
    public let frequency: SubscriptionFrequency
    public let nextExpectedDate: Date
    public let lastBilledDate: Date
    public let transactionCount: Int
    public let averageMonthlySpend: Decimal
    
    public init(
        id: String = UUID().uuidString,
        merchantName: String,
        amount: Decimal,
        currencyCode: String = CurrencyFormatter.defaultCurrencyCode,
        categorySuggestion: String? = nil,
        frequency: SubscriptionFrequency = .monthly,
        nextExpectedDate: Date,
        lastBilledDate: Date,
        transactionCount: Int,
        averageMonthlySpend: Decimal
    ) {
        self.id = id
        self.merchantName = merchantName
        self.amount = amount
        self.currencyCode = currencyCode
        self.categorySuggestion = categorySuggestion
        self.frequency = frequency
        self.nextExpectedDate = nextExpectedDate
        self.lastBilledDate = lastBilledDate
        self.transactionCount = transactionCount
        self.averageMonthlySpend = averageMonthlySpend
    }
}

/// Aggregate metrics and spending patterns for a specific merchant.
public struct MerchantSpendingInsight: Identifiable, Sendable, Equatable {
    public let id: String
    public let merchantName: String
    public let totalSpend: Decimal
    public let averageMonthlySpend: Decimal
    public let transactionCount: Int
    public let lastTransactionDate: Date
    public let categorySuggestion: String?
    
    public init(
        id: String = UUID().uuidString,
        merchantName: String,
        totalSpend: Decimal,
        averageMonthlySpend: Decimal,
        transactionCount: Int,
        lastTransactionDate: Date,
        categorySuggestion: String? = nil
    ) {
        self.id = id
        self.merchantName = merchantName
        self.totalSpend = totalSpend
        self.averageMonthlySpend = averageMonthlySpend
        self.transactionCount = transactionCount
        self.lastTransactionDate = lastTransactionDate
        self.categorySuggestion = categorySuggestion
    }
}

/// An anomalous transaction flagged for being significantly higher than historical merchant average.
public struct AnomalousTransactionAlert: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let transaction: TransactionCandidate
    public let historicalAverage: Decimal
    public let ratio: Double
    public let reason: String
    
    public init(
        id: UUID = UUID(),
        transaction: TransactionCandidate,
        historicalAverage: Decimal,
        ratio: Double,
        reason: String
    ) {
        self.id = id
        self.transaction = transaction
        self.historicalAverage = historicalAverage
        self.ratio = ratio
        self.reason = reason
    }
}

/// Suggested categorization rule derived from consistent historical user behavior.
public struct CategoryRuleSuggestion: Identifiable, Sendable, Equatable {
    public let id: String
    public let merchantName: String
    public let suggestedCategory: String
    public let confidence: Double
    public let matchingCount: Int
    
    public init(
        id: String = UUID().uuidString,
        merchantName: String,
        suggestedCategory: String,
        confidence: Double,
        matchingCount: Int
    ) {
        self.id = id
        self.merchantName = merchantName
        self.suggestedCategory = suggestedCategory
        self.confidence = confidence
        self.matchingCount = matchingCount
    }
}

/// Service protocol for merchant intelligence and subscription detection.
public protocol MerchantIntelligenceServiceProtocol: Sendable {
    func detectRecurringSubscriptions(from transactions: [TransactionCandidate]) -> [RecurringSubscription]
    func calculateMerchantInsights(from transactions: [TransactionCandidate]) -> [MerchantSpendingInsight]
    func identifyAnomalies(in transactions: [TransactionCandidate], historicalDays: Int) -> [AnomalousTransactionAlert]
    func suggestCategorizationRules(from transactions: [TransactionCandidate]) -> [CategoryRuleSuggestion]
}

/// Production implementation of Merchant Intelligence and Recurring Detection.
public final class MerchantIntelligenceService: MerchantIntelligenceServiceProtocol, Sendable {
    
    public static let shared = MerchantIntelligenceService()
    
    // Known subscription keywords that strongly indicate recurring billing
    private let knownSubscriptionKeywords: Set<String> = [
        "netflix", "spotify", "apple music", "youtube premium", "hotstar", "amazon prime",
        "icloud", "google storage", "google one", "gym", "cult.fit", "broadband", "airtel broadband",
        "jio fiber", "act fibernet", "rent", "newspaper", "magazine", "medium", "patreon",
        "chatgpt", "openai", "claude", "github", "aws", "digitalocean", "notion", "figma"
    ]
    
    public init() {}
    
    // MARK: - 1. Recurring Subscriptions Detection
    
    public func detectRecurringSubscriptions(from transactions: [TransactionCandidate]) -> [RecurringSubscription] {
        let calendar = Calendar.current
        let expenses = transactions.filter { $0.type == .expense && $0.amount > .zero }
        
        // Group by normalized merchant name
        let grouped = Dictionary(grouping: expenses) { tx in
            tx.merchantName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        
        var results: [RecurringSubscription] = []
        
        for (rawKey, merchantTxList) in grouped where !rawKey.isEmpty {
            let sortedTx = merchantTxList.sorted(by: { $0.transactionDate < $1.transactionDate })
            guard let latestTx = sortedTx.last else { continue }
            let merchantDisplayName = latestTx.merchantName
            
            let isKnownSubscriptionMerchant = knownSubscriptionKeywords.contains(where: { rawKey.contains($0) })
            
            if sortedTx.count >= 2 {
                // Check intervals between consecutive transactions
                var intervalsInDays: [Int] = []
                for i in 0..<(sortedTx.count - 1) {
                    let d1 = sortedTx[i].transactionDate
                    let d2 = sortedTx[i + 1].transactionDate
                    let days = abs(calendar.dateComponents([.day], from: d1, to: d2).day ?? 0)
                    intervalsInDays.append(days)
                }
                
                // Determine frequency and regularity
                let avgInterval = Double(intervalsInDays.reduce(0, +)) / Double(intervalsInDays.count)
                let isMonthlyInterval = avgInterval >= 25 && avgInterval <= 35
                let isWeeklyInterval = avgInterval >= 6 && avgInterval <= 8
                let isYearlyInterval = avgInterval >= 350 && avgInterval <= 380
                
                // Check amount consistency (e.g. variance within 15%)
                let amounts = sortedTx.map { $0.amount }
                let avgAmount = amounts.reduce(Decimal.zero, +) / Decimal(amounts.count)
                let amountsConsistent = amounts.allSatisfy { amount in
                    guard avgAmount > 0 else { return true }
                    let diff = abs(amount - avgAmount)
                    let diffDouble = NSDecimalNumber(decimal: diff).doubleValue
                    let avgDouble = NSDecimalNumber(decimal: avgAmount).doubleValue
                    return (diffDouble / avgDouble) <= 0.15
                }
                
                if (isMonthlyInterval || isWeeklyInterval || isYearlyInterval || isKnownSubscriptionMerchant) && amountsConsistent {
                    let frequency: SubscriptionFrequency
                    let daysToAdd: Int
                    
                    if isWeeklyInterval {
                        frequency = .weekly
                        daysToAdd = 7
                    } else if isYearlyInterval {
                        frequency = .yearly
                        daysToAdd = 365
                    } else {
                        frequency = .monthly
                        daysToAdd = 30
                    }
                    
                    let nextExpected = calendar.date(byAdding: .day, value: daysToAdd, to: latestTx.transactionDate) ?? latestTx.transactionDate
                    
                    let avgMonthlySpend: Decimal
                    switch frequency {
                    case .weekly:
                        avgMonthlySpend = avgAmount * Decimal(string: "4.33")!
                    case .monthly:
                        avgMonthlySpend = avgAmount
                    case .yearly:
                        avgMonthlySpend = avgAmount / Decimal(12)
                    }
                    
                    results.append(
                        RecurringSubscription(
                            id: "sub_\(rawKey)",
                            merchantName: merchantDisplayName,
                            amount: latestTx.amount,
                            currencyCode: latestTx.currencyCode,
                            categorySuggestion: latestTx.categorySuggestion,
                            frequency: frequency,
                            nextExpectedDate: nextExpected,
                            lastBilledDate: latestTx.transactionDate,
                            transactionCount: sortedTx.count,
                            averageMonthlySpend: avgMonthlySpend
                        )
                    )
                }
            } else if isKnownSubscriptionMerchant, let singleTx = sortedTx.first {
                // Known subscription merchant with single occurrence
                let nextExpected = calendar.date(byAdding: .day, value: 30, to: singleTx.transactionDate) ?? singleTx.transactionDate
                results.append(
                    RecurringSubscription(
                        id: "sub_\(rawKey)",
                        merchantName: merchantDisplayName,
                        amount: singleTx.amount,
                        currencyCode: singleTx.currencyCode,
                        categorySuggestion: singleTx.categorySuggestion,
                        frequency: .monthly,
                        nextExpectedDate: nextExpected,
                        lastBilledDate: singleTx.transactionDate,
                        transactionCount: 1,
                        averageMonthlySpend: singleTx.amount
                    )
                )
            }
        }
        
        return results.sorted(by: { $0.amount > $1.amount })
    }
    
    // MARK: - 2. Merchant Insights & Metrics
    
    public func calculateMerchantInsights(from transactions: [TransactionCandidate]) -> [MerchantSpendingInsight] {
        let expenses = transactions.filter { $0.type == .expense && $0.amount > .zero }
        let grouped = Dictionary(grouping: expenses) { tx in
            tx.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        var insights: [MerchantSpendingInsight] = []
        
        for (merchantName, txList) in grouped where !merchantName.isEmpty {
            let totalSpend = txList.reduce(Decimal.zero) { $0 + $1.amount }
            let sortedByDate = txList.sorted(by: { $0.transactionDate > $1.transactionDate })
            guard let latestTx = sortedByDate.first else { continue }
            
            // Calculate active span in months
            let calendar = Calendar.current
            let earliestDate = sortedByDate.last?.transactionDate ?? latestTx.transactionDate
            let monthSpan = max(1, calendar.dateComponents([.month], from: earliestDate, to: latestTx.transactionDate).month ?? 1)
            let avgMonthlySpend = totalSpend / Decimal(monthSpan)
            
            // Most frequent category
            let categoryCounts = Dictionary(grouping: txList.compactMap(\.categorySuggestion)) { $0 }
                .mapValues { $0.count }
            let mostFrequentCategory = categoryCounts.max(by: { $0.value < $1.value })?.key
            
            insights.append(
                MerchantSpendingInsight(
                    id: "insight_\(merchantName.lowercased())",
                    merchantName: merchantName,
                    totalSpend: totalSpend,
                    averageMonthlySpend: avgMonthlySpend,
                    transactionCount: txList.count,
                    lastTransactionDate: latestTx.transactionDate,
                    categorySuggestion: mostFrequentCategory
                )
            )
        }
        
        return insights.sorted(by: { $0.totalSpend > $1.totalSpend })
    }
    
    // MARK: - 3. Anomaly Detection
    
    public func identifyAnomalies(in transactions: [TransactionCandidate], historicalDays: Int = 90) -> [AnomalousTransactionAlert] {
        let calendar = Calendar.current
        let now = Date()
        guard let cutoffDate = calendar.date(byAdding: .day, value: -historicalDays, to: now) else { return [] }
        
        let expenses = transactions.filter { $0.type == .expense && $0.amount > .zero && $0.transactionDate >= cutoffDate }
        let grouped = Dictionary(grouping: expenses) { tx in
            tx.merchantName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        
        var alerts: [AnomalousTransactionAlert] = []
        
        for (_, txList) in grouped where txList.count >= 3 {
            let sorted = txList.sorted(by: { $0.transactionDate < $1.transactionDate })
            
            // Compare each recent transaction against the historical average of previous transactions
            for i in 2..<sorted.count {
                let currentTx = sorted[i]
                let previousTransactions = Array(sorted[0..<i])
                let previousSum = previousTransactions.reduce(Decimal.zero) { $0 + $1.amount }
                let previousAvg = previousSum / Decimal(previousTransactions.count)
                
                guard previousAvg > .zero else { continue }
                
                let currentAmountDouble = NSDecimalNumber(decimal: currentTx.amount).doubleValue
                let avgAmountDouble = NSDecimalNumber(decimal: previousAvg).doubleValue
                let ratio = currentAmountDouble / avgAmountDouble
                
                // Anomaly condition: transaction >= 2.0x of merchant historical average and absolute delta >= ₹300
                if ratio >= 2.0 && (currentTx.amount - previousAvg) >= Decimal(300) {
                    let formattedAvg = CurrencyFormatter.shared.format(amount: previousAvg, currencyCode: currentTx.currencyCode)
                    let reason = "Amount is \(String(format: "%.1f", ratio))x higher than your \(historicalDays)-day average (\(formattedAvg)) at \(currentTx.merchantName)."
                    
                    alerts.append(
                        AnomalousTransactionAlert(
                            id: currentTx.id,
                            transaction: currentTx,
                            historicalAverage: previousAvg,
                            ratio: ratio,
                            reason: reason
                        )
                    )
                }
            }
        }
        
        return alerts
    }
    
    // MARK: - 4. Categorization Rule Suggestions
    
    public func suggestCategorizationRules(from transactions: [TransactionCandidate]) -> [CategoryRuleSuggestion] {
        let expenses = transactions.filter { $0.type == .expense && !($0.categorySuggestion?.isEmpty ?? true) }
        let grouped = Dictionary(grouping: expenses) { tx in
            tx.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        var suggestions: [CategoryRuleSuggestion] = []
        
        for (merchant, txList) in grouped where txList.count >= 2 && !merchant.isEmpty {
            let categoryCounts = Dictionary(grouping: txList.compactMap(\.categorySuggestion)) { $0 }
                .mapValues { $0.count }
            
            guard let (topCategory, count) = categoryCounts.max(by: { $0.value < $1.value }) else { continue }
            let consistencyRatio = Double(count) / Double(txList.count)
            
            if consistencyRatio >= 0.75 {
                let confidence = min(0.99, max(0.75, consistencyRatio * 0.95))
                suggestions.append(
                    CategoryRuleSuggestion(
                        id: "rule_sug_\(merchant.lowercased())",
                        merchantName: merchant,
                        suggestedCategory: topCategory,
                        confidence: confidence,
                        matchingCount: count
                    )
                )
            }
        }
        
        return suggestions.sorted(by: { $0.confidence > $1.confidence })
    }
}
