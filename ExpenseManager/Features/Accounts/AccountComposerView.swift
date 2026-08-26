//
//  AccountComposerView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Modal Sheet for Creating and Editing Financial Accounts.
//

import SwiftUI

public struct AccountComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appState) private var appState
    @Environment(\.dependencyContainer) private var container
    
    private let editingAccount: AccountDTO?
    
    @State private var name: String = ""
    @State private var type: AccountType = .bank
    @State private var balanceText: String = ""
    @State private var currencyCode: String = CurrencyFormatter.defaultCurrencyCode
    @State private var lastFour: String = ""
    @State private var selectedIcon: String = "building.columns.fill"
    @State private var selectedColorToken: String = "blue"
    @State private var isArchived: Bool = false
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil
    
    private let availableIcons: [String] = [
        "building.columns.fill", "creditcard.fill", "banknote.fill", "wallet.pass.fill",
        "chart.line.uptrend.xyaxis", "indianrupeesign.circle.fill", "dollarsign.circle.fill",
        "shield.fill", "lock.shield.fill", "briefcase.fill", "house.fill", "cart.fill"
    ]
    
    private let availableColorTokens: [String] = [
        "blue", "green", "purple", "orange", "red", "teal", "indigo", "yellow", "pink", "gray"
    ]
    
    public init(account: AccountDTO? = nil) {
        self.editingAccount = account
        _name = State(initialValue: account?.name ?? "")
        _type = State(initialValue: account?.type ?? .bank)
        _balanceText = State(initialValue: account != nil ? "\(account!.balance)" : "")
        _currencyCode = State(initialValue: account?.currencyCode ?? CurrencyFormatter.defaultCurrencyCode)
        _lastFour = State(initialValue: account?.lastFour ?? "")
        _selectedIcon = State(initialValue: account?.icon ?? "building.columns.fill")
        _selectedColorToken = State(initialValue: account?.colorToken ?? "blue")
        _isArchived = State(initialValue: account?.isArchived ?? false)
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                // Basic Info
                Section("Account Details") {
                    TextField("Account Name (e.g. HDFC Salary)", text: $name)
                    
                    Picker("Account Type", selection: $type) {
                        ForEach(AccountType.allCases, id: \.self) { accType in
                            Text(accType.displayName).tag(accType)
                        }
                    }
                    
                    HStack {
                        Text("Current Balance")
                        Spacer()
                        TextField("0.00", text: $balanceText)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Last 4 Digits (Optional)")
                        Spacer()
                        TextField("4321", text: $lastFour)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                    }
                }
                
                // Visual Theme
                Section("Icon & Color") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Icon")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(availableIcons, id: \.self) { icon in
                                    Button(action: {
                                        selectedIcon = icon
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }) {
                                        Image(systemName: icon)
                                            .font(.system(size: 20))
                                            .frame(width: 44, height: 44)
                                            .foregroundStyle(selectedIcon == icon ? Color.white : ColorTokens.textPrimary)
                                            .background(selectedIcon == icon ? ColorTokens.color(for: selectedColorToken) : ColorTokens.backgroundTertiary)
                                            .clipShape(Circle())
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        Text("Color")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .padding(.top, 6)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(availableColorTokens, id: \.self) { token in
                                    Button(action: {
                                        selectedColorToken = token
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }) {
                                        Circle()
                                            .fill(ColorTokens.color(for: token))
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: selectedColorToken == token ? 3 : 0)
                                            )
                                            .shadow(color: selectedColorToken == token ? Color.black.opacity(0.2) : .clear, radius: 4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                if editingAccount != nil {
                    Section("Archive") {
                        Toggle("Archived Account", isOn: $isArchived)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.criticalAccent)
                    }
                }
            }
            .navigationTitle(editingAccount == nil ? "New Account" : "Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveAccount()
                        }
                    }
                    .font(Typography.headline)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }
    
    private func saveAccount() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Please provide an account name."
            return
        }
        
        let parsedBalance = CurrencyFormatter.shared.parse(from: balanceText) ?? .zero
        let trimmedLastFour = lastFour.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedLastFour = trimmedLastFour.isEmpty ? nil : String(trimmedLastFour.suffix(4))
        
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        
        do {
            if let existing = editingAccount {
                var updated = existing
                updated.name = trimmedName
                updated.type = type
                updated.balance = parsedBalance
                updated.currencyCode = currencyCode
                updated.icon = selectedIcon
                updated.colorToken = selectedColorToken
                updated.lastFour = resolvedLastFour
                updated.isArchived = isArchived
                
                try await container.accountService.updateAccount(updated)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                appState.showToast(title: "Account Updated", message: "\(trimmedName) saved", type: .success)
            } else {
                try await container.accountService.createAccount(
                    name: trimmedName,
                    type: type,
                    openingBalance: parsedBalance,
                    currencyCode: currencyCode,
                    icon: selectedIcon,
                    colorToken: selectedColorToken,
                    lastFour: resolvedLastFour
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                appState.showToast(title: "Account Created", message: "\(trimmedName) ready", type: .success)
            }
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

#Preview {
    AccountComposerView()
        .environment(AppState())
        .environment(\.dependencyContainer, .mock())
}
