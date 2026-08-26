//
//  PrivacyGuaranteeView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  100% On-Device Privacy Architecture & Security Ledger Modal.
//

import SwiftUI

public struct PrivacyGuaranteeView: View {
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Hero Shield
                    VStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(ColorTokens.incomeAccent)
                        
                        Text("100% On-Device Architecture")
                            .font(Typography.title2)
                            .foregroundStyle(ColorTokens.textPrimary)
                        
                        Text("Expense Manager has zero network permissions, zero cloud servers, and zero third-party telemetry SDKs. Your financial life stays entirely in your hands.")
                            .font(Typography.body)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    // Core Security Pillars
                    VStack(alignment: .leading, spacing: 18) {
                        pillarRow(
                            icon: "server.rack",
                            title: "Zero Network Access",
                            detail: "The application contains NO network stack dependencies, API keys, or internet entitlements. It runs completely offline."
                        )
                        
                        pillarRow(
                            icon: "doc.text.shield.fill",
                            title: "AC-SEC-1 CSV Formula Neutralization",
                            detail: "All exported CSV ledger data is rigorously sanitized. Dangerous formula triggers (=, +, -, @, \\t, \\r) are single-quote escaped to eliminate formula injection exploits in Excel and Numbers."
                        )
                        
                        pillarRow(
                            icon: "key.fill",
                            title: "AC-PARSE-2 Safety Classifier",
                            detail: "Bank SMS parsing discards OTPs, passwords, declined alerts, spam, and promotional ads on-device before any candidate is generated."
                        )
                        
                        pillarRow(
                            icon: "externaldrive.badge.checkmark",
                            title: "Local SwiftData & Checksummed Backups",
                            detail: "Your data is stored in a private local SQLite SwiftData store. Backups are exported as versioned JSON packages signed with SHA-256 integrity hashes."
                        )
                        
                        pillarRow(
                            icon: "mic.slash.fill",
                            title: "Local Voice Processing",
                            detail: "Speech-to-text uses Apple's built-in on-device speech recognizer. Audio streams are never recorded or sent off your iPhone."
                        )
                    }
                }
                .padding(20)
            }
            .navigationTitle("Privacy & Security")
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
    
    private func pillarRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(ColorTokens.incomeAccent)
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Typography.headline)
                    .foregroundStyle(ColorTokens.textPrimary)
                
                Text(detail)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    PrivacyGuaranteeView()
}
