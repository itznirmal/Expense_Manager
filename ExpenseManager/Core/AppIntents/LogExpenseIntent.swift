//
//  LogExpenseIntent.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  AppIntent for Structured Expense Logging via Siri & Shortcuts.
//

import Foundation
import AppIntents
import SwiftData

/// Apple AppIntent enabling users, Siri, and Shortcuts to log structured expenses with precise decimal amounts.
public struct LogExpenseIntent: AppIntent {
    
    public static var title: LocalizedStringResource = "Log Expense"
    public static var description = IntentDescription("Quickly log an expense transaction with amount, merchant, and optional category.")
    public static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Amount", description: "The amount spent (e.g. 250.00)")
    public var amount: Double
    
    @Parameter(title: "Merchant", description: "Where the money was spent (e.g. Swiggy, Uber, Starbucks)")
    public var merchant: String
    
    @Parameter(title: "Category", description: "Optional category name (e.g. Food, Travel, Shopping)")
    public var category: String?
    
    @Parameter(title: "Account", description: "Optional account or card name (e.g. HDFC Bank, Cash)")
    public var account: String?
    
    @Parameter(title: "Notes", description: "Optional transaction notes or remarks")
    public var notes: String?
    
    public init() {}
    
    public init(
        amount: Double,
        merchant: String,
        category: String? = nil,
        account: String? = nil,
        notes: String? = nil
    ) {
        self.amount = amount
        self.merchant = merchant
        self.category = category
        self.account = account
        self.notes = notes
    }
    
    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            return .result(dialog: "Please provide an amount greater than 0.")
        }
        
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMerchant.isEmpty else {
            return .result(dialog: "Please provide a valid merchant name.")
        }
        
        // Exact decimal conversion without precision loss
        let exactAmount = Decimal(string: "\(amount)") ?? Decimal(amount)
        
        let container = DatabaseContainer.shared.container
        let txnService = SwiftDataTransactionService(modelContainer: container)
        let fingerprintService = ImportFingerprintService(modelContainer: container)
        
        let candidate = TransactionCandidate(
            id: UUID(),
            type: .expense,
            amount: exactAmount,
            currencyCode: CurrencyFormatter.defaultCurrencyCode,
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
        
        do {
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
            
            let formatted = CurrencyFormatter.shared.format(amount: exactAmount)
            return .result(dialog: "Logged \(formatted) at \(trimmedMerchant).")
        } catch {
            return .result(dialog: "Failed to log expense: \(error.localizedDescription)")
        }
    }
}
