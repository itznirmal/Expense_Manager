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
    public static let supportedCurrencyCodes = ["INR", "USD", "EUR", "GBP", "CAD", "AUD", "SGD", "AED", "JPY", "CHF", "NZD", "KWD"]

    public static var preferences: UserDefaults {
        if let index = CommandLine.arguments.firstIndex(of: "-UITestStore"), index + 1 < CommandLine.arguments.count {
            return UserDefaults(suiteName: "ExpenseManager.UITests." + CommandLine.arguments[index + 1]) ?? .standard
        }
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return UserDefaults(suiteName: "ExpenseManager.UnitTests." + String(ProcessInfo.processInfo.processIdentifier)) ?? .standard
        }
        return .standard
    }

    public static var defaultCurrencyCode: String {
        let code = preferences.string(forKey: "preferredCurrencyCode") ?? preferences.string(forKey: "defaultCurrency") ?? "INR"
        return Locale.commonISOCurrencyCodes.contains(code) ? code : "INR"
    }
    public static var defaultLocaleIdentifier: String { Locale.current.identifier }

    public static func setPreferredCurrency(_ code: String) {
        guard Locale.commonISOCurrencyCodes.contains(code) else { return }
        preferences.set(code, forKey: "preferredCurrencyCode")
    }

    public static func fractionDigits(for code: String) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.maximumFractionDigits
    }
    
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
        fractionDigits: Int? = nil,
        alwaysShowSign: Bool = false
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = includeSymbol ? .currency : .decimal
        formatter.currencyCode = currencyCode
        let digits = fractionDigits ?? Self.fractionDigits(for: currencyCode)
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        
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
        
        let scales: [(Decimal, String)] = locale.identifier.contains("IN")
            ? [(10000000, " Cr"), (100000, " L"), (1000, " K")]
            : [(1000000000, "B"), (1000000, "M"), (1000, "K")]
        if let (divisor, suffix) = scales.first(where: { absAmount >= $0.0 }) {
            let number = NumberFormatter()
            number.locale = locale
            number.numberStyle = .decimal
            number.minimumFractionDigits = 2
            number.maximumFractionDigits = 2
            let scaled = NSDecimalNumber(decimal: absAmount / divisor)
            return prefix + (number.string(from: scaled) ?? scaled.stringValue) + suffix
        }
        return format(amount: amount, currencyCode: currencyCode, locale: locale)
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
        
        let accountingNegative = cleaned.hasPrefix("(") && cleaned.hasSuffix(")")
        if accountingNegative { cleaned = String(cleaned.dropFirst().dropLast()) }
        
        // Remove common currency prefixes / words / symbols
        let stripPatterns = ["₹", "Rs.", "Rs", "$", "€", "£"] + Self.supportedCurrencyCodes
        for pattern in stripPatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle thousands separator
        let groupingSeparator = locale.groupingSeparator ?? ","
        let decimalSeparator = locale.decimalSeparator ?? "."
        let parts = cleaned.components(separatedBy: decimalSeparator)
        guard parts.count <= 2 else { return nil }
        let integer = parts[0].trimmingCharacters(in: CharacterSet(charactersIn: "+-"))
        if accountingNegative && (cleaned.hasPrefix("-") || cleaned.hasPrefix("+")) { return nil }
        if integer.contains(groupingSeparator) {
            let groups = integer.components(separatedBy: groupingSeparator)
            let grouping = NumberFormatter()
            grouping.locale = locale
            grouping.numberStyle = .decimal
            let primary = grouping.groupingSize
            let secondary = grouping.secondaryGroupingSize > 0 ? grouping.secondaryGroupingSize : primary
            guard primary > 0, let first = groups.first, let last = groups.last,
                  !first.isEmpty, first.count <= secondary, last.count == primary,
                  groups.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
                  groups.dropFirst().dropLast().allSatisfy({ $0.count == secondary }) else { return nil }
        }
        if parts.count == 2 && parts[1].contains(groupingSeparator) { return nil }
        
        cleaned = cleaned.replacingOccurrences(of: groupingSeparator, with: "")
        if decimalSeparator != "." {
            cleaned = cleaned.replacingOccurrences(of: decimalSeparator, with: ".")
        }
        
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.range(of: "^[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)$", options: .regularExpression) != nil else { return nil }
        guard let decimal = Decimal(string: cleaned) else {
            return nil
        }
        
        guard !decimal.isNaN else { return nil }
        return accountingNegative ? -decimal : decimal
    }
}
