//
//  ParserOrchestrator.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Hybrid Ingestion Parser Orchestrator implementing ParserServiceProtocol.
//

import Foundation

/// Coordinates deterministic parsing, user-defined merchant rules, and confidence valuation.
public final class ParserOrchestrator: ParserServiceProtocol, Sendable {
    
    private let merchantRuleService: MerchantRuleServiceProtocol?
    
    public init(merchantRuleService: MerchantRuleServiceProtocol? = nil) {
        self.merchantRuleService = merchantRuleService
    }
    
    public func parse(text: String, source: InputSource) async throws -> TransactionCandidate {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return TransactionCandidate(
                id: UUID(),
                type: .expense,
                amount: .zero,
                merchantName: "Unknown",
                source: source,
                confidence: .low,
                needsReview: true,
                warnings: ["Input text is empty"]
            )
        }
        
        // 1. Run Deterministic Multi-Extractor Pipeline
        let draft = DeterministicTransactionParser.parse(text: trimmed)
        
        // 2. Check User-Defined Merchant Rules
        var matchedRule: MerchantRuleRecord? = nil
        if let ruleService = merchantRuleService, !draft.merchantName.isEmpty {
            matchedRule = try? await ruleService.findMatchingRule(for: draft.merchantName)
        }
        
        let hasMatchedRule = matchedRule != nil
        
        // 3. Resolve Category & Account suggestions
        var resolvedCategory = draft.inferredCategory
        var resolvedAccount = draft.accountSuggestion
        var resolvedTags: [String] = []
        
        if let rule = matchedRule {
            if let preferredCategory = rule.preferredCategoryID, !preferredCategory.isEmpty {
                resolvedCategory = preferredCategory
            }
            if let preferredAccount = rule.preferredAccountID, !preferredAccount.isEmpty {
                resolvedAccount = preferredAccount
            }
            resolvedTags = rule.preferredTags
        }
        
        // 4. Run Confidence Valuation & Diagnostics
        var updatedDraft = draft
        updatedDraft.inferredCategory = resolvedCategory
        updatedDraft.accountSuggestion = resolvedAccount
        
        let evaluation = ConfidenceEngine.evaluate(
            draft: updatedDraft,
            source: source,
            hasMatchedRule: hasMatchedRule
        )
        
        return TransactionCandidate(
            id: UUID(),
            type: draft.type,
            amount: draft.amount,
            currencyCode: draft.currencyCode,
            merchantName: draft.merchantName,
            categorySuggestion: resolvedCategory,
            accountSuggestion: resolvedAccount,
            destinationAccountSuggestion: draft.type == .transfer ? "Savings Account" : nil,
            paymentMethod: draft.paymentMethod,
            transactionDate: draft.transactionDate,
            notes: draft.rawText,
            tags: resolvedTags,
            source: source,
            sourceReference: draft.referenceNumber,
            confidence: evaluation.score,
            needsReview: !evaluation.isAutoSaveEligible,
            warnings: evaluation.warnings
        )
    }
    
    public func canHandle(text: String) -> Bool {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !cleaned.isEmpty
    }
}
