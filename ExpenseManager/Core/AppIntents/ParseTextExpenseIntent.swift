//
//  ParseTextExpenseIntent.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  AppIntent for Natural Language & SMS Text Ingestion via Siri & Shortcuts.
//

import Foundation
import AppIntents

/// Apple AppIntent for parsing bank transaction messages from a user-configured Shortcuts automation.
/// Generic text entry remains routed through the app's normal parser so raw message text is never
/// persisted by this import path.
public struct ParseTextExpenseIntent: AppIntent {
    
    public static let title: LocalizedStringResource = "Parse Text or SMS Expense"
    public static let description = IntentDescription("Validates a bank transaction message on-device, then logs or queues the sanitized transaction result.")
    public static let openAppWhenRun: Bool = true
    public static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }
    
    @Parameter(title: "Text", description: "The expense description or raw bank SMS text")
    public var text: String
    
    public init() {}
    
    public init(text: String) {
        self.text = text
    }
    
    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard !ExpenseManagerIntentSecurity.appLockEnabled else {
            return .result(dialog: ExpenseManagerIntentSecurity.lockedDialog)
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "Please provide a valid text string to parse.")
        }

        // This intent is the SMS adapter. Classify before constructing persistence services so
        // OTPs, marketing text, balance alerts, and arbitrary prose never reach a generic parser.
        let safety = SMSSafetyClassifier.classify(text: trimmed)
        guard safety.isSafeForTransactionGeneration else {
            return .result(dialog: "Ignored: \(safety.rejectionReason ?? "Message is not a supported transaction alert.")")
        }

        let result: SMSIngestionResult
        do {
            let container = try DatabaseContainer.production().container
            let txnService = SwiftDataTransactionService(modelContainer: container)
            let ruleService = MerchantRuleService(modelContainer: container)
            let fingerprintService = ImportFingerprintService(modelContainer: container)
            let orchestrator = SMSIngestionOrchestrator(
                transactionService: txnService,
                merchantRuleService: ruleService,
                fingerprintService: fingerprintService
            )
            result = try await orchestrator.ingest(smsText: trimmed, autoSaveIfEligible: true)
        } catch {
            return .result(dialog: "Unable to import this message: \(error.localizedDescription)")
        }
        
        switch result {
        case .saved(let candidate, _):
            let formatted = CurrencyFormatter.shared.format(amount: candidate.amount, currencyCode: candidate.currencyCode)
            return .result(dialog: "Logged \(formatted) at \(candidate.merchantName).")
            
        case .duplicate(let reason, let candidate):
            let formatted = CurrencyFormatter.shared.format(amount: candidate.amount, currencyCode: candidate.currencyCode)
            return .result(dialog: "Skipped: \(reason) (\(formatted) at \(candidate.merchantName)).")
            
        case .reviewRequired(let candidate, _):
            let formatted = CurrencyFormatter.shared.format(amount: candidate.amount, currencyCode: candidate.currencyCode)
            return .result(dialog: "Parsed \(formatted) for \(candidate.merchantName). Added to Review Queue for confirmation.")
            
        case .rejected(let reason, _):
            return .result(dialog: "Ignored: \(reason)")
        }
    }
}
