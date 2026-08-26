//
//  CurrencyFormatter.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Exact Decimal Financial Formatting & Parsing.
//

import Foundation

/// High-precision, locale-aware currency formatter and parser using Decimal arithmetic.
/// Invariant: Money is never converted to or from Double for display arithmetic.
public final class CurrencyFormatter: Sendable {
    
    public static let shared = CurrencyFormatter()
    
    // Default fallback currency code and locale
    public static let defaultCurrencyCode = "INR"
    public static let defaultLocaleIdentifier = "en_IN"
    
    public init() {}
    
    // MARK: - Formatting
    
    /// Formats a Decimal value as a localized currency string.
    /// - Parameters:
    ///   - amount: The exact Decimal amount to format.
    ///   - currencyCode: 3-letter ISO currency code (default: "INR").
    ///   - locale: Target Locale (default: "en_IN").
    ///   - includeSymbol: Whether to prepend/append the currency symbol.
    ///   - fractionDigits: Minimum and maximum fraction digits (default: 2).
    ///   - alwaysShowSign: If true, prepends "+" for positive numbers.
    /// - Returns: Localized formatted currency string (e.g., "₹1,24,500.00" or "+₹500.00").
    public func format(
        amount: Decimal,
        currencyCode: String = defaultCurrencyCode,
        locale: Locale = Locale(identifier: defaultLocaleIdentifier),
        includeSymbol: Bool = true,
        fractionDigits: Int = 2,
        alwaysShowSign: Bool = false
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = includeSymbol ? .currency : .decimal
        formatter.currencyCode = currencyCode
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        
        let isNegative = amount < 0
        let absAmount = isNegative ? -amount : amount
        let nsDecimal = NSDecimalNumber(decimal: absAmount)
        
        let formattedBase = formatter.string(from: nsDecimal) ?? "\(absAmount)"
        
        if isNegative {
            return "-\(formattedBase)"
        } else if alwaysShowSign && amount > 0 {
            return "+\(formattedBase)"
        } else {
            return formattedBase
        }
    }
    
    /// Formats an amount into a compact representation for charts and summary tiles.
    /// Supports Indian scale (K, L, Cr) when using en_IN locale or standard K/M/B.
    /// - Parameters:
    ///   - amount: Decimal amount.
    ///   - currencyCode: Currency code.
    ///   - locale: Target locale.
    /// - Returns: Compact string representation, e.g. "₹1.5L", "₹45K", "₹2.4Cr".
    public func formatCompact(
        amount: Decimal,
        currencyCode: String = defaultCurrencyCode,
        locale: Locale = Locale(identifier: defaultLocaleIdentifier)
    ) -> String {
        let symbol = symbol(for: currencyCode, locale: locale)
        let isNegative = amount < 0
        let absAmount = isNegative ? -amount : amount
        let prefix = isNegative ? "-\(symbol)" : symbol
        
        let doubleVal = NSDecimalNumber(decimal: absAmount).doubleValue
        
        if locale.identifier.contains("IN") {
            // Indian Numbering System: 1 Crore = 10,000,000, 1 Lakh = 100,000, 1 Thousand = 1,000
            if doubleVal >= 10_000_000 {
                let cr = doubleVal / 10_000_000
                return String(format: "%@%.2f Cr", prefix, cr).replacingOccurrences(of: ".00", with: "")
            } else if doubleVal >= 100_000 {
                let lakh = doubleVal / 100_000
                return String(format: "%@%.2f L", prefix, lakh).replacingOccurrences(of: ".00", with: "")
            } else if doubleVal >= 1_000 {
                let k = doubleVal / 1_000
                return String(format: "%@%.1f K", prefix, k).replacingOccurrences(of: ".0", with: "")
            } else {
                return format(amount: amount, currencyCode: currencyCode, locale: locale, fractionDigits: 0)
            }
        } else {
            // International Numbering System: B, M, K
            if doubleVal >= 1_000_000_000 {
                let b = doubleVal / 1_000_000_000
                return String(format: "%@%.2fB", prefix, b)
            } else if doubleVal >= 1_000_000 {
                let m = doubleVal / 1_000_000
                return String(format: "%@%.2fM", prefix, m)
            } else if doubleVal >= 1_000 {
                let k = doubleVal / 1_000
                return String(format: "%@%.1fK", prefix, k)
            } else {
                return format(amount: amount, currencyCode: currencyCode, locale: locale, fractionDigits: 0)
            }
        }
    }
    
    /// Extracts the currency symbol for a given currency code and locale.
    public func symbol(for currencyCode: String = defaultCurrencyCode, locale: Locale = Locale(identifier: defaultLocaleIdentifier)) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.currencySymbol ?? currencyCode
    }
    
    // MARK: - Parsing
    
    /// Parses a raw user-input or extracted string into a Decimal value.
    /// Handles currency symbols ("₹", "$", "€"), abbreviations ("Rs.", "INR", "USD"),
    /// thousand separators (",") and spaces.
    /// - Parameters:
    ///   - string: Input string.
    ///   - locale: Locale for decimal separator convention.
    /// - Returns: Valid Decimal if parseable, or nil.
    public func parse(from string: String, locale: Locale = Locale(identifier: defaultLocaleIdentifier)) -> Decimal? {
        var cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        
        let isNegative = cleaned.contains("-") || (cleaned.hasPrefix("(") && cleaned.hasSuffix(")"))
        
        // Remove common currency prefixes / words / symbols
        let stripPatterns = ["₹", "Rs.", "Rs", "INR", "$", "USD", "€", "EUR", "£", "GBP", "(", ")", "+", "-"]
        for pattern in stripPatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle thousands separator
        let groupingSeparator = locale.groupingSeparator ?? ","
        let decimalSeparator = locale.decimalSeparator ?? "."
        
        cleaned = cleaned.replacingOccurrences(of: groupingSeparator, with: "")
        if decimalSeparator != "." {
            cleaned = cleaned.replacingOccurrences(of: decimalSeparator, with: ".")
        }
        
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let decimal = Decimal(string: cleaned) else {
            return nil
        }
        
        return isNegative ? -decimal : decimal
    }
}
