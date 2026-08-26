//
//  MockParserService.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  In-Memory Mock Natural Language Parser Service.
//

import Foundation

public final class MockParserService: ParserServiceProtocol, Sendable {
    
    public init() {}
    
    public func parse(text: String, source: InputSource) async throws -> TransactionCandidate {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Basic deterministic extraction for mock/preview purposes
        let words = trimmed.components(separatedBy: .whitespaces)
        var extractedAmount: Decimal = .zero
        var extractedMerchant = "Merchant"
        var candidateType: TransactionType = .expense
        
        if trimmed.localizedCaseInsensitiveContains("salary") || trimmed.localizedCaseInsensitiveContains("credited") {
            candidateType = .income
            extractedMerchant = "Employer / Client"
        }
        
        for word in words {
            if let decimal = CurrencyFormatter.shared.parse(from: word), decimal > 0 {
                extractedAmount = decimal
                break
            }
        }
        
        if let firstWord = words.first, !firstWord.isEmpty, CurrencyFormatter.shared.parse(from: firstWord) == nil {
            extractedMerchant = firstWord.capitalized
        }
        
        let confidence: ConfidenceScore = extractedAmount > 0 ? .high : .medium
        
        return TransactionCandidate(
            id: UUID(),
            type: candidateType,
            amount: extractedAmount > 0 ? extractedAmount : Decimal(100),
            currencyCode: "INR",
            merchantName: extractedMerchant,
            categorySuggestion: candidateType == .income ? "Salary" : "Food & Dining",
            accountSuggestion: "HDFC Bank",
            paymentMethod: .upi,
            transactionDate: Date(),
            notes: trimmed,
            source: source,
            confidence: confidence,
            needsReview: !confidence.isAutoSaveEligible
        )
    }
    
    public func canHandle(text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
