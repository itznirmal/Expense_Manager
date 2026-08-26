//
//  TransactionDetailView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Detailed Transaction Inspection, Audit Information & Action Modal.
//

import SwiftUI

public struct TransactionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appState) private var appState
    @Environment(\.dependencyContainer) private var container
    
    public let transaction: TransactionCandidate
    public var onEdit: ((TransactionCandidate) -> Void)? = nil
    public var onDelete: ((String) -> Void)? = nil
    
    @State private var isShowingDeleteConfirmation: Bool = false
    
    public init(
        transaction: TransactionCandidate,
        onEdit: ((TransactionCandidate) -> Void)? = nil,
        onDelete: ((String) -> Void)? = nil
    ) {
        self.transaction = transaction
        self.onEdit = onEdit
        self.onDelete = onDelete
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Hero Amount Header
                    heroAmountCard
                    
                    // Transaction Details Section
                    detailsSection
                    
                    // Ingestion & Audit Metadata Section
                    metadataSection
                    
                    // Notes & Tags
                    if !(transaction.notes?.isEmpty ?? true) || !transaction.tags.isEmpty {
                        notesAndTagsSection
                    }
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .padding()
            }
            .background(ColorTokens.backgroundPrimary)
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        dismiss()
                        onEdit?(transaction)
                    }) {
                        Text("Edit")
                            .font(Typography.headline)
                            .foregroundStyle(ColorTokens.brandPrimary)
                    }
                }
            }
            .confirmationDialog(
                "Delete Transaction?",
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Transaction", role: .destructive) {
                    Task {
                        try? await container.transactionService.deleteTransaction(id: transaction.id.uuidString)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        appState.showToast(title: "Transaction Deleted", type: .info)
                        onDelete?(transaction.id.uuidString)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to permanently delete this transaction? Account balances will be automatically adjusted.")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var heroAmountCard: some View {
        CardContainer {
            VStack(spacing: 8) {
                Image(systemName: transaction.type.iconName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(typeColor)
                    .frame(width: 60, height: 60)
                    .background(typeColor.opacity(0.12))
                    .clipShape(Circle())
                
                Text(CurrencyFormatter.shared.format(amount: transaction.amount, currencyCode: transaction.currencyCode))
                    .font(Typography.amountHero)
                    .foregroundStyle(typeColor)
                
                Text(transaction.merchantName.isEmpty ? transaction.type.displayName : transaction.merchantName)
                    .font(Typography.title3.weight(.semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                
                Text(transaction.type.displayName)
                    .font(Typography.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(typeColor.opacity(0.12))
                    .foregroundStyle(typeColor)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
    
    private var detailsSection: some View {
        CardContainer {
            VStack(spacing: 12) {
                detailRow(
                    label: "Category",
                    value: transaction.categorySuggestion ?? "Uncategorized",
                    icon: "tag.fill",
                    iconColor: ColorTokens.brandPrimary
                )
                
                Divider().overlay(ColorTokens.separator)
                
                detailRow(
                    label: transaction.type == .transfer ? "From Account" : "Account",
                    value: transaction.accountSuggestion ?? "Default Account",
                    icon: "building.columns.fill",
                    iconColor: ColorTokens.incomeAccent
                )
                
                if let dest = transaction.destinationAccountSuggestion, transaction.type == .transfer {
                    Divider().overlay(ColorTokens.separator)
                    
                    detailRow(
                        label: "To Account",
                        value: dest,
                        icon: "arrow.right.circle.fill",
                        iconColor: ColorTokens.transferAccent
                    )
                }
                
                Divider().overlay(ColorTokens.separator)
                
                detailRow(
                    label: "Date & Time",
                    value: "\(DateFormatterHelper.shared.shortDate(for: transaction.transactionDate)) at \(DateFormatterHelper.shared.timeOnly(for: transaction.transactionDate))",
                    icon: "calendar",
                    iconColor: ColorTokens.warningAccent
                )
                
                if let payment = transaction.paymentMethod {
                    Divider().overlay(ColorTokens.separator)
                    
                    detailRow(
                        label: "Payment Method",
                        value: payment.displayName,
                        icon: "creditcard.fill",
                        iconColor: ColorTokens.brandSecondary
                    )
                }
            }
        }
    }
    
    private var metadataSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("Source & Ingestion Metadata")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
                
                detailRow(
                    label: "Channel Source",
                    value: transaction.source.displayName,
                    icon: "sparkles",
                    iconColor: ColorTokens.brandPrimary
                )
                
                if let ref = transaction.sourceReference, !ref.isEmpty {
                    Divider().overlay(ColorTokens.separator)
                    detailRow(
                        label: "Reference / UPI VPA",
                        value: ref,
                        icon: "number",
                        iconColor: ColorTokens.textSecondary
                    )
                }
                
                Divider().overlay(ColorTokens.separator)
                
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "gauge.with.needle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.incomeAccent)
                        Text("Confidence Score")
                            .font(Typography.subheadline)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    Spacer()
                    Text("\(Int(transaction.confidence.value * 100))% (\(transaction.confidence.tier.displayName))")
                        .font(Typography.subheadline.weight(.semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                }
                
                if !transaction.warnings.isEmpty {
                    Divider().overlay(ColorTokens.separator)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(transaction.warnings, id: \.self) { warning in
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(ColorTokens.warningAccent)
                                Text(warning)
                                    .font(Typography.caption2)
                                    .foregroundStyle(ColorTokens.warningAccent)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var notesAndTagsSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                if let notes = transaction.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(ColorTokens.textSecondary)
                        Text(notes)
                            .font(Typography.body)
                            .foregroundStyle(ColorTokens.textPrimary)
                    }
                }
                
                if !transaction.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tags")
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(ColorTokens.textSecondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(transaction.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(Typography.caption.weight(.medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(ColorTokens.backgroundTertiary)
                                        .foregroundStyle(ColorTokens.brandPrimary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                isShowingDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Delete Transaction")
                }
                .font(Typography.headline)
                .foregroundStyle(ColorTokens.criticalAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ColorTokens.criticalAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
    
    private func detailRow(label: String, value: String, icon: String, iconColor: Color) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
                Text(label)
                    .font(Typography.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            Spacer()
            Text(value)
                .font(Typography.subheadline.weight(.semibold))
                .foregroundStyle(ColorTokens.textPrimary)
        }
    }
    
    private var typeColor: Color {
        switch transaction.type {
        case .expense: return ColorTokens.expenseAccent
        case .income: return ColorTokens.incomeAccent
        case .transfer: return ColorTokens.transferAccent
        case .refund: return ColorTokens.refundAccent
        case .cashWithdrawal, .unknown: return ColorTokens.brandPrimary
        }
    }
}

#Preview {
    TransactionDetailView(
        transaction: TransactionCandidate(
            type: .expense,
            amount: Decimal(1450),
            currencyCode: "INR",
            merchantName: "Shell Fuel Station",
            categorySuggestion: "Fuel",
            accountSuggestion: "HDFC Salary Bank",
            paymentMethod: .upi,
            transactionDate: Date(),
            notes: "Full tank top-up",
            tags: ["fuel", "roadtrip"],
            source: .sms,
            sourceReference: "UPI/123456789012"
        )
    )
    .environment(AppState())
    .environment(\.dependencyContainer, .mock())
}
