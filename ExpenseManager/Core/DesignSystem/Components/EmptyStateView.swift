//
//  EmptyStateView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Reusable Empty State View with Action Hook.
//

import SwiftUI

public struct EmptyStateView: View {
    public let iconName: String
    public let title: String
    public let message: String
    public let actionTitle: String?
    public let action: (() -> Void)?
    
    public init(
        iconName: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.iconName = iconName
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(ColorTokens.brandPrimary.opacity(0.8))
                .padding()
                .background(ColorTokens.brandPrimary.opacity(0.1))
                .clipShape(Circle())
            
            VStack(spacing: 6) {
                Text(title)
                    .font(Typography.title3)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(Typography.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    action()
                }) {
                    Text(actionTitle)
                        .font(Typography.headline)
                        .foregroundStyle(ColorTokens.brandPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(ColorTokens.brandPrimary.opacity(0.12))
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}

#Preview {
    EmptyStateView(
        iconName: "tray",
        title: "No Transactions Yet",
        message: "Log your first expense manually or use smart text to get started.",
        actionTitle: "Add Transaction"
    ) {}
}
