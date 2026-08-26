//
//  TransactionDirectionClassifier.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Transaction Accounting Direction & Intent Classifier.
//

import Foundation

/// Classification output containing detected accounting direction, confidence, and keyword evidence.
public struct DirectionClassification: Equatable, Sendable {
    public let type: TransactionType
    public let confidence: Double
    public let matchedKeywords: [String]
    
    public init(
        type: TransactionType,
        confidence: Double,
        matchedKeywords: [String] = []
    ) {
        self.type = type
        self.confidence = confidence
        self.matchedKeywords = matchedKeywords
    }
}

/// Classifies transaction text into accounting directions (Expense, Income, Refund, Transfer, Cash Withdrawal).
public struct TransactionDirectionClassifier: Sendable {
    
    public init() {}
    
    private static let incomeKeywords: [String] = [
        "credited", "credit", "received", "salary", "earned", "deposited", "deposit",
        "bonus", "cashback", "dividend", "interest credited", "interest", "stipend",
        "payout", "got paid", "incoming", "refund credited", "reimbursement"
    ]
    
    private static let refundKeywords: [String] = [
        "refund", "refunded", "reversal", "reversed", "cashback reversal", "reimbursed"
    ]
    
    private static let transferKeywords: [String] = [
        "transfer", "transferred", "self transfer", "sent to my", "moved to", "to savings",
        "to account", "acc transfer", "fund transfer", "neft", "rtgs", "imps to self",
        "transferred to", "transfer to"
    ]
    
    private static let cashWithdrawalKeywords: [String] = [
        "withdrawn", "withdraw", "withdrawal", "atm", "atm wdl", "cash out", "atm withdrawal",
        "cash withdraw", "cash withdrawal"
    ]
    
    private static let expenseKeywords: [String] = [
        "paid", "spent", "debited", "debit", "bought", "purchase", "purchased", "sent",
        "bill", "order", "recharge", "fee", "charged", "swiggy", "zomato", "uber", "ola",
        "blinkit", "zepto", "amazon", "flipkart", "fuel", "petrol", "groceries", "grocery",
        "dinner", "lunch", "breakfast", "coffee", "dine"
    ]
    
    /// Classifies the transaction text into accounting direction.
    public static func classify(text: String) -> DirectionClassification {
        let lowercased = text.lowercased()
        
        // 1. Check Refund Keywords
        let matchedRefund = refundKeywords.filter { containsKeyword(in: lowercased, keyword: $0) }
        if !matchedRefund.isEmpty {
            return DirectionClassification(type: .refund, confidence: 0.95, matchedKeywords: matchedRefund)
        }
        
        // 2. Check Cash Withdrawal Keywords
        let matchedWithdrawal = cashWithdrawalKeywords.filter { containsKeyword(in: lowercased, keyword: $0) }
        if !matchedWithdrawal.isEmpty {
            return DirectionClassification(type: .cashWithdrawal, confidence: 0.95, matchedKeywords: matchedWithdrawal)
        }
        
        // 3. Check Transfer Keywords
        let matchedTransfer = transferKeywords.filter { containsKeyword(in: lowercased, keyword: $0) }
        if !matchedTransfer.isEmpty {
            return DirectionClassification(type: .transfer, confidence: 0.92, matchedKeywords: matchedTransfer)
        }
        
        // 4. Check Income Keywords
        let matchedIncome = incomeKeywords.filter { containsKeyword(in: lowercased, keyword: $0) }
        if !matchedIncome.isEmpty {
            return DirectionClassification(type: .income, confidence: 0.95, matchedKeywords: matchedIncome)
        }
        
        // 5. Check Explicit Expense Keywords
        let matchedExpense = expenseKeywords.filter { containsKeyword(in: lowercased, keyword: $0) }
        if !matchedExpense.isEmpty {
            return DirectionClassification(type: .expense, confidence: 0.90, matchedKeywords: matchedExpense)
        }
        
        // Default fallback: In financial tracking, short text entries like "Swiggy 520" or "Coffee 350" are expenses
        return DirectionClassification(type: .expense, confidence: 0.70, matchedKeywords: [])
    }
    
    private static func containsKeyword(in text: String, keyword: String) -> Bool {
        if keyword.contains(" ") {
            return text.contains(keyword)
        }
        // Word boundary match for single words
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: text.utf16.count)
            return regex.firstMatch(in: text, options: [], range: range) != nil
        }
        return text.contains(keyword)
    }
}
