//
//  PrimaryButton.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Reusable HIG Compliant Primary Action Button.
//

import SwiftUI

public struct PrimaryButton: View {
    public let title: String
    public let iconName: String?
    public let style: ButtonVariant
    public let isLoading: Bool
    public let isEnabled: Bool
    public let action: () -> Void
    
    public enum ButtonVariant {
        case primary
        case secondary
        case destructive
        case tinted
    }
    
    public init(
        title: String,
        iconName: String? = nil,
        style: ButtonVariant = .primary,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.iconName = iconName
        self.style = style
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            guard isEnabled && !isLoading else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                } else if let iconName = iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Text(title)
                    .font(Typography.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(borderColor, lineWidth: style == .secondary ? 1.5 : 0)
            )
            .opacity(isEnabled ? 1.0 : 0.5)
        }
        .disabled(!isEnabled || isLoading)
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return ColorTokens.brandPrimary
        case .secondary:
            return Color.clear
        case .destructive:
            return ColorTokens.criticalAccent
        case .tinted:
            return ColorTokens.brandPrimary.opacity(0.15)
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive:
            return .white
        case .secondary:
            return ColorTokens.brandPrimary
        case .tinted:
            return ColorTokens.brandPrimary
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .secondary:
            return ColorTokens.brandPrimary
        default:
            return .clear
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Save Transaction", iconName: "checkmark") {}
        PrimaryButton(title: "Cancel", style: .secondary) {}
        PrimaryButton(title: "Delete Account", iconName: "trash", style: .destructive) {}
        PrimaryButton(title: "Processing...", isLoading: true) {}
    }
    .padding()
    .background(ColorTokens.backgroundPrimary)
}
