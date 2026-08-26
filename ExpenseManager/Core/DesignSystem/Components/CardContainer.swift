//
//  CardContainer.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Elevated HIG Compliant Card Container.
//

import SwiftUI

public struct CardContainer<Content: View>: View {
    public let content: Content
    public let padding: CGFloat
    public let cornerRadius: CGFloat
    public let showBorder: Bool
    
    public init(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 16,
        showBorder: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.showBorder = showBorder
    }
    
    public var body: some View {
        content
            .padding(padding)
            .background(ColorTokens.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(showBorder ? ColorTokens.borderSubtle : Color.clear, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    CardContainer {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Spending")
                .font(Typography.subheadline)
                .foregroundStyle(ColorTokens.textSecondary)
            Text("₹42,580.00")
                .font(Typography.amountLarge)
                .foregroundStyle(ColorTokens.textPrimary)
        }
    }
    .padding()
    .background(ColorTokens.backgroundPrimary)
}
