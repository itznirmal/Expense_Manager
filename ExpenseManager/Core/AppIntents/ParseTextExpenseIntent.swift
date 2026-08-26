//
//  ParseTextExpenseIntent.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  AppIntent for Natural Language & SMS Text Ingestion via Siri & Shortcuts.
//

import Foundation
import AppIntents
import SwiftData

/// Apple AppIntent for parsing raw natural language strings or SMS bank notifications directly from Shortcuts Automations or Siri.
public struct ParseTextExpenseIntent: AppIntent {
    
    public static var title: LocalizedStringResource = "Parse Text or SMS Expense"
    public static var description = IntentDescription("Parses natural language or bank SMS text, automatically logging high-confidence items or adding them to the review queue.")
    public static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Text", description: "The expense description or raw bank SMS text")
    public var text: String
    
    public init() {}
    
    public init(text: String) {
        self.text = text
    }
    
    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "Please provide a valid text string to parse.")
        }
        
        let container = DatabaseContainer.shared.container
        let txnService = SwiftDataTransactionService(modelContainer: container)
        let ruleService = MerchantRuleService(modelContainer: container)
        let fingerprintService = ImportFingerprintService(modelContainer: container)
        
        let orchestrator = SMSIngestionOrchestrator(
            transactionService: txnService,
            merchantRuleService: ruleService,
            fingerprintService: fingerprintService
        )
        
        let result = try await orchestrator.ingest(smsText: trimmed, autoSaveIfEligible: true)
        
        switch result {
        case .saved(let candidate, _):
            let formatted = CurrencyFormatter.shared.format(amount: candidate.amount)
            return .result(dialog: "Logged \(formatted) at \(candidate.merchantName).")
            
        case .duplicate(let reason, let candidate):
            let formatted = CurrencyFormatter.shared.format(amount: candidate.amount)
            return .result(dialog: "Skipped: \(reason) (\(formatted) at \(candidate.merchantName)).")
            
        case .reviewRequired(let candidate, _):
            let formatted = CurrencyFormatter.shared.format(amount: candidate.amount)
            return .result(dialog: "Parsed \(formatted) for \(candidate.merchantName). Added to Review Queue for confirmation.")
            
        case .rejected(let reason, _):
            return .result(dialog: "Ignored: \(reason)")
        }
    }
}
