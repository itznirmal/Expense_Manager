//
//  MoneyValidation.swift
//  ExpenseManager
//
//  Boundary validation for persisted monetary values.
//

import Foundation

/// Validation failures for a monetary amount entering the ledger.
public enum MoneyValidationError: LocalizedError, Equatable, Sendable {
    case amountMustBePositive
    case amountMustBeFinite
    case unsupportedCurrencyCode(String)
    case tooManyFractionalDigits(currencyCode: String, maximum: Int)

    public var errorDescription: String? {
        switch self {
        case .amountMustBePositive:
            return "Amount must be greater than zero."
        case .amountMustBeFinite:
            return "Amount must be a finite number."
        case .unsupportedCurrencyCode(let code):
            return "Currency code '\(code)' is not supported."
        case .tooManyFractionalDigits(let code, let maximum):
            return "Amount for \(code) may have at most \(maximum) fractional digits."
        }
    }
}

/// Exact Decimal validation shared by manual, import, and split persistence paths.
public enum MoneyValidation {
    /// Validates a positive amount without changing or rounding it.
    ///
    /// The supported currency's fraction scale comes from `CurrencyFormatter`, so
    /// this helper does not introduce a second currency/default policy.
    public static func validate(amount: Decimal, currencyCode: String) throws {
        guard !amount.isNaN else {
            throw MoneyValidationError.amountMustBeFinite
        }
        guard amount > .zero else {
            throw MoneyValidationError.amountMustBePositive
        }

        let normalizedCode = currencyCode.uppercased()
        guard currencyCode == normalizedCode,
              Locale.commonISOCurrencyCodes.contains(normalizedCode) else {
            throw MoneyValidationError.unsupportedCurrencyCode(currencyCode)
        }

        let scale = CurrencyFormatter.fractionDigits(for: normalizedCode)
        var source = amount
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &source, scale, .plain)
        guard rounded == amount else {
            throw MoneyValidationError.tooManyFractionalDigits(
                currencyCode: normalizedCode,
                maximum: scale
            )
        }
    }

    /// Unlabeled convenience form for callers that already have a currency code.
    public static func validate(_ amount: Decimal, currencyCode: String) throws {
        try validate(amount: amount, currencyCode: currencyCode)
    }
}
