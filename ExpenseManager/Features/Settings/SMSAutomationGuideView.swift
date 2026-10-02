//
//  SMSAutomationGuideView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Step-by-step Apple Shortcuts SMS Automation Setup Guide.
//

import SwiftUI

public struct SMSAutomationGuideView: View {
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Banner
                    HStack(spacing: 16) {
                        Image(systemName: "bolt.badge.automatic.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(ColorTokens.brandPrimary)
                            .padding(12)
                            .background(ColorTokens.brandPrimary.opacity(0.12))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bank messages with Shortcuts")
                                .font(Typography.headline)
                                .foregroundStyle(ColorTokens.textPrimary)
                            
                            Text("iOS does not let this app read your inbox. You can pass selected message text through an Apple Shortcut.")
                                .font(Typography.subheadline)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    Divider()
                    
                    // Step-by-Step Instructions
                    VStack(alignment: .leading, spacing: 16) {
                        guideStep(
                            number: 1,
                            icon: "app.badge.fill",
                            title: "Open Apple Shortcuts",
                            description: "Launch the native **Shortcuts** app on your iPhone and navigate to the **Automation** tab at the bottom."
                        )
                        
                        guideStep(
                            number: 2,
                            icon: "plus.circle.fill",
                            title: "Create Personal Automation",
                            description: "Tap **+** (New Automation) and select the **Message** trigger."
                        )
                        
                        guideStep(
                            number: 3,
                            icon: "text.bubble.fill",
                            title: "Configure Keywords Trigger",
                            description: "Choose a bank sender or a transaction keyword such as **debited**. Avoid forwarding every message."
                        )
                        
                        guideStep(
                            number: 4,
                            icon: "bolt.fill",
                            title: "Add Expense Manager Action",
                            description: "Search for **Expense Manager** and choose **Parse Text or SMS Expense**. Connect the trigger's message text to its text parameter."
                        )
                        
                        guideStep(
                            number: 5,
                            icon: "checkmark.seal.fill",
                            title: "Test while unlocked",
                            description: "Run with a sample transaction while your iPhone is unlocked. Authentication is required. With App Lock enabled, enter or review the transaction inside the app instead. Automation availability varies with your iOS version."
                        )
                    }
                    
                    // Privacy & Safety Callout (AC-PARSE-2)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(ColorTokens.incomeAccent)
                            Text("Review imported details")
                                .font(Typography.subheadline.weight(.semibold))
                                .foregroundStyle(ColorTokens.textPrimary)
                        }
                        
                        Text("Parsing runs on your device. Safety filters reject recognized OTP and failed-transaction alerts, and duplicate checks reduce repeat imports. Unsupported formats can still be missed or misread. Review the amount, currency, merchant, and account before accepting uncertain results.")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .padding(16)
                    .background(ColorTokens.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(20)
            }
            .navigationTitle("SMS Automation Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func guideStep(number: Int, icon: String, title: String, description: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(ColorTokens.brandPrimary)
                    .frame(width: 28, height: 28)
                
                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.brandPrimary)
                    
                    Text(title)
                        .font(Typography.headline)
                        .foregroundStyle(ColorTokens.textPrimary)
                }
                
                Text(description)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    SMSAutomationGuideView()
}
