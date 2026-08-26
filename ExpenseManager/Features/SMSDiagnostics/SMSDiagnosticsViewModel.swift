//
//  SMSDiagnosticsViewModel.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Observable ViewModel for SMS Diagnostics & Testing Sandbox.
//

import SwiftUI
import Observation

/// Sample SMS template representation for diagnostic sandbox testing.
public struct SampleSMSTemplate: Identifiable, Sendable {
    public let id = UUID()
    public let title: String
    public let category: String
    public let text: String
    public let expectedSafe: Bool
}

/// ViewModel coordinating interactive SMS parsing diagnostics, safety evaluation, duplicate detection, and confidence scoring.
@Observable
@MainActor
public final class SMSDiagnosticsViewModel {
    
    // MARK: - State Properties
    
    public var inputText: String = ""
    public var safetyResult: SMSSafetyResult? = nil
    public var parsedResult: BankParsedResult? = nil
    public var isDuplicate: Bool = false
    public var duplicateReason: String? = nil
    public var confidenceScore: Double = 0.0
    public var confidenceTier: ConfidenceScore.Tier = .low
    public var diagnosticWarnings: [String] = []
    public var isProcessing: Bool = false
    public var selectedSample: SampleSMSTemplate? = nil
    
    // MARK: - Sample SMS Catalog
    
    public let sampleTemplates: [SampleSMSTemplate] = [
        SampleSMSTemplate(
            title: "HDFC Bank UPI",
            category: "Valid Debit",
            text: "HDFC Bank: Rs 520.00 debited from a/c **4321 on 25-AUG-26 to VPA swiggy@upi (UPI Ref no 482019283741). Avl bal: Rs 15,400.00",
            expectedSafe: true
        ),
        SampleSMSTemplate(
            title: "ICICI Credit Card",
            category: "Valid Debit",
            text: "Tranx of INR 1,299.00 using ICICI Bank Card 5678 done at ZOMATO on 25-Aug-26. Avl Lmt: INR 88,000.00",
            expectedSafe: true
        ),
        SampleSMSTemplate(
            title: "SBI Salary Credit",
            category: "Valid Credit",
            text: "Your A/C XXXXX123456 credited by Rs.50000.00 on 25Aug26 by salary transfer. (Avl Bal Rs:58,450.00) - SBI",
            expectedSafe: true
        ),
        SampleSMSTemplate(
            title: "Axis Bank Blinkit",
            category: "Valid Debit",
            text: "INR 650.00 debited from Axis Bank A/C no. XX9876 on 25-08-2026 to BLINKIT via UPI. Avail Bal: INR 12,300.00",
            expectedSafe: true
        ),
        SampleSMSTemplate(
            title: "SBI ATM Cash WDL",
            category: "Valid ATM",
            text: "Your A/C XXXXX123456 debited by Rs.5000.00 on 25Aug26 at SBI ATM CASH WDL. Avl Bal Rs:3,450.00",
            expectedSafe: true
        ),
        SampleSMSTemplate(
            title: "OTP Verification",
            category: "Rejected Safety",
            text: "492019 is your secret OTP for transaction of INR 1,500.00 at Amazon India. Valid for 10 mins. Do not share with anyone.",
            expectedSafe: false
        ),
        SampleSMSTemplate(
            title: "Declined Payment",
            category: "Rejected Safety",
            text: "Transaction of Rs. 2,400.00 on HDFC Bank Card 9876 was declined due to insufficient balance.",
            expectedSafe: false
        ),
        SampleSMSTemplate(
            title: "Pre-Approved Loan Spam",
            category: "Rejected Spam",
            text: "Congratulations! You are eligible for a pre-approved personal loan of Rs 5,00,000 at zero interest. Apply now.",
            expectedSafe: false
        ),
        SampleSMSTemplate(
            title: "Card Blocked Alert",
            category: "Rejected Security",
            text: "Your Axis Bank Debit Card ending 9876 has been temporarily blocked due to suspicious activity.",
            expectedSafe: false
        ),
        SampleSMSTemplate(
            title: "Bill Due Date Notice",
            category: "Rejected Informational",
            text: "Your ICICI Credit Card statement for Aug is generated. Total amount due: Rs 12,450. Due date: 10-Sep-26.",
            expectedSafe: false
        )
    ]
    
    // MARK: - Dependencies
    
    private let fingerprintService: ImportFingerprintServiceProtocol?
    private let merchantRuleService: MerchantRuleServiceProtocol?
    
    // MARK: - Initializer
    
    public init(
        fingerprintService: ImportFingerprintServiceProtocol? = nil,
        merchantRuleService: MerchantRuleServiceProtocol? = nil
    ) {
        self.fingerprintService = fingerprintService
        self.merchantRuleService = merchantRuleService
    }
    
    // MARK: - Actions
    
    public func loadSample(_ template: SampleSMSTemplate) {
        self.selectedSample = template
        self.inputText = template.text
        analyze()
    }
    
    public func clear() {
        inputText = ""
        safetyResult = nil
        parsedResult = nil
        isDuplicate = false
        duplicateReason = nil
        confidenceScore = 0.0
        confidenceTier = .low
        diagnosticWarnings = []
        selectedSample = nil
    }
    
    public func analyze() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clear()
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // 1. Safety Classification
        let safety = SMSSafetyClassifier.classify(text: trimmed)
        self.safetyResult = safety
        
        guard safety.isSafeForTransactionGeneration else {
            self.parsedResult = nil
            self.isDuplicate = false
            self.duplicateReason = nil
            self.confidenceScore = 0.0
            self.confidenceTier = .low
            self.diagnosticWarnings = [safety.rejectionReason ?? "Rejected by Safety Classifier"]
            return
        }
        
        // 2. Deterministic Bank Parsing
        let parsed = BankSMSParser.parse(smsText: trimmed)
        self.parsedResult = parsed
        
        // 3. Duplicate Check
        if let p = parsed {
            let hash = ImportFingerprintService.computeSourceHash(
                amount: p.amount,
                merchant: p.merchant,
                timestamp: p.date,
                reference: p.referenceNumber
            )
            
            Task {
                if let fpSvc = self.fingerprintService {
                    let hasHash = (try? await fpSvc.hasFingerprint(hash: hash)) ?? false
                    let isWindowDup = (try? await fpSvc.isDuplicate(
                        amount: p.amount,
                        merchant: p.merchant,
                        date: p.date,
                        accountLastFour: p.accountMask,
                        windowSeconds: 300
                    )) ?? false
                    
                    await MainActor.run {
                        self.isDuplicate = hasHash || isWindowDup
                        self.duplicateReason = hasHash ? "Exact SHA-256 Hash Matched" : (isWindowDup ? "5-Minute Time Window Duplicate" : nil)
                    }
                }
            }
            
            // 4. Confidence Evaluation
            let draft = ParsedTransactionDraft(
                type: p.direction,
                amount: p.amount,
                currencyCode: p.currencyCode,
                merchantName: p.merchant,
                inferredCategory: p.inferredCategory,
                accountSuggestion: p.bankName ?? "Bank Account",
                paymentMethod: p.paymentMethod,
                transactionDate: p.date,
                referenceNumber: p.referenceNumber,
                upiVPA: p.upiVPA,
                rawText: trimmed
            )
            
            let eval = ConfidenceEngine.evaluate(draft: draft, source: .sms, hasMatchedRule: false)
            self.confidenceScore = eval.score.value
            self.confidenceTier = eval.score.tier
            self.diagnosticWarnings = eval.warnings
        } else {
            self.confidenceScore = 0.0
            self.confidenceTier = .low
            self.diagnosticWarnings = ["Failed to extract valid amount or transaction fields."]
        }
    }
}
