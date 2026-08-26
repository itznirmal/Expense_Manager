//
//  SMSDiagnosticsView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  SMS Diagnostics & Parser Testing Sandbox View.
//

import SwiftUI

/// Interactive diagnostics sandbox view allowing developers and users to paste SMS notifications, inspect safety classification,
/// verify field extraction across Indian banks, duplicate detection, and confidence scoring.
public struct SMSDiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencyContainer) private var container
    @State private var viewModel = SMSDiagnosticsViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Quick Sample SMS Presets
                    samplePresetsSection
                    
                    // Input Text Editor
                    inputEditorSection
                    
                    // Diagnostics Inspection Results
                    if let safety = viewModel.safetyResult {
                        safetyStatusCard(safety)
                        
                        if let parsed = viewModel.parsedResult {
                            extractedPayloadCard(parsed)
                            duplicateStatusCard
                            confidenceCard
                        }
                    }
                }
                .padding()
            }
            .background(ColorTokens.backgroundPrimary)
            .navigationTitle("SMS Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(ColorTokens.brandPrimary)
                }
            }
            .task {
                viewModel = SMSDiagnosticsViewModel(
                    fingerprintService: container.fingerprintService,
                    merchantRuleService: container.merchantRuleService
                )
                // Load default first sample for instant visibility
                if let first = viewModel.sampleTemplates.first {
                    viewModel.loadSample(first)
                }
            }
        }
    }
    
    // MARK: - Sample Presets Section
    
    private var samplePresetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sample Bank Templates")
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(ColorTokens.textSecondary)
                .textCase(.uppercase)
                .tracking(0.6)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.sampleTemplates) { sample in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            viewModel.loadSample(sample)
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(sample.expectedSafe ? ColorTokens.incomeAccent : ColorTokens.criticalAccent)
                                    .frame(width: 6, height: 6)
                                
                                Text(sample.title)
                                    .font(Typography.caption.weight(.medium))
                                    .foregroundStyle(
                                        viewModel.selectedSample?.id == sample.id
                                            ? Color.white
                                            : ColorTokens.textPrimary
                                    )
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.selectedSample?.id == sample.id
                                    ? ColorTokens.brandPrimary
                                    : ColorTokens.cardBackground
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(
                                        viewModel.selectedSample?.id == sample.id
                                            ? Color.clear
                                            : ColorTokens.borderSubtle,
                                        lineWidth: 1
                                    )
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Input Editor Section
    
    private var inputEditorSection: some View {
        CardContainer(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Raw SMS Message", systemImage: "message.fill")
                        .font(Typography.subheadline.weight(.semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    Spacer()
                    
                    if !viewModel.inputText.isEmpty {
                        Button("Clear") {
                            viewModel.clear()
                        }
                        .font(Typography.caption.weight(.medium))
                        .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
                
                TextEditor(text: $viewModel.inputText)
                    .frame(minHeight: 90)
                    .font(Typography.body)
                    .scrollContentBackground(.hidden)
                    .background(ColorTokens.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(ColorTokens.borderSubtle, lineWidth: 1)
                    )
                    .onChange(of: viewModel.inputText) { _, _ in
                        viewModel.analyze()
                    }
                
                HStack {
                    Button {
                        if let clip = UIPasteboard.general.string {
                            viewModel.inputText = clip
                            viewModel.analyze()
                        }
                    } label: {
                        Label("Paste Clipboard", systemImage: "doc.on.clipboard")
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(ColorTokens.brandPrimary)
                    }
                    
                    Spacer()
                    
                    Button("Analyze") {
                        viewModel.analyze()
                    }
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(ColorTokens.brandPrimary)
                }
            }
        }
    }
    
    // MARK: - Safety Status Card
    
    private func safetyStatusCard(_ safety: SMSSafetyResult) -> some View {
        CardContainer(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(
                        safety.isSafeForTransactionGeneration ? "Safe Transaction Message" : "Rejected by Safety Classifier (AC-PARSE-2)",
                        systemImage: safety.messageType.iconName
                    )
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(safety.isSafeForTransactionGeneration ? ColorTokens.incomeAccent : ColorTokens.criticalAccent)
                    
                    Spacer()
                    
                    Text(safety.messageType.rawValue)
                        .font(Typography.caption2.weight(.bold))
                        .foregroundStyle(safety.isSafeForTransactionGeneration ? ColorTokens.incomeAccent : ColorTokens.criticalAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((safety.isSafeForTransactionGeneration ? ColorTokens.incomeAccent : ColorTokens.criticalAccent).opacity(0.12))
                        .clipShape(Capsule())
                }
                
                if let reason = safety.rejectionReason {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundStyle(ColorTokens.criticalAccent)
                        Text(reason)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ColorTokens.criticalAccent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
    
    // MARK: - Extracted Payload Card
    
    private func extractedPayloadCard(_ parsed: BankParsedResult) -> some View {
        CardContainer(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Extracted Payload")
                        .font(Typography.headline)
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    Spacer()
                    
                    AmountBadgeView(
                        amount: parsed.amount,
                        currencyCode: parsed.currencyCode,
                        type: parsed.direction == .expense ? .expense : (parsed.direction == .income ? .income : .transfer),
                        size: .large
                    )
                }
                
                Divider()
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    fieldRow(title: "Merchant", value: parsed.merchant, icon: "cart.fill")
                    fieldRow(title: "Category", value: parsed.inferredCategory ?? "General", icon: "tag.fill")
                    fieldRow(title: "Bank", value: parsed.bankName ?? "Generic Bank", icon: "building.columns.fill")
                    fieldRow(title: "Account Mask", value: parsed.accountMask ?? "None", icon: "creditcard.fill")
                    fieldRow(title: "Payment Method", value: parsed.paymentMethod?.displayName ?? "Auto", icon: "iphone.radiowaves.left.and.right")
                    fieldRow(title: "Reference / VPA", value: parsed.referenceNumber ?? parsed.upiVPA ?? "None", icon: "number")
                    
                    if let balance = parsed.availableBalance {
                        fieldRow(
                            title: "Remaining Balance",
                            value: CurrencyFormatter.shared.format(amount: balance),
                            icon: "banknote.fill"
                        )
                    }
                    fieldRow(
                        title: "Direction",
                        value: parsed.direction.displayName,
                        icon: parsed.direction.iconName
                    )
                }
            }
        }
    }
    
    private func fieldRow(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: icon)
                .font(Typography.caption2)
                .foregroundStyle(ColorTokens.textSecondary)
            
            Text(value)
                .font(Typography.subheadline.weight(.semibold))
                .foregroundStyle(ColorTokens.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Duplicate Status Card
    
    private var duplicateStatusCard: some View {
        CardContainer(padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: viewModel.isDuplicate ? "doc.on.doc.fill" : "checkmark.shield.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(viewModel.isDuplicate ? ColorTokens.warningAccent : ColorTokens.incomeAccent)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.isDuplicate ? "Duplicate Detected" : "Unique Ingestion")
                        .font(Typography.subheadline.weight(.semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    Text(viewModel.duplicateReason ?? "No previous identical SHA-256 hash or 5-min window conflict.")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Confidence Card
    
    private var confidenceCard: some View {
        CardContainer(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Confidence Metric")
                        .font(Typography.subheadline.weight(.semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    Spacer()
                    
                    Text("\(Int(viewModel.confidenceScore * 100))% • \(viewModel.confidenceTier.displayName)")
                        .font(Typography.subheadline.weight(.bold))
                        .foregroundStyle(
                            viewModel.confidenceTier == .high
                                ? ColorTokens.incomeAccent
                                : (viewModel.confidenceTier == .medium ? ColorTokens.warningAccent : ColorTokens.criticalAccent)
                        )
                }
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorTokens.backgroundTertiary)
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                viewModel.confidenceTier == .high
                                    ? ColorTokens.incomeAccent
                                    : (viewModel.confidenceTier == .medium ? ColorTokens.warningAccent : ColorTokens.criticalAccent)
                            )
                            .frame(width: geo.size.width * CGFloat(viewModel.confidenceScore), height: 8)
                    }
                }
                .frame(height: 8)
                
                if !viewModel.diagnosticWarnings.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.diagnosticWarnings, id: \.self) { warning in
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 11))
                                    .foregroundStyle(ColorTokens.warningAccent)
                                Text(warning)
                                    .font(Typography.caption2)
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
}

#Preview("SMS Diagnostics") {
    SMSDiagnosticsView()
        .environment(AppState())
        .environment(\.dependencyContainer, .mock())
}
