//
//  ManualTransactionComposerView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Fast 2-3 Second Manual Transaction Entry View.
//

import SwiftUI

public struct ManualTransactionComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appState) private var appState
    @Environment(\.dependencyContainer) private var container
    
    @State private var viewModel: ManualTransactionComposerViewModel
    @FocusState private var isAmountFocused: Bool
    
    public init(candidate: TransactionCandidate? = nil) {
        _viewModel = State(initialValue: ManualTransactionComposerViewModel(candidate: candidate))
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Transaction Type Selector
                    typeSegmentedControl
                    
                    // 2. Hero Amount Card with Quick Presets
                    amountEntryCard
                    
                    // 3. Merchant / Payee Name & Recent Chips
                    merchantSection
                    
                    // 4. Category Grid Selector
                    if !viewModel.isTransfer {
                        categoryGridSection
                    }
                    
                    // 5. Account Selection
                    accountSection
                    
                    // 6. Date & Time Picker
                    dateSection
                    
                    // 7. Notes & Tags (Optional)
                    notesAndTagsSection
                    
                    // 8. Remember Merchant Rule Toggle
                    if !viewModel.merchantName.isEmpty && viewModel.selectedCategoryID != nil {
                        rememberRuleToggle
                    }
                    
                    // Validation Error Banner
                    if let error = viewModel.validationError {
                        Text(error)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.criticalAccent)
                            .padding(.horizontal, 8)
                    }
                    
                    // 9. Save Button
                    PrimaryButton(
                        title: viewModel.isSaving ? "Saving..." : "Save Transaction",
                        iconName: "checkmark",
                        style: .primary,
                        isLoading: viewModel.isSaving,
                        isEnabled: viewModel.canSave
                    ) {
                        Task {
                            let success = await viewModel.saveTransaction(container: container, appState: appState)
                            if success {
                                dismiss()
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
            .background(ColorTokens.backgroundPrimary)
            .navigationTitle("New Transaction")
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
                            let success = await viewModel.saveTransaction(container: container, appState: appState)
                            if success {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canSave || viewModel.isSaving)
                    .fontWeight(.semibold)
                }
            }
            .task {
                await viewModel.loadData(container: container)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var typeSegmentedControl: some View {
        HStack(spacing: 8) {
            typeButton(title: "Expense", type: .expense, icon: "arrow.up.right", color: ColorTokens.expenseAccent)
            typeButton(title: "Income", type: .income, icon: "arrow.down.left", color: ColorTokens.incomeAccent)
            typeButton(title: "Transfer", type: .transfer, icon: "arrow.left.arrow.right", color: ColorTokens.transferAccent)
        }
        .padding(4)
        .background(ColorTokens.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func typeButton(title: String, type: TransactionType, icon: String, color: Color) -> some View {
        let isSelected = viewModel.type == type
        return Button(action: {
            viewModel.type = type
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(Typography.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? color : Color.clear)
            .foregroundStyle(isSelected ? Color.white : ColorTokens.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .animation(.easeInOut(duration: 0.2), value: viewModel.type)
        }
    }
    
    private var amountEntryCard: some View {
        CardContainer {
            VStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("₹")
                        .font(Typography.title.weight(.bold))
                        .foregroundStyle(ColorTokens.textSecondary)
                    
                    TextField("0", text: $viewModel.amountText)
                        .font(Typography.amountHero)
                        .keyboardType(.decimalPad)
                        .focused($isAmountFocused)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .multilineTextAlignment(.leading)
                }
                
                Divider()
                
                // Quick Amount Presets (+100, +500, +1000, +2000)
                HStack(spacing: 8) {
                    presetChip("+100", delta: 100)
                    presetChip("+500", delta: 500)
                    presetChip("+1,000", delta: 1000)
                    presetChip("+2,000", delta: 2000)
                }
            }
        }
    }
    
    private func presetChip(_ title: String, delta: Decimal) -> some View {
        Button(action: {
            viewModel.applyPresetAmount(delta)
        }) {
            Text(title)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(ColorTokens.brandPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(ColorTokens.brandPrimary.opacity(0.1))
                .clipShape(Capsule())
        }
    }
    
    private var merchantSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                Text(viewModel.isTransfer ? "Transfer Description" : "Merchant / Payee")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
                
                TextField(viewModel.isTransfer ? "e.g. Savings transfer" : "e.g. Swiggy, Starbucks, Shell", text: $viewModel.merchantName)
                    .font(Typography.body)
                    .padding(10)
                    .background(ColorTokens.backgroundPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                if !viewModel.recentMerchants.isEmpty && !viewModel.isTransfer {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(viewModel.recentMerchants, id: \.self) { merchant in
                                Button(action: {
                                    viewModel.selectMerchant(merchant)
                                }) {
                                    Text(merchant)
                                        .font(Typography.caption2.weight(.medium))
                                        .foregroundStyle(ColorTokens.textPrimary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(ColorTokens.backgroundSecondary)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(ColorTokens.borderSubtle, lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var categoryGridSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("Category")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
                    ForEach(viewModel.filteredCategories) { category in
                        categoryItem(category)
                    }
                }
            }
        }
    }
    
    private func categoryItem(_ category: CategoryDTO) -> some View {
        let isSelected = viewModel.selectedCategoryID == category.id || viewModel.selectedCategoryID == category.name
        let color = ColorTokens.color(for: category.colorToken)
        
        return Button(action: {
            viewModel.selectedCategoryID = category.id
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? color : color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? Color.white : color)
                }
                
                Text(category.name)
                    .font(Typography.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }
    
    private var accountSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.isTransfer ? "From Account" : "Account")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.availableAccounts) { account in
                            accountChip(account: account, isSelected: viewModel.selectedAccountID == account.id) {
                                viewModel.selectedAccountID = account.id
                            }
                        }
                    }
                }
                
                if viewModel.isTransfer {
                    Divider()
                        .padding(.vertical, 4)
                    
                    Text("To Destination Account")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(ColorTokens.textSecondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(viewModel.availableAccounts) { account in
                                accountChip(account: account, isSelected: viewModel.selectedDestinationAccountID == account.id) {
                                    viewModel.selectedDestinationAccountID = account.id
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func accountChip(account: AccountDTO, isSelected: Bool, onSelect: @escaping () -> Void) -> some View {
        Button(action: {
            onSelect()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            HStack(spacing: 8) {
                Image(systemName: account.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? Color.white : ColorTokens.brandPrimary)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(account.name)
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.white : ColorTokens.textPrimary)
                    
                    if let last4 = account.lastFour {
                        Text("•••• \(last4)")
                            .font(Typography.caption2)
                            .foregroundStyle(isSelected ? Color.white.opacity(0.8) : ColorTokens.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? ColorTokens.brandPrimary : ColorTokens.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.clear : ColorTokens.borderSubtle, lineWidth: 1)
            )
        }
    }
    
    private var dateSection: some View {
        CardContainer {
            DatePicker(
                "Transaction Date",
                selection: $viewModel.transactionDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(Typography.subheadline)
        }
    }
    
    private var notesAndTagsSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                Text("Notes & Tags")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
                
                TextField("Add a note (optional)", text: $viewModel.notes)
                    .font(Typography.body)
                    .padding(10)
                    .background(ColorTokens.backgroundPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                // Tags display & input
                if !viewModel.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(viewModel.tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text("#\(tag)")
                                    .font(Typography.caption2.weight(.medium))
                                Button(action: {
                                    viewModel.removeTag(tag)
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ColorTokens.brandPrimary.opacity(0.12))
                            .foregroundStyle(ColorTokens.brandPrimary)
                            .clipShape(Capsule())
                        }
                    }
                }
                
                HStack {
                    TextField("Add tag", text: $viewModel.tagInput)
                        .font(Typography.caption)
                        .padding(8)
                        .background(ColorTokens.backgroundPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .onSubmit {
                            viewModel.addTag()
                        }
                    
                    Button("Add") {
                        viewModel.addTag()
                    }
                    .font(Typography.caption.weight(.semibold))
                    .disabled(viewModel.tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private var rememberRuleToggle: some View {
        CardContainer {
            Toggle(isOn: $viewModel.rememberRule) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remember Category for \(viewModel.merchantName)")
                        .font(Typography.subheadline.weight(.semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("Automatically apply this category in future Smart Entry & SMS")
                        .font(Typography.caption2)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
            .tint(ColorTokens.brandPrimary)
        }
    }
}

#Preview {
    ManualTransactionComposerView()
        .environment(AppState())
        .environment(\.dependencyContainer, .mock())
}
