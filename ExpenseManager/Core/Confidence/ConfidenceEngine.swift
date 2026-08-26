//
//  ConfidenceEngine.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Transaction Ingestion Confidence Valuation & Warning Diagnostics.
//

import Foundation

/// Detailed evaluation output including numeric confidence score, routing tier, and diagnostic warnings.
public struct ConfidenceEvaluation: Equatable, Sendable {
    public let score: ConfidenceScore
    public let warnings: [String]
    public let isAutoSaveEligible: Bool
    
    public init(
        score: ConfidenceScore,
        warnings: [String] = [],
        isAutoSaveEligible: Bool? = nil
    ) {
        self.score = score
        self.warnings = warnings
        self.isAutoSaveEligible = isAutoSaveEligible ?? score.isAutoSaveEligible
    }
}

/// Computes granular confidence scores (0.0 to 1.0) and assigns review queue tiers.
public struct ConfidenceEngine: Sendable {
    
    public init() {}
    
    /// Evaluates a parsed transaction draft and returns a confidence assessment.
    public static func evaluate(
        draft: ParsedTransactionDraft,
        source: InputSource,
        hasMatchedRule: Bool = false
    ) -> ConfidenceEvaluation {
        // Manual entry is 100% verified by definition
        if source == .manual {
            return ConfidenceEvaluation(
                score: .manual,
                warnings: [],
                isAutoSaveEligible: true
            )
        }
        
        var totalScore: Double = 0.0
        var warnings: [String] = []
        
        // 1. Amount Evaluation (Weight: 0.35)
        if draft.amount > .zero {
            totalScore += 0.35
        } else {
            warnings.append("Missing or invalid amount")
        }
        
        // 2. Merchant Evaluation (Weight: 0.25)
        let genericMerchants = ["Unknown Merchant", "Expense", "Income / Deposit", "Account Transfer", "ATM Cash Withdrawal"]
        if !draft.merchantName.isEmpty && !genericMerchants.contains(draft.merchantName) {
            totalScore += 0.25
        } else if !draft.merchantName.isEmpty {
            totalScore += 0.10
            warnings.append("Generic or inferred merchant name")
        } else {
            warnings.append("Missing merchant name")
        }
        
        // 3. Direction Evaluation (Weight: 0.15)
        if draft.type != .unknown {
            totalScore += 0.15
        } else {
            warnings.append("Uncertain transaction direction")
        }
        
        // 4. Account Evaluation (Weight: 0.15)
        if draft.accountSuggestion != nil && !draft.accountSuggestion!.isEmpty {
            totalScore += 0.15
        } else {
            warnings.append("Unassigned bank/payment account")
        }
        
        // 5. Category Evaluation (Weight: 0.10)
        if draft.inferredCategory != nil && !draft.inferredCategory!.isEmpty {
            totalScore += 0.10
        } else {
            warnings.append("Uncategorized transaction")
        }
        
        // 6. User Rule Matching Boost (+0.15)
        if hasMatchedRule {
            totalScore += 0.15
        }
        
        // 7. UPI / Reference Verification Boost (+0.05)
        if draft.upiVPA != nil || draft.referenceNumber != nil {
            totalScore += 0.05
        }
        
        // High amount anomaly warning (e.g. amounts > ₹50,000)
        if draft.amount >= Decimal(50000) {
            warnings.append("High value transaction requires confirmation")
        }
        
        let finalScore = ConfidenceScore(totalScore)
        
        return ConfidenceEvaluation(
            score: finalScore,
            warnings: warnings,
            isAutoSaveEligible: finalScore.isAutoSaveEligible && warnings.isEmpty
        )
    }
}
