//
//  AmountParser.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Deterministic Financial Amount & Currency Extractor.
//

import Foundation

/// Result of an amount extraction operation.
public struct ExtractedAmount: Equatable, Sendable {
    public let amount: Decimal
    public let currencyCode: String
    public let rawMatch: String
    public let range: Range<String.Index>
    
    public init(
        amount: Decimal,
        currencyCode: String = CurrencyFormatter.defaultCurrencyCode,
        rawMatch: String,
        range: Range<String.Index>
    ) {
        self.amount = amount
        self.currencyCode = currencyCode
        self.rawMatch = rawMatch
        self.range = range
    }
}

/// Robust deterministic extractor for financial amounts and currency codes.
public struct AmountParser: Sendable {
    
    public init() {}
    
    /// Currency prefix and suffix pattern definitions.
    private static let currencyPrefixPatterns: [(pattern: String, currencyCode: String)] = [
        ("(?i)(?:₹|rs\\.?|inr)\\s*([0-9]{1,3}(?:,[0-9]{2,3})*(?:\\.[0-9]{1,2})?|[0-9]+(?:\\.[0-9]{1,2})?)", "INR"),
        ("(?i)(?:\\$|usd)\\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]{1,2})?|[0-9]+(?:\\.[0-9]{1,2})?)", "USD"),
        ("(?i)(?:€|eur)\\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]{1,2})?|[0-9]+(?:\\.[0-9]{1,2})?)", "EUR"),
        ("(?i)(?:£|gbp)\\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]{1,2})?|[0-9]+(?:\\.[0-9]{1,2})?)", "GBP")
    ]
    
    private static let currencySuffixPatterns: [(pattern: String, currencyCode: String)] = [
        ("(?i)([0-9]{1,3}(?:,[0-9]{2,3})*(?:\\.[0-9]{1,2})?|[0-9]+(?:\\.[0-9]{1,2})?)\\s*(?:₹|rs\\.?|rupees?|inr|bucks)", "INR"),
        ("(?i)([0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]{1,2})?|[0-9]+(?:\\.[0-9]{1,2})?)\\s*(?:\\$|usd|dollars?|cents?)", "USD"),
        ("(?i)([0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]{1,2})?|[0-9]+(?:\\.[0-9]{1,2})?)\\s*(?:€|eur|euros?)", "EUR"),
        ("(?i)([0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]{1,2})?|[0-9]+(?:\\.[0-9]{1,2})?)\\s*(?:£|gbp|pounds?)", "GBP")
    ]
    
    // Standalone number pattern (e.g., "Swiggy 520", "Coffee 350.50", "1,450.00")
    // Restrict bare digits to 1-7 digits to prevent matching 10-digit phone numbers, 12-digit UTRs, or timestamps
    private static let bareNumberPattern = "\\b([0-9]{1,3}(?:,[0-9]{2,3})*(?:\\.[0-9]{1,2})?|[0-9]{1,7}(?:\\.[0-9]{1,2})?)\\b"
    
    /// Extracts the first or most prominent financial amount from the provided text.
    public static func extractAmount(from text: String) -> ExtractedAmount? {
        let normalized = InputNormalizer.normalize(text)
        guard !normalized.isEmpty else { return nil }
        
        let nsRange = NSRange(location: 0, length: normalized.utf16.count)
        
        // 1. Try Currency Prefix Matching (e.g. ₹520, Rs. 1,450.50, $12.99)
        for (pattern, code) in currencyPrefixPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: normalized, options: [], range: nsRange),
               match.numberOfRanges >= 2,
               let fullRange = Range(match.range(at: 0), in: normalized),
               let numRange = Range(match.range(at: 1), in: normalized) {
                
                let numString = String(normalized[numRange])
                if let decimal = parseCleanDecimal(from: numString), decimal > .zero {
                    return ExtractedAmount(
                        amount: decimal,
                        currencyCode: code,
                        rawMatch: String(normalized[fullRange]),
                        range: fullRange
                    )
                }
            }
        }
        
        // 2. Try Currency Suffix Matching (e.g. 520 rupees, 1450.50 rs, 12.99 USD)
        for (pattern, code) in currencySuffixPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: normalized, options: [], range: nsRange),
               match.numberOfRanges >= 2,
               let fullRange = Range(match.range(at: 0), in: normalized),
               let numRange = Range(match.range(at: 1), in: normalized) {
                
                let numString = String(normalized[numRange])
                if let decimal = parseCleanDecimal(from: numString), decimal > .zero {
                    return ExtractedAmount(
                        amount: decimal,
                        currencyCode: code,
                        rawMatch: String(normalized[fullRange]),
                        range: fullRange
                    )
                }
            }
        }
        
        // 3. Try Bare Number Matching (e.g. "Swiggy 520", "350")
        if let regex = try? NSRegularExpression(pattern: bareNumberPattern, options: []) {
            let matches = regex.matches(in: normalized, options: [], range: nsRange)
            for match in matches {
                guard let fullRange = Range(match.range(at: 0), in: normalized) else { continue }
                let matchedString = String(normalized[fullRange])
                
                // Skip if this looks like a year (e.g. 2024, 2025, 2026) when surrounded by date context
                if let yearVal = Int(matchedString), (1990...2040).contains(yearVal) {
                    let preceding = String(normalized[..<fullRange.lowerBound]).lowercased()
                    let succeeding = String(normalized[fullRange.upperBound...]).lowercased()
                    if preceding.contains("aug") || preceding.contains("jan") || preceding.contains("/") || preceding.contains("-") ||
                       succeeding.contains("aug") || succeeding.contains("jan") || succeeding.contains("/") || succeeding.contains("-") {
                        continue
                    }
                }
                
                // Skip if this is part of account last four or card notation
                let precedingText = String(normalized[..<fullRange.lowerBound]).lowercased()
                if precedingText.hasSuffix("ending ") || precedingText.hasSuffix("card ") ||
                   precedingText.hasSuffix("a/c ") || precedingText.hasSuffix("ac ") ||
                   precedingText.hasSuffix("xx") || precedingText.hasSuffix("**") ||
                   precedingText.hasSuffix("ref ") || precedingText.hasSuffix("utr ") {
                    continue
                }
                
                if let decimal = parseCleanDecimal(from: matchedString), decimal > .zero {
                    return ExtractedAmount(
                        amount: decimal,
                        currencyCode: CurrencyFormatter.defaultCurrencyCode,
                        rawMatch: matchedString,
                        range: fullRange
                    )
                }
            }
        }
        
        return nil
    }
    
    /// Parses a clean string representation into a precise Decimal amount.
    public static func parseCleanDecimal(from text: String) -> Decimal? {
        let cleaned = text.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US"))
    }
}
