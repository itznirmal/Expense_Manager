//
//  AccountType.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Account Classification Types.
//

import Foundation

/// Types of accounts supported by the financial ledger.
public enum AccountType: String, Codable, CaseIterable, Sendable {
    case cash
    case bank
    case creditCard
    case savings
    case investment
    case wallet
    case other
    
    public var displayName: String {
        switch self {
        case .cash: return "Cash"
        case .bank: return "Bank Account"
        case .creditCard: return "Credit Card"
        case .savings: return "Savings Account"
        case .investment: return "Investment"
        case .wallet: return "Digital Wallet"
        case .other: return "Other"
        }
    }
    
    public var iconName: String {
        switch self {
        case .cash: return "banknote"
        case .bank: return "building.columns.fill"
        case .creditCard: return "creditcard.fill"
        case .savings: return "banknote.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .wallet: return "wallet.pass.fill"
        case .other: return "archivebox.fill"
        }
    }
}
