//
//  PaymentMethod.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Payment Instrument Identifier.
//

import Foundation

/// Payment instrument used for transactions.
public enum PaymentMethod: String, Codable, CaseIterable, Sendable {
    case upi
    case creditCard
    case debitCard
    case netBanking
    case cash
    case wallet
    case other
    
    public var displayName: String {
        switch self {
        case .upi: return "UPI"
        case .creditCard: return "Credit Card"
        case .debitCard: return "Debit Card"
        case .netBanking: return "Net Banking"
        case .cash: return "Cash"
        case .wallet: return "Digital Wallet"
        case .other: return "Other"
        }
    }
}
