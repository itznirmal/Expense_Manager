//
//  BiometricLockView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Full-Screen Biometric Lock Screen (GT-66).
//

import SwiftUI
import LocalAuthentication

/// Full-screen biometric gate displayed when the application is locked via Face ID, Touch ID, or Passcode.
public struct BiometricLockView: View {
    @Environment(\.appState) private var appState
    
    public init() {}
    
    public var body: some View {
        ZStack {
            ColorTokens.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 28) {
                Spacer()
                
                // Hero Lock Icon
                ZStack {
                    Circle()
                        .fill(ColorTokens.brandPrimary.opacity(0.12))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 54, weight: .bold))
                        .foregroundStyle(ColorTokens.brandPrimary)
                }
                
                VStack(spacing: 8) {
                    Text("Expense Manager Locked")
                        .font(Typography.title)
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    Text("Authentication is required to access your private financial records.")
                        .font(Typography.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
                
                PrimaryButton(
                    title: "Unlock App",
                    iconName: "faceid"
                ) {
                    appState.authenticateBiometrics()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            appState.authenticateBiometrics()
        }
    }
}

#Preview {
    BiometricLockView()
        .environment(AppState())
}
