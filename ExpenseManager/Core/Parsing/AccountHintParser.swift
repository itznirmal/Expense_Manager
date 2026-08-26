//
//  AccountHintParser.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Bank Hints, Account Last Four Digits, and Payment Method Extractor.
//

import Foundation

/// Result of account and payment method hint extraction.
public struct ExtractedAccountHint: Equatable, Sendable {
    public let bankName: String?
    public let lastFour: String?
    public var accountLastFour: String? { lastFour }
    public let accountSuggestion: String?
    public let paymentMethod: PaymentMethod?
    public let matchedString: String
    public let range: Range<String.Index>?
    
    public init(
        bankName: String? = nil,
        lastFour: String? = nil,
        accountSuggestion: String? = nil,
        paymentMethod: PaymentMethod? = nil,
        matchedString: String = "",
        range: Range<String.Index>? = nil
    ) {
        self.bankName = bankName
        self.lastFour = lastFour
        self.accountSuggestion = accountSuggestion
        self.paymentMethod = paymentMethod
        self.matchedString = matchedString
        self.range = range
    }
}

/// Extractor for bank hints, masked account numbers, and payment methods.
public struct AccountHintParser: Sendable {
    
    public init() {}
    
    private static let knownBanks: [(pattern: String, canonicalName: String)] = [
        ("(?i)\\bhdfc(?:\\s+bank)?\\b", "HDFC Bank"),
        ("(?i)\\bicici(?:\\s+bank)?\\b", "ICICI Bank"),
        ("(?i)\\bsbi\\b|(?i)\\bstate\\s+bank(?:\\s+of\\s+india)?\\b", "State Bank of India"),
        ("(?i)\\baxis(?:\\s+bank)?\\b", "Axis Bank"),
        ("(?i)\\bkotak(?:\\s+mahindra)?(?:\\s+bank)?\\b", "Kotak Mahindra Bank"),
        ("(?i)\\bindusind(?:\\s+bank)?\\b", "IndusInd Bank"),
        ("(?i)\\bfederal\\s+bank\\b", "Federal Bank"),
        ("(?i)\\bcanara\\s+bank\\b", "Canara Bank"),
        ("(?i)\\bpnb\\b|(?i)\\bpunjab\\s+national\\s+bank\\b", "Punjab National Bank"),
        ("(?i)\\bciti(?:bank)?\\b", "Citibank"),
        ("(?i)\\bstandard\\s+chartered\\b|(?i)\\bstan\\s+chart\\b", "Standard Chartered"),
        ("(?i)\\bamex\\b|(?i)\\bamerican\\s+express\\b", "American Express"),
        ("(?i)\\bpaytm\\s+payments?\\s+bank\\b|(?i)\\bpaytm\\s+bank\\b", "Paytm Payments Bank"),
        ("(?i)\\bapple\\s+pay\\b|(?i)\\bapple\\s+wallet\\b", "Apple Pay"),
        ("(?i)\\bgoogle\\s+pay\\b|(?i)\\bgpay\\b", "Google Pay"),
        ("(?i)\\bphonepe\\b", "PhonePe"),
        ("(?i)\\bcash\\b", "Cash")
    ]
    
    // Pattern for last four digits: XX4321, **4321, ending 8432, card 9876, a/c 1234, etc.
    private static let lastFourRegex = "(?i)(?:xx|\\*\\*|ending\\s+(?:in\\s+)?|card\\s+(?:no\\.?\\s+)?(?:ending\\s+)?|a/?c\\s+(?:no\\.?\\s+)?(?:ending\\s+)?|account\\s+(?:ending\\s+)?)([0-9]{4})\\b"
    
    /// Extracts account hints, bank names, and payment methods from text.
    public static func extractAccountHint(from text: String) -> ExtractedAccountHint? {
        let normalized = InputNormalizer.normalize(text)
        guard !normalized.isEmpty else { return nil }
        let nsRange = NSRange(location: 0, length: normalized.utf16.count)
        
        var detectedBank: String? = nil
        var detectedLastFour: String? = nil
        var detectedPaymentMethod: PaymentMethod? = nil
        var matchedPhrases: [String] = []
        var matchedRange: Range<String.Index>? = nil
        
        // 1. Check for last 4 digits
        if let regex = try? NSRegularExpression(pattern: lastFourRegex, options: []),
           let match = regex.firstMatch(in: normalized, options: [], range: nsRange),
           match.numberOfRanges >= 2,
           let fullRange = Range(match.range(at: 0), in: normalized),
           let digitsRange = Range(match.range(at: 1), in: normalized) {
            
            detectedLastFour = String(normalized[digitsRange])
            let matchText = String(normalized[fullRange])
            matchedPhrases.append(matchText)
            matchedRange = fullRange
            
            if matchText.lowercased().contains("card") {
                detectedPaymentMethod = .creditCard
            } else if matchText.lowercased().contains("a/c") || matchText.lowercased().contains("ac") || matchText.lowercased().contains("account") {
                detectedPaymentMethod = .netBanking
            }
        }
        
        // 2. Check for Bank / Channel Names
        for (pattern, canonical) in knownBanks {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: normalized, options: [], range: nsRange),
               let fullRange = Range(match.range(at: 0), in: normalized) {
                
                detectedBank = canonical
                matchedPhrases.append(String(normalized[fullRange]))
                if matchedRange == nil {
                    matchedRange = fullRange
                }
                
                if canonical == "Cash" {
                    detectedPaymentMethod = .cash
                } else if canonical == "Apple Pay" || canonical == "Google Pay" || canonical == "PhonePe" {
                    detectedPaymentMethod = .upi
                }
                break
            }
        }
        
        // 3. Check for specific payment method keywords if not already detected
        let lowercased = normalized.lowercased()
        if detectedPaymentMethod == nil {
            if lowercased.contains("upi") || lowercased.contains("@") {
                detectedPaymentMethod = .upi
            } else if lowercased.contains("credit card") || lowercased.contains("creditcard") {
                detectedPaymentMethod = .creditCard
            } else if lowercased.contains("debit card") || lowercased.contains("debitcard") {
                detectedPaymentMethod = .debitCard
            } else if lowercased.contains("netbanking") || lowercased.contains("net banking") {
                detectedPaymentMethod = .netBanking
            } else if lowercased.contains("wallet") {
                detectedPaymentMethod = .wallet
            } else if lowercased.contains("cash") {
                detectedPaymentMethod = .cash
            }
        }
        
        guard detectedBank != nil || detectedLastFour != nil || detectedPaymentMethod != nil else {
            return nil
        }
        
        // Synthesize account suggestion name
        var suggestionParts: [String] = []
        if let bank = detectedBank {
            suggestionParts.append(bank)
        }
        if let last4 = detectedLastFour {
            suggestionParts.append("•••• \(last4)")
        }
        
        let accountSuggestion = suggestionParts.isEmpty ? nil : suggestionParts.joined(separator: " ")
        
        return ExtractedAccountHint(
            bankName: detectedBank,
            lastFour: detectedLastFour,
            accountSuggestion: accountSuggestion,
            paymentMethod: detectedPaymentMethod,
            matchedString: matchedPhrases.joined(separator: " "),
            range: matchedRange
        )
    }
}
