//
//  AmountBadgeView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Semantic Transaction Amount Badge Component.
//

import SwiftUI

public struct AmountBadgeView: View {
    public let amount: Decimal
    public let currencyCode: String
    public let type: TransactionBadgeType
    public let size: AmountSize
    
    public enum TransactionBadgeType {
        case expense
        case income
        case transfer
        case refund
        case neutral
    }
    
    public init(
        amount: Decimal,
        currencyCode: String = "INR",
        type: TransactionBadgeType = .expense,
        size: AmountSize = .medium
    ) {
        self.amount = amount
        self.currencyCode = currencyCode
        self.type = type
        self.size = size
    }
    
    public var body: some View {
        Text(formattedText)
            .financialAmountStyle(size: size, color: textColor)
    }
    
    private var formattedText: String {
        let absAmount = amount < 0 ? -amount : amount
        let baseFormatted = CurrencyFormatter.shared.format(
            amount: absAmount,
            currencyCode: currencyCode
        )
        
        switch type {
        case .expense:
            return "-\(baseFormatted)"
        case .income, .refund:
            return "+\(baseFormatted)"
        case .transfer, .neutral:
            return baseFormatted
        }
    }
    
    private var textColor: Color {
        switch type {
        case .expense:
            return ColorTokens.expenseAccent
        case .income:
            return ColorTokens.incomeAccent
        case .transfer:
            return ColorTokens.transferAccent
        case .refund:
            return ColorTokens.refundAccent
        case .neutral:
            return ColorTokens.textPrimary
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        AmountBadgeView(amount: 520, type: .expense, size: .large)
        AmountBadgeView(amount: 85000, type: .income, size: .large)
        AmountBadgeView(amount: 15000, type: .transfer, size: .medium)
        AmountBadgeView(amount: 240, type: .refund, size: .small)
    }
    .padding()
    .background(ColorTokens.backgroundPrimary)
}
