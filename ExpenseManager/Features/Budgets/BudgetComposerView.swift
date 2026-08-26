//
//  BudgetComposerView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Modal Sheet for Setting and Editing Monthly Budget Limits.
//

import SwiftUI

public struct BudgetComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appState) private var appState
    @Environment(\.dependencyContainer) private var container
    
    private let editingBudget: BudgetDTO?
    private let targetMonth: Date
    
    @State private var selectedCategoryID: String? = nil
    @State private var limitAmountText: String = ""
    @State private var alertThreshold: Double = 80.0
    @State private var availableCategories: [CategoryDTO] = []
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil
    
    public init(budget: BudgetDTO? = nil, targetMonth: Date = Date()) {
        self.editingBudget = budget
        self.targetMonth = budget?.month ?? targetMonth
        _selectedCategoryID = State(initialValue: budget?.categoryID)
        _limitAmountText = State(initialValue: budget != nil && budget!.limitAmount > 0 ? "\(budget!.limitAmount)" : "")
        _alertThreshold = State(initialValue: Double(budget?.alertThresholdPercent ?? 80))
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("Budget Target") {
                    Picker("Budget Scope", selection: $selectedCategoryID) {
                        Text("Overall Monthly Budget").tag(String?.none)
                        ForEach(availableCategories) { cat in
                            HStack {
                                Image(systemName: cat.icon)
                                Text(cat.name)
                            }
                            .tag(String?.some(cat.id))
                        }
                    }
                    
                    HStack {
                        Text("Month")
                        Spacer()
                        Text(DateFormatterHelper.shared.monthYear(for: targetMonth))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
                
                Section("Spending Limit") {
                    HStack {
                        Text("Limit Amount")
                        Spacer()
                        TextField("₹0", text: $limitAmountText)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                            .font(Typography.headline)
                    }
                    
                    // Quick amount presets
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            presetButton("+₹2,000", amount: 2000)
                            presetButton("+₹5,000", amount: 5000)
                            presetButton("+₹10,000", amount: 10000)
                            presetButton("+₹25,000", amount: 25000)
                            presetButton("+₹50,000", amount: 50000)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("Alerts & Thresholds") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Warning Alert Threshold")
                            Spacer()
                            Text("\(Int(alertThreshold))%")
                                .font(Typography.headline)
                                .foregroundStyle(ColorTokens.warningAccent)
                        }
                        
                        Slider(value: $alertThreshold, in: 50...100, step: 5)
                            .tint(ColorTokens.warningAccent)
                        
                        Text("You'll receive a warning when spending exceeds \(Int(alertThreshold))% of your limit.")
                            .font(Typography.caption2)
                            .foregroundStyle(ColorTokens.textSecondary)
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
            .navigationTitle(editingBudget == nil ? "Set Budget" : "Edit Budget")
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
                            await saveBudget()
                        }
                    }
                    .font(Typography.headline)
                    .disabled(limitAmount <= .zero || isSaving)
                }
            }
            .task {
                await loadCategories()
            }
        }
    }
    
    private var limitAmount: Decimal {
        CurrencyFormatter.shared.parse(from: limitAmountText) ?? .zero
    }
    
    private func presetButton(_ title: String, amount: Decimal) -> some View {
        Button(action: {
            let current = self.limitAmount
            let newAmount = current + amount
            self.limitAmountText = "\(newAmount)"
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            Text(title)
                .font(Typography.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ColorTokens.backgroundTertiary)
                .foregroundStyle(ColorTokens.brandPrimary)
                .clipShape(Capsule())
        }
    }
    
    private func loadCategories() async {
        do {
            availableCategories = try await container.categoryService.fetchCategories(type: .expense)
        } catch {
            errorMessage = "Failed to load categories: \(error.localizedDescription)"
        }
    }
    
    private func saveBudget() async {
        guard limitAmount > .zero else {
            errorMessage = "Please enter a valid budget amount."
            return
        }
        
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        
        do {
            try await container.budgetService.setBudget(
                categoryID: selectedCategoryID,
                limitAmount: limitAmount,
                month: targetMonth,
                alertThresholdPercent: Int(alertThreshold)
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            appState.showToast(
                title: "Budget Saved",
                message: "\(CurrencyFormatter.shared.format(amount: limitAmount)) for \(DateFormatterHelper.shared.monthYear(for: targetMonth))",
                type: .success
            )
            dismiss()
        } catch {
            errorMessage = "Failed to save budget: \(error.localizedDescription)"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

#Preview {
    BudgetComposerView()
        .environment(AppState())
        .environment(\.dependencyContainer, .mock())
}
