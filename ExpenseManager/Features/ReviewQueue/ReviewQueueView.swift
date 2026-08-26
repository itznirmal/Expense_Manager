//
//  ReviewQueueView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Confidence Review Queue & Ingestion Diagnostic Triage View.
//

import SwiftUI

public struct ReviewQueueView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appState) private var appState
    @Environment(\.dependencyContainer) private var container
    
    @State private var viewModel = ReviewQueueViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Segmented Picker & Batch Action
                topFilterBar
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(ColorTokens.backgroundSecondary)
                
                // List of Pending Review Cards
                if viewModel.filteredCandidates.isEmpty {
                    emptyQueueView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.filteredCandidates) { candidate in
                                reviewCandidateCard(candidate)
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(ColorTokens.backgroundPrimary)
            .navigationTitle("Review Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(item: $viewModel.candidateToEdit) { candidate in
                ManualTransactionComposerView(candidate: candidate)
            }
            .task {
                await viewModel.loadQueue(container: container)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var topFilterBar: some View {
        VStack(spacing: 10) {
            Picker("Filter", selection: $viewModel.selectedFilter) {
                ForEach(ReviewQueueViewModel.FilterTier.allCases) { tier in
                    Text(tier.rawValue).tag(tier)
                }
            }
            .pickerStyle(.segmented)
            
            if viewModel.highConfidenceEligibleCount > 0 {
                Button(action: {
                    Task {
                        await viewModel.acceptAllEligible(container: container, appState: appState)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Accept All High Confidence (\(viewModel.highConfidenceEligibleCount))")
                    }
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(ColorTokens.incomeAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(ColorTokens.incomeAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
    
    private func reviewCandidateCard(_ candidate: TransactionCandidate) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                // Header: Source, Date, Confidence Badge
                HStack {
                    Label(candidate.source.displayName, systemImage: candidate.source.iconName)
                        .font(Typography.caption2.weight(.medium))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(ColorTokens.backgroundPrimary)
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    confidenceBadge(candidate.confidence)
                }
                
                // Merchant & Amount Row
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(candidate.merchantName.isEmpty ? "Unknown Merchant" : candidate.merchantName)
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
                        type: candidate.type == .expense ? .expense : (candidate.type == .income ? .income : .transfer),
                        size: .large
                    )
                }
                
                // Account & Category metadata
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.brandPrimary)
                        Text(candidate.categorySuggestion ?? "Uncategorized")
                            .font(Typography.caption.weight(.medium))
                            .foregroundStyle(candidate.categorySuggestion == nil ? ColorTokens.warningAccent : ColorTokens.textPrimary)
                    }
                    
                    Text("•")
                        .foregroundStyle(ColorTokens.textTertiary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.brandPrimary)
                        Text(candidate.accountSuggestion ?? "No Account")
                            .font(Typography.caption.weight(.medium))
                            .foregroundStyle(candidate.accountSuggestion == nil ? ColorTokens.warningAccent : ColorTokens.textPrimary)
                    }
                }
                
                // "Why this needs review" Warnings
                if !candidate.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Why this needs review:")
                            .font(Typography.caption2.weight(.bold))
                            .foregroundStyle(ColorTokens.textSecondary)
                        
                        ForEach(candidate.warnings, id: \.self) { warning in
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(ColorTokens.warningAccent)
                                Text(warning)
                                    .font(Typography.caption2)
                                    .foregroundStyle(ColorTokens.textPrimary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(ColorTokens.warningAccent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                
                Divider()
                
                // Action Buttons: Accept, Edit, Discard
                HStack(spacing: 10) {
                    Button(action: {
                        Task {
                            await viewModel.discardCandidate(candidate, container: container, appState: appState)
                        }
                    }) {
                        Text("Discard")
                            .font(Typography.subheadline.weight(.medium))
                            .foregroundStyle(ColorTokens.criticalAccent)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                    }
                    
                    Button(action: {
                        viewModel.startEditing(candidate)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                        .font(Typography.subheadline.weight(.semibold))
                        .foregroundStyle(ColorTokens.brandPrimary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(ColorTokens.brandPrimary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            await viewModel.acceptCandidate(candidate, container: container, appState: appState)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                            Text("Accept")
                        }
                        .font(Typography.subheadline.weight(.semibold))
                        .foregroundStyle(Color.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(ColorTokens.incomeAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }
    
    private var emptyQueueView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(ColorTokens.incomeAccent)
            
            Text("All Caught Up!")
                .font(Typography.title2)
                .foregroundStyle(ColorTokens.textPrimary)
            
            Text("No transactions currently need review. New incoming transactions from SMS, OCR, and Smart Text will appear here if ambiguous.")
                .font(Typography.subheadline)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func confidenceBadge(_ score: ConfidenceScore) -> some View {
        let (title, color) = badgeDetails(for: score)
        let percent = Int(score.value * 100)
        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(title) (\(percent)%)")
                .font(Typography.caption2.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
    
    private func badgeDetails(for score: ConfidenceScore) -> (String, Color) {
        switch score.tier {
        case .high:
            return ("High", ColorTokens.incomeAccent)
        case .medium:
            return ("Medium", ColorTokens.warningAccent)
        case .low:
            return ("Low", ColorTokens.criticalAccent)
        }
    }
}

#Preview {
    ReviewQueueView()
        .environment(AppState())
        .environment(\.dependencyContainer, .mock())
}
