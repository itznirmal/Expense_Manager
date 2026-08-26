//
//  SMSIngestionOrchestrator.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  End-to-End SMS Ingestion Orchestrator with Safety Filtering, Parsing, and Duplicate Prevention.
//

import Foundation

/// Pipeline outcome of an SMS ingestion attempt.
public enum SMSIngestionResult: Equatable, Sendable {
    case rejected(reason: String, messageType: SMSMessageType)
    case duplicate(reason: String, candidate: TransactionCandidate)
    case saved(candidate: TransactionCandidate, transactionID: String)
    case reviewRequired(candidate: TransactionCandidate, warnings: [String])
}

/// Orchestrates the entire SMS ingestion pipeline: Safety Classification -> Bank Parsing -> Duplicate Detection -> Rule Resolution -> Confidence Valuation -> Auto-Save/Queue.
public final class SMSIngestionOrchestrator: Sendable {
    
    private let transactionService: TransactionServiceProtocol?
    private let merchantRuleService: MerchantRuleServiceProtocol?
    private let fingerprintService: ImportFingerprintServiceProtocol?
    
    public init(
        transactionService: TransactionServiceProtocol? = nil,
        merchantRuleService: MerchantRuleServiceProtocol? = nil,
        fingerprintService: ImportFingerprintServiceProtocol? = nil
    ) {
        self.transactionService = transactionService
        self.merchantRuleService = merchantRuleService
        self.fingerprintService = fingerprintService
    }
    
    /// Processes raw incoming SMS text through the complete safety and ingestion pipeline.
    /// - Parameters:
    ///   - smsText: Raw text from SMS notification or Apple Shortcuts.
    ///   - autoSaveIfEligible: If true, automatically saves high-confidence transactions.
    ///   - referenceDate: Temporal reference date (defaults to now).
    /// - Returns: Ingestion result indicating whether the SMS was rejected, duplicate, saved, or queued for review.
    public func ingest(
        smsText: String,
        autoSaveIfEligible: Bool = true,
        referenceDate: Date = Date()
    ) async throws -> SMSIngestionResult {
        // Step 1: Strict AC-PARSE-2 Safety Classification
        let safety = SMSSafetyClassifier.classify(text: smsText)
        guard safety.isSafeForTransactionGeneration else {
            return .rejected(
                reason: safety.rejectionReason ?? "Non-transactional message.",
                messageType: safety.messageType
            )
        }
        
        // Step 2: Multi-Bank Deterministic Extraction
        var draft: ParsedTransactionDraft
        var accountMaskVal: String? = nil
        if let bankParsed = BankSMSParser.parse(smsText: smsText, referenceDate: referenceDate) {
            accountMaskVal = bankParsed.accountMask
            draft = ParsedTransactionDraft(
                type: bankParsed.direction,
                amount: bankParsed.amount,
                currencyCode: bankParsed.currencyCode,
                merchantName: bankParsed.merchant,
                inferredCategory: bankParsed.inferredCategory,
                accountSuggestion: bankParsed.bankName ?? "Bank Account",
                paymentMethod: bankParsed.paymentMethod,
                transactionDate: bankParsed.date,
                referenceNumber: bankParsed.referenceNumber,
                upiVPA: bankParsed.upiVPA,
                rawText: smsText
            )
        } else {
            draft = DeterministicTransactionParser.parse(text: smsText, referenceDate: referenceDate)
        }
        
        guard draft.amount > .zero else {
            return .rejected(
                reason: "Could not extract valid monetary amount from message.",
                messageType: .unknown
            )
        }
        
        // Step 3: Duplicate Prevention Check (Exact SHA-256 + 5-Minute Window)
        let sourceHash = ImportFingerprintService.computeSourceHash(
            amount: draft.amount,
            merchant: draft.merchantName,
            timestamp: draft.transactionDate,
            reference: draft.referenceNumber
        )
        
        if let fingerprintSvc = fingerprintService {
            let isExactDuplicate = try await fingerprintSvc.hasFingerprint(hash: sourceHash)
            if isExactDuplicate {
                let candidate = buildCandidate(from: draft, confidence: .high, needsReview: false, warnings: ["Exact duplicate detected"])
                return .duplicate(reason: "Exact message hash already ingested.", candidate: candidate)
            }
            
            let isTimeWindowDuplicate = try await fingerprintSvc.isDuplicate(
                amount: draft.amount,
                merchant: draft.merchantName,
                date: draft.transactionDate,
                accountLastFour: accountMaskVal,
                windowSeconds: 300
            )
            if isTimeWindowDuplicate {
                let candidate = buildCandidate(from: draft, confidence: .high, needsReview: false, warnings: ["Duplicate transaction within 5-minute window"])
                return .duplicate(reason: "Similar transaction within 5-minute window already ingested.", candidate: candidate)
            }
        }
        
        // Step 4: Merchant Rule Resolution
        var matchedRule: MerchantRuleRecord? = nil
        if let ruleSvc = merchantRuleService, !draft.merchantName.isEmpty {
            matchedRule = try? await ruleSvc.findMatchingRule(for: draft.merchantName)
        }
        
        let hasMatchedRule = matchedRule != nil
        if let rule = matchedRule {
            if let preferredCategory = rule.preferredCategoryID, !preferredCategory.isEmpty {
                draft.inferredCategory = preferredCategory
            }
            if let preferredAccount = rule.preferredAccountID, !preferredAccount.isEmpty {
                draft.accountSuggestion = preferredAccount
            }
        }
        
        // Step 5: Confidence Valuation & Auto-Save Decision
        let confidenceEval = ConfidenceEngine.evaluate(
            draft: draft,
            source: .sms,
            hasMatchedRule: hasMatchedRule
        )
        
        let candidate = buildCandidate(
            from: draft,
            confidence: confidenceEval.score,
            needsReview: !confidenceEval.isAutoSaveEligible,
            warnings: confidenceEval.warnings
        )
        
        // Step 6: Execution (Auto-Save or Review Queue)
        if autoSaveIfEligible && confidenceEval.isAutoSaveEligible, let txnSvc = transactionService {
            let savedID = try await txnSvc.createTransaction(candidate)
            
            // Record fingerprint
            try await fingerprintService?.recordFingerprint(
                sourceHash: sourceHash,
                amount: candidate.amount,
                merchant: candidate.merchantName,
                accountLastFour: accountMaskVal,
                reference: candidate.sourceReference,
                timestamp: candidate.transactionDate,
                source: "sms"
            )
            
            return .saved(candidate: candidate, transactionID: savedID)
        } else if let txnSvc = transactionService {
            // Persist as a durable review item in SwiftData
            var reviewCandidate = candidate
            reviewCandidate.needsReview = true
            let savedID = try await txnSvc.createTransaction(reviewCandidate)
            
            // Record fingerprint to prevent duplicate re-import
            try await fingerprintService?.recordFingerprint(
                sourceHash: sourceHash,
                amount: candidate.amount,
                merchant: candidate.merchantName,
                accountLastFour: accountMaskVal,
                reference: candidate.sourceReference,
                timestamp: candidate.transactionDate,
                source: "sms"
            )
            
            return .reviewRequired(candidate: reviewCandidate, warnings: confidenceEval.warnings)
        } else {
            // Fallback for stateless evaluation
            return .reviewRequired(candidate: candidate, warnings: confidenceEval.warnings)
        }
    }
    
    // MARK: - Helper
    
    private func buildCandidate(
        from draft: ParsedTransactionDraft,
        confidence: ConfidenceScore,
        needsReview: Bool,
        warnings: [String]
    ) -> TransactionCandidate {
        TransactionCandidate(
            id: UUID(),
            type: draft.type,
            amount: draft.amount,
            currencyCode: draft.currencyCode,
            merchantName: draft.merchantName,
            categorySuggestion: draft.inferredCategory,
            accountSuggestion: draft.accountSuggestion,
            destinationAccountSuggestion: draft.type == .transfer ? "Savings Account" : nil,
            paymentMethod: draft.paymentMethod,
            transactionDate: draft.transactionDate,
            notes: nil, // GT-69 Fix: Zero raw bank SMS text stored in notes
            tags: [],
            source: .sms,
            sourceReference: draft.referenceNumber,
            confidence: confidence,
            needsReview: needsReview,
            warnings: warnings
        )
    }
}
