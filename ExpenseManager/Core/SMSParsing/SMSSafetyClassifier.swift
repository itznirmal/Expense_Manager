//
//  SMSSafetyClassifier.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Strict SMS Safety Classifier enforcing AC-PARSE-2 (Rejection of Non-Transactions).
//

import Foundation

/// Safety evaluation result containing classification, safety pass boolean, and rejection rationale.
public struct SMSSafetyResult: Equatable, Sendable {
    public let messageType: SMSMessageType
    public let isSafeForTransactionGeneration: Bool
    public let rejectionReason: String?
    public let matchedRule: String
    
    public init(
        messageType: SMSMessageType,
        isSafeForTransactionGeneration: Bool,
        rejectionReason: String? = nil,
        matchedRule: String = "Default"
    ) {
        self.messageType = messageType
        self.isSafeForTransactionGeneration = isSafeForTransactionGeneration
        self.rejectionReason = rejectionReason
        self.matchedRule = matchedRule
    }
}

/// Strict deterministic classifier that categorizes SMS messages and guarantees that OTPs, failed/declined transactions,
/// marketing spam, card blocks, and balance queries NEVER create financial transactions.
public struct SMSSafetyClassifier: Sendable {
    
    public init() {}
    
    /// Classifies an incoming SMS message text with strict rule precedence.
    public static func classify(text: String) -> SMSSafetyResult {
        let cleaned = InputNormalizer.normalize(text)
        guard !cleaned.isEmpty else {
            return SMSSafetyResult(
                messageType: .unknown,
                isSafeForTransactionGeneration: false,
                rejectionReason: "Empty text",
                matchedRule: "EmptyInput"
            )
        }
        
        let lower = cleaned.lowercased()
        
        // 1. RULE: OTP & Verification Security Check (Highest Priority)
        if isOTP(lower) {
            return SMSSafetyResult(
                messageType: .otp,
                isSafeForTransactionGeneration: false,
                rejectionReason: SMSMessageType.otp.rejectionReason,
                matchedRule: "OTP_Regex"
            )
        }
        
        // 2. RULE: Card Blocked & Security Alerts
        if isCardBlockedOrSecurity(lower) {
            return SMSSafetyResult(
                messageType: .cardBlocked,
                isSafeForTransactionGeneration: false,
                rejectionReason: SMSMessageType.cardBlocked.rejectionReason,
                matchedRule: "CardBlocked_Regex"
            )
        }
        
        // 3. RULE: Failed & Declined Transactions
        if isDeclinedTransaction(lower) {
            return SMSSafetyResult(
                messageType: .declinedTransaction,
                isSafeForTransactionGeneration: false,
                rejectionReason: SMSMessageType.declinedTransaction.rejectionReason,
                matchedRule: "Declined_Regex"
            )
        }
        if isFailedTransaction(lower) {
            return SMSSafetyResult(
                messageType: .failedTransaction,
                isSafeForTransactionGeneration: false,
                rejectionReason: SMSMessageType.failedTransaction.rejectionReason,
                matchedRule: "Failed_Regex"
            )
        }
        
        // 4. RULE: Marketing & Promotional Ads
        if isMarketingSpam(lower) {
            return SMSSafetyResult(
                messageType: .spamMarketing,
                isSafeForTransactionGeneration: false,
                rejectionReason: SMSMessageType.spamMarketing.rejectionReason,
                matchedRule: "Marketing_Regex"
            )
        }
        
        // 5. RULE: Credit Card Bill & Due Date Reminders
        if isBillDueReminder(lower) {
            return SMSSafetyResult(
                messageType: .billDueReminder,
                isSafeForTransactionGeneration: false,
                rejectionReason: SMSMessageType.billDueReminder.rejectionReason,
                matchedRule: "BillDue_Regex"
            )
        }
        
        // 6. RULE: Balance Inquiries / Account Alerts without financial movements
        if isBalanceOnlyAlert(lower) {
            return SMSSafetyResult(
                messageType: .balanceAlert,
                isSafeForTransactionGeneration: false,
                rejectionReason: SMSMessageType.balanceAlert.rejectionReason,
                matchedRule: "BalanceAlert_Regex"
            )
        }
        
        // 7. RULE: Transactional Credit (Credited / Received / Deposited / Salary)
        if isTransactionalCredit(lower) {
            return SMSSafetyResult(
                messageType: .transactionalCredit,
                isSafeForTransactionGeneration: true,
                rejectionReason: nil,
                matchedRule: "Credit_Regex"
            )
        }
        
        // 8. RULE: Transactional Debit (Debited / Spent / Paid / Withdrawn / Sent)
        if isTransactionalDebit(lower) {
            return SMSSafetyResult(
                messageType: .transactionalDebit,
                isSafeForTransactionGeneration: true,
                rejectionReason: nil,
                matchedRule: "Debit_Regex"
            )
        }
        
        // 9. Default Fallback: Unknown
        return SMSSafetyResult(
            messageType: .unknown,
            isSafeForTransactionGeneration: false,
            rejectionReason: SMSMessageType.unknown.rejectionReason,
            matchedRule: "Unknown_Fallback"
        )
    }
    
    // MARK: - Sub-Classifier Heuristics
    
    private static func isOTP(_ text: String) -> Bool {
        let otpPatterns = [
            "\\b(?:otp|one time password|verification code|security code|login code|passcode)\\b",
            "\\b(?:is your secret|valid for|do not share|never share|valid till|expires in)\\b",
            "\\b(?:is the otp for|auth code|authentication code)\\b",
            "\\b(?:use otp|enter otp)\\b",
            "\\b(?:to verify your)\\b"
        ]
        
        // Check for presence of OTP keywords
        for pattern in otpPatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
    
    private static func isCardBlockedOrSecurity(_ text: String) -> Bool {
        let securityPatterns = [
            "\\b(?:card.*blocked|card.*has been blocked|temporarily blocked|card.*locked)\\b",
            "\\b(?:unauthorized transaction|suspicious activity|fraud alert|security alert)\\b",
            "\\b(?:prevent misuse|permanently blocked|deactivated|hotlisted|hotlisting)\\b",
            "\\b(?:if not done by you|report immediately)\\b"
        ]
        for pattern in securityPatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
    
    private static func isDeclinedTransaction(_ text: String) -> Bool {
        let declinedPatterns = [
            "\\b(?:declined|txn declined|transaction declined|was declined|got declined)\\b",
            "\\b(?:due to insufficient|insufficient balance|insufficient funds|limit exceeded|daily limit)\\b",
            "\\b(?:authorization declined|auth declined|payment rejected)\\b"
        ]
        for pattern in declinedPatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
    
    private static func isFailedTransaction(_ text: String) -> Bool {
        let failedPatterns = [
            "\\b(?:failed|payment failed|transaction failed|txn failed|unsuccessful)\\b",
            "\\b(?:could not be processed|not debited|cancelled|aborted|failed to process)\\b"
        ]
        for pattern in failedPatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
    
    private static func isMarketingSpam(_ text: String) -> Bool {
        let marketingPatterns = [
            "\\b(?:pre-approved|pre approved|instant loan|personal loan|apply now|click here)\\b",
            "\\b(?:congratulations.*offer|get.*cashback|use code|voucher worth|special offer)\\b",
            "\\b(?:zero interest|lifetime free|upgrade your card|increase limit to)\\b",
            "\\b(?:discount up to|flat\\s+\\d+% off|limited period offer)\\b",
            "\\b(?:credit limit enhancement|limit increased|enjoy higher limit)\\b"
        ]
        for pattern in marketingPatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
    
    private static func isBillDueReminder(_ text: String) -> Bool {
        let billPatterns = [
            "\\b(?:total amount due|minimum amount due|min amount due|bill is generated)\\b",
            "\\b(?:payment due date|statement for.*card|bill of rs|bill due on)\\b",
            "\\b(?:pay before.*to avoid|due date is|card statement)\\b",
            "\\b(?:emi.*due|emi of rs|upcoming emi|reminder: emi)\\b"
        ]
        for pattern in billPatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
    
    private static func isBalanceOnlyAlert(_ text: String) -> Bool {
        // Must contain balance phrases but NO debit/credit/spent/paid/received action
        let hasBalancePhrase = text.range(
            of: "\\b(?:available balance in|avail bal in|current balance is|avail bal:|balance is rs|avl bal)\\b",
            options: .regularExpression
        ) != nil
        
        let hasDebitOrCreditAction = text.range(
            of: "\\b(?:debited|spent|paid|withdrawn|sent|credited|received|deposited)\\b",
            options: .regularExpression
        ) != nil
        
        return hasBalancePhrase && !hasDebitOrCreditAction
    }
    
    private static func isTransactionalCredit(_ text: String) -> Bool {
        let creditPatterns = [
            "\\b(?:credited|credited with|credited to|credited by)\\b",
            "\\b(?:salary.*credited|received from|deposited in|refund.*credited|added to account|received\\s+(?:rs|inr))\\b"
        ]
        
        for pattern in creditPatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
    
    private static func isTransactionalDebit(_ text: String) -> Bool {
        let debitPatterns = [
            "\\b(?:debited|debited by|debited from|debited for)\\b",
            "\\b(?:spent on|spent at|spent rs|spent inr)\\b",
            "\\b(?:paid to|paid rs|paid inr|paid using)\\b",
            "\\b(?:withdrawn from|withdrawn at|atm cash wdl|cash withdrawal)\\b",
            "\\b(?:sent rs|sent inr|transferred to|tranx of|purchase at)\\b"
        ]
        
        for pattern in debitPatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
}
