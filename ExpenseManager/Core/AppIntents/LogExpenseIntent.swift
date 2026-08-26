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
        
        // Exact financial conversion
        let exactAmount = Decimal(string: String(format: "%.2f", amount)) ?? Decimal(amount)
        
        let container = DatabaseContainer.shared.modelContainer
        let context = container.mainContext
        
        // Find or infer account
        var matchedAccount: AccountRecord? = nil
        let accountDescriptor = FetchDescriptor<AccountRecord>()
        if let allAccounts = try? context.fetch(accountDescriptor) {
            if let accountName = account, !accountName.isEmpty {
                matchedAccount = allAccounts.first { $0.name.localizedCaseInsensitiveContains(accountName) }
            }
            if matchedAccount == nil {
                matchedAccount = allAccounts.first { $0.isDefault } ?? allAccounts.first
            }
        }
        
        // Find or infer category
        var matchedCategory: CategoryRecord? = nil
        let categoryDescriptor = FetchDescriptor<CategoryRecord>()
        if let allCategories = try? context.fetch(categoryDescriptor) {
            if let categoryName = category, !categoryName.isEmpty {
                matchedCategory = allCategories.first { $0.name.localizedCaseInsensitiveContains(categoryName) }
            }
        }
        
        // Create Transaction Record
        let transactionID = UUID().uuidString
        let transaction = TransactionRecord(
            id: transactionID,
            amount: exactAmount,
            currencyCode: CurrencyFormatter.defaultCurrencyCode,
            typeRawValue: TransactionType.expense.rawValue,
            merchant: trimmedMerchant,
            notes: notes ?? "Logged via Siri / Shortcuts",
            category: matchedCategory,
            account: matchedAccount,
            destinationAccount: nil,
            paymentMethodRawValue: PaymentMethod.upi.rawValue,
            statusRawValue: TransactionStatus.cleared.rawValue,
            transactionDate: Date(),
            source: "siri_intent",
            sourceReference: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        context.insert(transaction)
        
        // Update account balance (Debit for expense)
        if let acc = matchedAccount {
            acc.currentBalance -= exactAmount
            acc.updatedAt = Date()
        }
        
        // Record duplicate fingerprint
        let fingerprintHash = ImportFingerprintService.computeSourceHash(
            amount: exactAmount,
            merchant: trimmedMerchant,
            timestamp: transaction.transactionDate,
            reference: transactionID
        )
        let fingerprint = ImportFingerprintRecord(
            id: UUID().uuidString,
            sourceHash: fingerprintHash,
            amount: exactAmount,
            normalizedMerchant: trimmedMerchant,
            accountLastFour: matchedAccount?.accountNumberMask,
            transactionReference: transactionID,
            approximateTimestamp: transaction.transactionDate,
            source: "app_intent",
            createdAt: Date()
        )
        context.insert(fingerprint)
        
        try? context.save()
        
        let formatted = CurrencyFormatter.shared.format(amount: exactAmount)
        return .result(dialog: "Logged \(formatted) at \(trimmedMerchant).")
    }
}
