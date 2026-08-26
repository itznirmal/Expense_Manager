//
//  SmartTextComposerView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Smart Text Natural Language Transaction Composer View.
//

import SwiftUI

public struct SmartTextComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appState) private var appState
    @Environment(\.dependencyContainer) private var container
    
    @State private var viewModel = SmartTextComposerViewModel()
    @FocusState private var isInputFocused: Bool
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Text Input Card
                    inputSection
                    
                    // 2. Parsed Candidate Preview Card
                    if let candidate = viewModel.activeCandidate {
                        candidatePreviewCard(candidate)
                    } else if viewModel.isParsing {
                        parsingPlaceholderCard
                    }
                    
                    // Error Banner
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.criticalAccent)
                            .padding(.horizontal, 8)
                    }
                }
                .padding()
            }
            .background(ColorTokens.backgroundPrimary)
            .navigationTitle("Smart Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showFullEditor) {
                if let candidate = viewModel.activeCandidate {
                    ManualTransactionComposerView(candidate: candidate)
                }
            }
            .task {
                await viewModel.loadDependencies(container: container)
                isInputFocused = true
            }
        }
    }
    
    // MARK: - Subviews
    
    private var inputSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Natural Language Entry", systemImage: "sparkles")
                        .font(Typography.subheadline.weight(.semibold))
                        .foregroundStyle(ColorTokens.brandPrimary)
                    
                    Spacer()
                    
                    if viewModel.isParsing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                TextField("e.g. Swiggy 520, Salary 85000 today, Uber 460 from HDFC", text: $viewModel.inputText, axis: .vertical)
                    .font(Typography.body)
                    .lineLimit(2...4)
                    .focused($isInputFocused)
                    .padding(12)
                    .background(ColorTokens.backgroundPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onChange(of: viewModel.inputText) { _, newValue in
                        viewModel.handleInputChanged(newValue, parserService: container.parserService)
                    }
                
                // Quick Example Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        exampleChip("Swiggy 520")
                        exampleChip("Salary 85000 today")
                        exampleChip("Uber 460 from HDFC")
                        exampleChip("Starbucks 350 yesterday")
                        exampleChip("Transferred 5000 to Savings")
                    }
                }
            }
        }
    }
    
    private func exampleChip(_ text: String) -> some View {
        Button(action: {
            viewModel.applyExample(text, parserService: container.parserService)
        }) {
            Text(text)
                .font(Typography.caption.weight(.medium))
                .foregroundStyle(ColorTokens.brandPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(ColorTokens.brandPrimary.opacity(0.12))
                .clipShape(Capsule())
        }
    }
    
    private func candidatePreviewCard(_ candidate: TransactionCandidate) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Parsed Transaction")
                    .font(Typography.headline)
                    .foregroundStyle(ColorTokens.textPrimary)
                
                Spacer()
                
                confidenceTierBadge(candidate.confidence)
            }
            .padding(.horizontal, 4)
            
            CardContainer {
                VStack(spacing: 16) {
                    // Top: Merchant & Amount
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.merchantName.isEmpty ? "Unknown" : candidate.merchantName)
                                .font(Typography.title3)
                                .foregroundStyle(ColorTokens.textPrimary)
                            
                            Text(DateFormatterHelper.shared.relativeDateString(for: candidate.transactionDate))
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                        
                        Spacer()
                        
                        AmountBadgeView(
                            amount: candidate.amount,
                            currencyCode: candidate.currencyCode,
                            type: badgeType(for: candidate.type),
                            size: .large
                        )
                    }
                    
                    Divider()
                    
                    // Middle: Category & Account Pickers
                    HStack(spacing: 16) {
                        // Category Picker Menu
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Category")
                                .font(Typography.caption2.weight(.medium))
                                .foregroundStyle(ColorTokens.textSecondary)
                            
                            Menu {
                                ForEach(viewModel.availableCategories) { cat in
                                    Button(cat.name) {
                                        viewModel.overrideCategoryID = cat.name
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(viewModel.overrideCategoryID ?? "General")
                                        .font(Typography.subheadline.weight(.semibold))
                                        .foregroundStyle(ColorTokens.brandPrimary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 10))
                                        .foregroundStyle(ColorTokens.brandPrimary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                            .frame(height: 30)
                        
                        // Account Picker Menu
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Account")
                                .font(Typography.caption2.weight(.medium))
                                .foregroundStyle(ColorTokens.textSecondary)
                            
                            Menu {
                                ForEach(viewModel.availableAccounts) { acc in
                                    Button(acc.name) {
                                        viewModel.overrideAccountID = acc.name
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(viewModel.overrideAccountID ?? "Default Account")
                                        .font(Typography.subheadline.weight(.semibold))
                                        .foregroundStyle(ColorTokens.brandPrimary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 10))
                                        .foregroundStyle(ColorTokens.brandPrimary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Diagnostic Warnings (if any)
                    if !candidate.warnings.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(candidate.warnings, id: \.self) { warning in
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(ColorTokens.warningAccent)
                                    Text(warning)
                                        .font(Typography.caption2)
                                        .foregroundStyle(ColorTokens.textSecondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(ColorTokens.warningAccent.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    
                    // Category Rule Memory Prompt (if user modified category)
                    if viewModel.hasOverriddenCategory && !candidate.merchantName.isEmpty {
                        Toggle(isOn: $viewModel.rememberCategoryRule) {
                            Text("Always categorize \(candidate.merchantName) as \(viewModel.overrideCategoryID ?? "")")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textPrimary)
                        }
                        .tint(ColorTokens.brandPrimary)
                        .padding(.top, 4)
                    }
                }
            }
            
            // Actions: Save Button & Edit Full Details
            VStack(spacing: 10) {
                PrimaryButton(
                    title: "Confirm & Save",
                    iconName: "checkmark",
                    style: .primary,
                    isLoading: viewModel.isSaving,
                    isEnabled: candidate.amount > 0
                ) {
                    Task {
                        let success = await viewModel.saveTransaction(container: container, appState: appState)
                        if success {
                            dismiss()
                        }
                    }
                }
                
                Button(action: {
                    viewModel.showFullEditor = true
                }) {
                    Text("Edit Full Details")
                        .font(Typography.subheadline.weight(.medium))
                        .foregroundStyle(ColorTokens.brandPrimary)
                        .padding(.vertical, 8)
                }
            }
        }
    }
    
    private var parsingPlaceholderCard: some View {
        CardContainer {
            HStack(spacing: 12) {
                ProgressView()
                Text("Analyzing transaction details...")
                    .font(Typography.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
        }
    }
    
    private func confidenceTierBadge(_ score: ConfidenceScore) -> some View {
        let (title, color) = tierDetails(for: score)
        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(Typography.caption2.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
    
    private func tierDetails(for score: ConfidenceScore) -> (String, Color) {
        switch score.tier {
        case .high:
            return ("High Confidence", ColorTokens.incomeAccent)
        case .medium:
            return ("Review Recommended", ColorTokens.warningAccent)
        case .low:
            return ("Review Required", ColorTokens.criticalAccent)
        }
    }
    
    private func badgeType(for type: TransactionType) -> AmountBadgeView.TransactionBadgeType {
        switch type {
        case .expense: return .expense
        case .income: return .income
        case .transfer: return .transfer
        case .refund: return .refund
        case .cashWithdrawal, .unknown: return .neutral
        }
    }
}

#Preview {
    SmartTextComposerView()
        .environment(AppState())
        .environment(\.dependencyContainer, .mock())
}
