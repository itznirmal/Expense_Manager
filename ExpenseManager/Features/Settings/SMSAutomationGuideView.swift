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
                            Text("Automatic Bank SMS Ingestion")
                                .font(Typography.headline)
                                .foregroundStyle(ColorTokens.textPrimary)
                            
                            Text("Log transactions instantly in the background when your bank sends an SMS.")
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
                            description: "Set *Message Contains* to common bank terms:\n`debited`, `credited`, `spent`, `INR`, `Rs`, `UPI`, `VPA`, `A/c`."
                        )
                        
                        guideStep(
                            number: 4,
                            icon: "bolt.fill",
                            title: "Add Expense Manager Action",
                            description: "Add action: Search for **Expense Manager** and choose **Parse Bank SMS** (or **Log Text Expense**). Connect `Shortcut Input` (the SMS text) to the message parameter."
                        )
                        
                        guideStep(
                            number: 5,
                            icon: "checkmark.seal.fill",
                            title: "Enable Background Execution",
                            description: "Select **Run Immediately** and disable *Notify When Run* so transactions are saved seamlessly in the background."
                        )
                    }
                    
                    // Privacy & Safety Callout (AC-PARSE-2)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(ColorTokens.incomeAccent)
                            Text("Strict Security Guarantees")
                                .font(Typography.subheadline.weight(.semibold))
                                .foregroundStyle(ColorTokens.textPrimary)
                        }
                        
                        Text("• **Zero Internet Transmission**: SMS parsing is 100% on-device.\n• **AC-PARSE-2 Invariant**: OTPs, passwords, declined alerts, spam, and marketing messages are automatically recognized and strictly rejected.\n• **Deduplication**: Duplicate SMS messages within 5 minutes are silently ignored.")
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
