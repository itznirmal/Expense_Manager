//
//  LogExpenseIntent.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  AppIntent for Structured Expense Logging via Siri & Shortcuts.
//

import Foundation
import AppIntents

/// Shared security contract for App Intents that can write or inspect financial data.
/// The App Intent authentication policy authenticates the device; this preference prevents
/// an intent from bypassing the app's own foreground lock screen.
enum ExpenseManagerIntentSecurity {
    static let lockPreferenceKey = "requireBiometrics"
    static let lockedDialog: IntentDialog = "App Lock is enabled. Open Expense Manager and add this expense inside the app."

    static var appLockEnabled: Bool {
        CurrencyFormatter.preferences.bool(forKey: lockPreferenceKey)
    }
}

/// Exact decimal validation for App Intent amount text.
enum ExpenseManagerIntentAmountValidator {
    static func parse(_ rawValue: String, currencyCode: String) -> Decimal? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, isCurrencyCodeValid(currencyCode), isDecimalSyntaxValid(value) else {
            return nil
        }

        guard let amount = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }

        guard !amount.isNaN, amount > .zero else { return nil }
        guard amount.exponent >= -CurrencyFormatter.fractionDigits(for: currencyCode) else { return nil }
        return amount
    }

    static func isCurrencyCodeValid(_ code: String) -> Bool {
        let scalars = Array(code.unicodeScalars)
        return scalars.count == 3 && scalars.allSatisfy { $0.value >= 65 && $0.value <= 90 } &&
            Locale.commonISOCurrencyCodes.contains(code)
    }

    private static func isDecimalSyntaxValid(_ value: String) -> Bool {
        let pattern = "^[0-9]+(?:\\.[0-9]+)?$"
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}

/// Apple AppIntent enabling users, Siri, and Shortcuts to log structured expenses with precise decimal amounts.
public struct LogExpenseIntent: AppIntent {
    
    public static let title: LocalizedStringResource = "Log Expense"
    public static let description = IntentDescription("Quickly log an expense transaction with amount, merchant, and optional category.")
    public static let openAppWhenRun: Bool = true
    public static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }
    
    @Parameter(title: "Amount", description: "The amount spent (e.g. 250.00)")
    public var amount: String

    @Parameter(title: "Currency", description: "Three-letter currency code (e.g. INR, USD)")
    public var currencyCode: String
    
    @Parameter(title: "Merchant", description: "Where the money was spent (e.g. Swiggy, Uber, Starbucks)")
    public var merchant: String
    
    @Parameter(title: "Category", description: "Optional category name (e.g. Food, Travel, Shopping)")
    public var category: String?
    
    @Parameter(title: "Account", description: "Optional account or card name (e.g. HDFC Bank, Cash)")
    public var account: String?
    
    @Parameter(title: "Notes", description: "Optional transaction notes or remarks")
    public var notes: String?
    
    public init() { self.currencyCode = CurrencyFormatter.defaultCurrencyCode }
    
    public init(
        amount: String,
        merchant: String,
        category: String? = nil,
        account: String? = nil,
        notes: String? = nil,
        currencyCode: String = CurrencyFormatter.defaultCurrencyCode
    ) {
        self.amount = amount
        self.merchant = merchant
        self.category = category
        self.account = account
        self.notes = notes
        self.currencyCode = currencyCode
    }
    
    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard !ExpenseManagerIntentSecurity.appLockEnabled else {
            return .result(dialog: ExpenseManagerIntentSecurity.lockedDialog)
        }

        let normalizedCurrency = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let exactAmount = ExpenseManagerIntentAmountValidator.parse(amount, currencyCode: normalizedCurrency) else {
            return .result(dialog: "Enter a positive amount using no more than the currency's supported decimal places.")
        }
        
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMerchant.isEmpty else {
            return .result(dialog: "Please provide a valid merchant name.")
        }

        do {
            let container = try DatabaseContainer.production().container
            let txnService = SwiftDataTransactionService(modelContainer: container)
            let fingerprintService = ImportFingerprintService(modelContainer: container)
            let candidate = TransactionCandidate(
                id: UUID(),
                type: .expense,
                amount: exactAmount,
                currencyCode: normalizedCurrency,
                merchantName: trimmedMerchant,
                categorySuggestion: category?.trimmingCharacters(in: .whitespacesAndNewlines),
                accountSuggestion: account?.trimmingCharacters(in: .whitespacesAndNewlines),
                paymentMethod: .upi,
                transactionDate: Date(),
                notes: notes ?? "Logged via Siri / Shortcuts",
                tags: [],
                source: .siri,
                confidence: .high,
                needsReview: false,
                warnings: []
            )
            let txID = try await txnService.createTransaction(candidate)
            
            // Record duplicate prevention fingerprint
            let sourceHash = ImportFingerprintService.computeSourceHash(
                amount: exactAmount,
                merchant: trimmedMerchant,
                timestamp: candidate.transactionDate,
                reference: txID
            )
            
            try? await fingerprintService.recordFingerprint(
                sourceHash: sourceHash,
                amount: exactAmount,
                merchant: trimmedMerchant,
                accountLastFour: account,
                reference: txID,
                timestamp: candidate.transactionDate,
                source: "siri_intent"
            )
            
            let formatted = CurrencyFormatter.shared.format(amount: exactAmount, currencyCode: normalizedCurrency)
            return .result(dialog: "Logged \(formatted) at \(trimmedMerchant).")
        } catch {
            return .result(dialog: "Failed to log expense: \(error.localizedDescription)")
        }
    }
}
