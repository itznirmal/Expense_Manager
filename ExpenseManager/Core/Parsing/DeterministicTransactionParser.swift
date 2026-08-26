//
//  DeterministicTransactionParser.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  High-Speed Deterministic Multi-Extractor Parser Pipeline.
//

import Foundation

/// Intermediate draft output from the deterministic parser before rule enrichment and confidence scoring.
public struct ParsedTransactionDraft: Equatable, Sendable {
    public var type: TransactionType
    public var amount: Decimal
    public var currencyCode: String
    public var merchantName: String
    public var inferredCategory: String?
    public var accountSuggestion: String?
    public var paymentMethod: PaymentMethod?
    public var transactionDate: Date
    public var referenceNumber: String?
    public var upiVPA: String?
    public var rawText: String
    public var extractedKeywords: [String]
    
    public init(
        type: TransactionType = .expense,
        amount: Decimal = .zero,
        currencyCode: String = CurrencyFormatter.defaultCurrencyCode,
        merchantName: String = "",
        inferredCategory: String? = nil,
        accountSuggestion: String? = nil,
        paymentMethod: PaymentMethod? = nil,
        transactionDate: Date = Date(),
        referenceNumber: String? = nil,
        upiVPA: String? = nil,
        rawText: String = "",
        extractedKeywords: [String] = []
    ) {
        self.type = type
        self.amount = amount
        self.currencyCode = currencyCode
        self.merchantName = merchantName
        self.inferredCategory = inferredCategory
        self.accountSuggestion = accountSuggestion
        self.paymentMethod = paymentMethod
        self.transactionDate = transactionDate
        self.referenceNumber = referenceNumber
        self.upiVPA = upiVPA
        self.rawText = rawText
        self.extractedKeywords = extractedKeywords
    }
}

/// Orchestrates deterministic sub-parsers in sequence to extract a unified transaction draft.
public struct DeterministicTransactionParser: Sendable {
    
    public init() {}
    
    /// Parses raw input text deterministically.
    public static func parse(
        text: String,
        referenceDate: Date = Date()
    ) -> ParsedTransactionDraft {
        let normalized = InputNormalizer.normalize(text)
        guard !normalized.isEmpty else {
            return ParsedTransactionDraft(rawText: text)
        }
        
        var rangesToRemove: [Range<String.Index>] = []
        var keywords: [String] = []
        
        // 1. Extract Amount
        let extractedAmount = AmountParser.extractAmount(from: normalized)
        let amount = extractedAmount?.amount ?? .zero
        let currencyCode = extractedAmount?.currencyCode ?? CurrencyFormatter.defaultCurrencyCode
        if let amountRange = extractedAmount?.range {
            rangesToRemove.append(amountRange)
        }
        
        // 2. Extract Date
        let extractedDate = DateParser.extractDate(from: normalized, referenceDate: referenceDate)
        let transactionDate = extractedDate?.date ?? referenceDate
        if let dateRange = extractedDate?.range {
            rangesToRemove.append(dateRange)
        }
        
        // 3. Extract Reference / UPI VPA
        let extractedRef = ReferenceNumberParser.extractReference(from: normalized)
        let referenceNumber = extractedRef?.referenceNumber
        let upiVPA = extractedRef?.upiVPA
        if let refRange = extractedRef?.range {
            rangesToRemove.append(refRange)
        }
        
        // 4. Extract Account Hints & Payment Method
        let extractedAccount = AccountHintParser.extractAccountHint(from: normalized)
        let accountSuggestion = extractedAccount?.accountSuggestion
        var paymentMethod = extractedAccount?.paymentMethod
        if let accRange = extractedAccount?.range {
            rangesToRemove.append(accRange)
        }
        
        // Default payment method to UPI if VPA is present
        if paymentMethod == nil && upiVPA != nil {
            paymentMethod = .upi
        }
        
        // 5. Classify Direction
        let directionClassification = TransactionDirectionClassifier.classify(text: normalized)
        let transactionType = directionClassification.type
        keywords.append(contentsOf: directionClassification.matchedKeywords)
        
        // 6. Extract Merchant Name from residual text
        let residualText = InputNormalizer.removingRanges(normalized, ranges: rangesToRemove)
        
        // Clean direction keywords and prepositions from merchant candidate text
        var candidateMerchantRaw = residualText
        let fillerWords = [
            "(?i)\\b(?:paid\\s+(?:to|for)?|spent\\s+(?:on|at)?|debited\\s+(?:for|to)?|credited\\s+(?:by|to)?|received\\s+from|from|to|for|at|on|via|in|using|by)\\b",
            "(?i)\\b(?:transfer|transferred|withdrawn|salary|refund|deposit|cash)\\b"
        ]
        for filler in fillerWords {
            candidateMerchantRaw = candidateMerchantRaw.replacingOccurrences(of: filler, with: " ", options: .regularExpression)
        }
        
        var normalizedMerchant = MerchantNormalizer.normalizeMerchantName(candidateMerchantRaw)
        
        // If merchant is empty or "Unknown Merchant", try UPI VPA handle prefix
        if (normalizedMerchant.normalizedName.isEmpty || normalizedMerchant.normalizedName == "Unknown Merchant"),
           let vpa = upiVPA {
            let handle = vpa.components(separatedBy: "@").first ?? ""
            if !handle.isEmpty {
                normalizedMerchant = MerchantNormalizer.normalizeMerchantName(handle)
            }
        }
        
        // If merchant is still unknown, assign meaningful context based on transaction type
        var finalMerchantName = normalizedMerchant.normalizedName
        var inferredCategory = normalizedMerchant.inferredCategory
        
        if finalMerchantName.isEmpty || finalMerchantName == "Unknown Merchant" {
            switch transactionType {
            case .income:
                finalMerchantName = "Income / Deposit"
                if inferredCategory == nil { inferredCategory = "Salary" }
            case .refund:
                finalMerchantName = "Refund"
                if inferredCategory == nil { inferredCategory = "Refunds" }
            case .transfer:
                finalMerchantName = "Account Transfer"
                if inferredCategory == nil { inferredCategory = "Transfer" }
            case .cashWithdrawal:
                finalMerchantName = "ATM Cash Withdrawal"
                if inferredCategory == nil { inferredCategory = "Cash" }
            case .expense, .unknown:
                // If there's any residual word, use it
                let residualWords = InputNormalizer.tokenize(candidateMerchantRaw)
                if let firstWord = residualWords.first, firstWord.count > 1 {
                    finalMerchantName = firstWord.capitalized
                } else {
                    finalMerchantName = "Expense"
                }
            }
        } else {
            // Specific category heuristics if not mapped
            if inferredCategory == nil {
                if transactionType == .income {
                    inferredCategory = "Income"
                } else if transactionType == .transfer {
                    inferredCategory = "Transfer"
                } else if transactionType == .cashWithdrawal {
                    inferredCategory = "Cash"
                }
            }
        }
        
        return ParsedTransactionDraft(
            type: transactionType,
            amount: amount,
            currencyCode: currencyCode,
            merchantName: finalMerchantName,
            inferredCategory: inferredCategory,
            accountSuggestion: accountSuggestion,
            paymentMethod: paymentMethod,
            transactionDate: transactionDate,
            referenceNumber: referenceNumber,
            upiVPA: upiVPA,
            rawText: normalized,
            extractedKeywords: keywords
        )
    }
}
