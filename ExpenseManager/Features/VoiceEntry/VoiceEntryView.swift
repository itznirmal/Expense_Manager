//
//  VoiceEntryView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Interactive Voice Ingestion Modal View.
//

import SwiftUI

/// Modal interface for voice-based transaction entry featuring live speech recognition, waveform metering, and parsed transaction cards.
public struct VoiceEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appState) private var appState
    @Environment(\.dependencyContainer) private var container
    
    @State private var viewModel: VoiceEntryViewModel
    @State private var pulseAnimation = false
    
    public init(audioService: AudioRecordingServiceProtocol? = nil) {
        // Initializer placeholder; viewModel gets initialized in onAppear / factory
        _viewModel = State(initialValue: VoiceEntryViewModel(
            audioService: audioService,
            parserService: MockParserService(),
            transactionService: MockTransactionService(),
            accountService: MockAccountService(),
            categoryService: MockCategoryService()
        ))
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer(minLength: 12)
                    
                    // Waveform Metering Visualizer
                    waveformVisualizer
                        .frame(height: 70)
                        .padding(.horizontal, 20)
                    
                    // Central Pulsing Microphone Button
                    microphoneButton
                    
                    // Status & Live Transcript Card
                    transcriptSection
                        .padding(.horizontal, 20)
                    
                    // Parsed Candidate Preview (if parsed)
                    if let candidate = viewModel.candidate {
                        parsedCandidateCard(candidate)
                            .padding(.horizontal, 20)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    Spacer(minLength: 12)
                    
                    // Action Buttons Footer
                    footerActions
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }
            }
            .navigationTitle("Voice Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.retry()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(ColorTokens.brandPrimary)
                    }
                }
            }
            .task {
                // Initialize with real container services
                viewModel = VoiceEntryViewModel(
                    audioService: nil,
                    parserService: container.parserService,
                    transactionService: container.transactionService,
                    accountService: container.accountService,
                    categoryService: container.categoryService,
                    merchantRuleService: container.merchantRuleService
                )
                await viewModel.loadContext()
                // Auto-start recording on appear
                viewModel.startListening()
            }
        }
    }
    
    // MARK: - Waveform Visualizer
    
    private var waveformVisualizer: some View {
        HStack(spacing: 6) {
            ForEach(0..<viewModel.audioLevels.count, id: \.self) { index in
                let level = viewModel.audioLevels[index]
                let barHeight = CGFloat(max(level * 60, 6))
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: viewModel.isRecording
                                ? [ColorTokens.brandPrimary, ColorTokens.brandPrimary.opacity(0.6)]
                                : [ColorTokens.textTertiary, ColorTokens.textTertiary.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 8, height: barHeight)
                    .animation(.spring(response: 0.15, dampingFraction: 0.7), value: level)
            }
        }
    }
    
    // MARK: - Microphone Button
    
    private var microphoneButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            viewModel.toggleRecording()
        } label: {
            ZStack {
                // Animated Pulsing Ripple Rings
                if viewModel.isRecording {
                    Circle()
                        .stroke(ColorTokens.criticalAccent.opacity(0.25), lineWidth: 3)
                        .frame(width: 130, height: 130)
                        .scaleEffect(pulseAnimation ? 1.25 : 0.95)
                        .opacity(pulseAnimation ? 0.0 : 0.7)
                        .animation(
                            .easeOut(duration: 1.4).repeatForever(autoreverses: false),
                            value: pulseAnimation
                        )
                    
                    Circle()
                        .stroke(ColorTokens.criticalAccent.opacity(0.4), lineWidth: 2)
                        .frame(width: 108, height: 108)
                        .scaleEffect(pulseAnimation ? 1.15 : 0.98)
                        .opacity(pulseAnimation ? 0.2 : 0.8)
                        .animation(
                            .easeOut(duration: 1.4).repeatForever(autoreverses: false).delay(0.2),
                            value: pulseAnimation
                        )
                }
                
                // Central Mic Circle
                Circle()
                    .fill(viewModel.isRecording ? ColorTokens.criticalAccent : ColorTokens.brandPrimary)
                    .frame(width: 84, height: 84)
                    .shadow(
                        color: (viewModel.isRecording ? ColorTokens.criticalAccent : ColorTokens.brandPrimary).opacity(0.35),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
                
                Image(systemName: viewModel.isRecording ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            pulseAnimation = true
        }
    }
    
    // MARK: - Transcript & Status Section
    
    private var transcriptSection: some View {
        VStack(spacing: 10) {
            Text(viewModel.statusMessage)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(viewModel.isRecording ? ColorTokens.criticalAccent : ColorTokens.textSecondary)
                .textCase(.uppercase)
                .tracking(0.8)
            
            CardContainer(padding: 16) {
                VStack(spacing: 8) {
                    if viewModel.liveTranscript.isEmpty {
                        Text("“Swiggy 540 rupees from HDFC Bank today”")
                            .font(Typography.subheadline)
                            .foregroundStyle(ColorTokens.textTertiary)
                            .italic()
                            .multilineTextAlignment(.center)
                    } else {
                        Text(viewModel.liveTranscript)
                            .font(Typography.headline)
                            .foregroundStyle(ColorTokens.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            
            if viewModel.permissionDenied {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(ColorTokens.warningAccent)
                    Text("Microphone or Speech Recognition permission required.")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
            
            if let errorMsg = viewModel.errorMessage {
                Text(errorMsg)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.criticalAccent)
            }
        }
    }
    
    // MARK: - Parsed Candidate Card
    
    private func parsedCandidateCard(_ candidate: TransactionCandidate) -> some View {
        CardContainer(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(candidate.merchantName.isEmpty ? "Expense" : candidate.merchantName)
                            .font(Typography.title3)
                            .foregroundStyle(ColorTokens.textPrimary)
                        
                        HStack(spacing: 8) {
                            if let category = candidate.categorySuggestion {
                                Label(category, systemImage: "tag.fill")
                                    .font(Typography.caption.weight(.medium))
                                    .foregroundStyle(ColorTokens.brandPrimary)
                            }
                            if let account = candidate.accountSuggestion {
                                Label(account, systemImage: "creditcard.fill")
                                    .font(Typography.caption.weight(.medium))
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    AmountBadgeView(
                        amount: candidate.amount,
                        currencyCode: candidate.currencyCode,
                        type: candidate.type == .expense ? .expense : .income,
                        size: .large
                    )
                }
                
                // Confidence & Diagnostic Badges
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(candidate.confidence.tier == .high ? ColorTokens.incomeAccent : (candidate.confidence.tier == .medium ? ColorTokens.warningAccent : ColorTokens.criticalAccent))
                            .frame(width: 8, height: 8)
                        Text("\(candidate.confidence.tier.displayName) Confidence (\(Int(candidate.confidence.rawScore * 100))%)")
                            .font(Typography.caption2.weight(.semibold))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ColorTokens.backgroundTertiary)
                    .clipShape(Capsule())
                    
                    if let method = candidate.paymentMethod {
                        Text(method.displayName)
                            .font(Typography.caption2.weight(.medium))
                            .foregroundStyle(ColorTokens.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ColorTokens.backgroundTertiary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
    
    // MARK: - Footer Actions
    
    private var footerActions: some View {
        VStack(spacing: 12) {
            if let candidate = viewModel.candidate, candidate.amount > .zero {
                PrimaryButton(
                    title: "Save \(CurrencyFormatter.shared.format(amount: candidate.amount))",
                    iconName: "checkmark",
                    isLoading: viewModel.isSaving
                ) {
                    Task {
                        let success = await viewModel.saveCandidate()
                        if success {
                            appState.showToast(
                                title: "Expense Saved",
                                message: "\(candidate.merchantName) - \(CurrencyFormatter.shared.format(amount: candidate.amount))",
                                type: .success
                            )
                            dismiss()
                        }
                    }
                }
                
                Button("Edit in Full Form") {
                    dismiss()
                    appState.presentSheet(.manualEntry)
                }
                .font(Typography.subheadline.weight(.semibold))
                .foregroundStyle(ColorTokens.brandPrimary)
            } else {
                Button(viewModel.isRecording ? "Stop Listening" : "Start Speaking") {
                    viewModel.toggleRecording()
                }
                .font(Typography.headline)
                .foregroundStyle(ColorTokens.brandPrimary)
                .padding(.vertical, 10)
            }
        }
    }
}

#Preview("Voice Entry Idle") {
    VoiceEntryView(audioService: MockAudioRecordingService())
        .environment(AppState())
        .environment(\.dependencyContainer, .mock())
}
