//
//  TransactionType.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Core Transaction Direction & Type Enum.
//

import Foundation

/// Defines the accounting direction of a financial event.
public enum TransactionType: String, Codable, CaseIterable, Sendable {
    case expense
    case income
    case refund
    case transfer
    case cashWithdrawal
    case unknown
    
    public var displayName: String {
        switch self {
        case .expense: return "Expense"
        case .income: return "Income"
        case .refund: return "Refund"
        case .transfer: return "Transfer"
        case .cashWithdrawal: return "Cash Withdrawal"
        case .unknown: return "Unknown"
        }
    }
    
    public var iconName: String {
        switch self {
        case .expense: return "arrow.up.right.circle.fill"
        case .income: return "arrow.down.left.circle.fill"
        case .refund: return "arrow.uturn.backward.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        case .cashWithdrawal: return "banknote.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}
