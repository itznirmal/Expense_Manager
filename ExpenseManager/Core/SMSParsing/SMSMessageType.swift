//
//  SMSMessageType.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  SMS Message Classification Types.
//

import Foundation

/// Classification of incoming SMS text messages to enforce safety and prevent non-transaction ingestion.
public enum SMSMessageType: String, CaseIterable, Sendable, Identifiable {
    case transactionalDebit = "Transactional Debit"
    case transactionalCredit = "Transactional Credit"
    case otp = "One-Time Password (OTP)"
    case failedTransaction = "Failed Transaction"
    case declinedTransaction = "Declined Transaction"
    case balanceAlert = "Balance Inquiry / Alert"
    case billDueReminder = "Bill Due / Statement Reminder"
    case spamMarketing = "Promotional / Marketing Offer"
    case cardBlocked = "Card Blocked / Security Notice"
    case unknown = "Unknown / Non-Financial"
    
    public var id: String { rawValue }
    
    /// Strict predicate: Only debit and credit messages are allowed to generate transaction candidates.
    public var isTransactional: Bool {
        switch self {
        case .transactionalDebit, .transactionalCredit:
            return true
        case .otp, .failedTransaction, .declinedTransaction, .balanceAlert, .billDueReminder, .spamMarketing, .cardBlocked, .unknown:
            return false
        }
    }
    
    /// Human-readable safety rejection rationale.
    public var rejectionReason: String? {
        switch self {
        case .transactionalDebit, .transactionalCredit:
            return nil
        case .otp:
            return "Security: OTP verification codes must never be ingested as expenses."
        case .failedTransaction:
            return "Safety: Failed payment attempt was not processed."
        case .declinedTransaction:
            return "Safety: Declined transaction resulted in no monetary debit."
        case .balanceAlert:
            return "Informational: Balance inquiry alert does not represent a transaction."
        case .billDueReminder:
            return "Informational: Credit card bill or utility statement reminder."
        case .spamMarketing:
            return "Safety: Promotional advertisement or pre-approved loan offer."
        case .cardBlocked:
            return "Security: Card lock or fraud warning notification."
        case .unknown:
            return "Unrecognized non-financial message."
        }
    }
    
    /// UI icon for diagnostics sandbox.
    public var iconName: String {
        switch self {
        case .transactionalDebit: return "arrow.up.right.circle.fill"
        case .transactionalCredit: return "arrow.down.left.circle.fill"
        case .otp: return "key.fill"
        case .failedTransaction: return "xmark.circle.fill"
        case .declinedTransaction: return "hand.raised.fill"
        case .balanceAlert: return "banknote.fill"
        case .billDueReminder: return "calendar.badge.clock"
        case .spamMarketing: return "megaphone.fill"
        case .cardBlocked: return "lock.slash.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}
