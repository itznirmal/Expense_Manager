//
//  VoiceEntryViewModel.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Observable ViewModel for Voice Ingestion & Live Speech Parsing.
//

import SwiftUI
import Observation

/// ViewModel managing real-time voice recording, waveform animation metering, live transcription, and transaction candidate parsing.
@Observable
@MainActor
public final class VoiceEntryViewModel {
    
    // MARK: - State Properties
    
    public var isRecording: Bool = false
    public var liveTranscript: String = ""
    public var audioLevels: [Float] = Array(repeating: 0.15, count: 16)
    public var candidate: TransactionCandidate? = nil
    public var isParsing: Bool = false
    public var isSaving: Bool = false
    public var permissionDenied: Bool = false
    public var statusMessage: String = "Tap microphone to speak"
    public var errorMessage: String? = nil
    
    public var availableAccounts: [AccountDTO] = []
    public var availableCategories: [CategoryDTO] = []
    
    // MARK: - Dependencies
    
    private let audioService: AudioRecordingServiceProtocol
    private let parserService: ParserServiceProtocol
    private let transactionService: TransactionServiceProtocol
    private let accountService: AccountServiceProtocol
    private let categoryService: CategoryServiceProtocol
    private let merchantRuleService: MerchantRuleServiceProtocol?
    
    private var parseDebounceTask: Task<Void, Never>?
    
    // MARK: - Initializer
    
    public init(
        audioService: AudioRecordingServiceProtocol? = nil,
        parserService: ParserServiceProtocol,
        transactionService: TransactionServiceProtocol,
        accountService: AccountServiceProtocol,
        categoryService: CategoryServiceProtocol,
        merchantRuleService: MerchantRuleServiceProtocol? = nil
    ) {
        self.audioService = audioService ?? AudioRecordingService()
        self.parserService = parserService
        self.transactionService = transactionService
        self.accountService = accountService
        self.categoryService = categoryService
        self.merchantRuleService = merchantRuleService
    }
    
    // MARK: - Lifecycle
    
    public func loadContext() async {
        do {
            async let accounts = accountService.fetchAccounts()
            async let categories = categoryService.fetchCategories()
            self.availableAccounts = try await accounts
            self.availableCategories = try await categories
        } catch {
            AppLogger.error("Failed to load accounts/categories for VoiceEntry", error: error)
        }
    }
    
    // MARK: - Recording Actions
    
    public func toggleRecording() {
        if isRecording {
            stopListening()
        } else {
            startListening()
        }
    }
    
    public func startListening() {
        errorMessage = nil
        permissionDenied = false
        candidate = nil
        liveTranscript = ""
        statusMessage = "Listening..."
        isRecording = true
        
        Task {
            do {
                try await audioService.startRecording(
                    onTranscript: { [weak self] transcript in
                        Task { @MainActor in
                            guard let self = self else { return }
                            self.liveTranscript = transcript
                            self.debounceParse(text: transcript)
                        }
                    },
                    onPowerChange: { [weak self] power in
                        Task { @MainActor in
                            guard let self = self else { return }
                            self.updateWaveformLevels(with: power)
                        }
                    }
                )
            } catch let voiceErr as VoiceRecordingError {
                await MainActor.run {
                    self.isRecording = false
                    self.resetWaveform()
                    if case .microphonePermissionDenied = voiceErr {
                        self.permissionDenied = true
                        self.statusMessage = "Microphone permission required"
                    } else if case .speechRecognitionPermissionDenied = voiceErr {
                        self.permissionDenied = true
                        self.statusMessage = "Speech recognition permission required"
                    } else {
                        self.errorMessage = voiceErr.localizedDescription
                        self.statusMessage = "Speech recognition unavailable"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isRecording = false
                    self.resetWaveform()
                    self.errorMessage = error.localizedDescription
                    self.statusMessage = "Recording error"
                }
            }
        }
    }
    
    public func stopListening() {
        isRecording = false
        statusMessage = liveTranscript.isEmpty ? "Tap microphone to speak" : "Processing speech..."
        resetWaveform()
        
        Task {
            await audioService.stopRecording()
            if !liveTranscript.isEmpty {
                await performParse(text: liveTranscript)
                if self.candidate != nil {
                    self.statusMessage = "Candidate ready"
                }
            }
        }
    }
    
    public func retry() {
        candidate = nil
        liveTranscript = ""
        errorMessage = nil
        startListening()
    }
    
    // MARK: - Waveform Metering
    
    private func updateWaveformLevels(with power: Float) {
        var levels = audioLevels
        levels.removeFirst()
        // Add random slight variation around current power level for natural visualizer aesthetics
        let variation = Float.random(in: -0.08...0.08)
        let smoothedPower = min(max(power + variation, 0.08), 1.0)
        levels.append(smoothedPower)
        self.audioLevels = levels
    }
    
    private func resetWaveform() {
        self.audioLevels = Array(repeating: 0.15, count: 16)
    }
    
    // MARK: - Parsing
    
    private func debounceParse(text: String) {
        parseDebounceTask?.cancel()
        parseDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
            if !Task.isCancelled {
                await self.performParse(text: text)
            }
        }
    }
    
    private func performParse(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        isParsing = true
        defer { isParsing = false }
        
        do {
            let parsed = try await parserService.parse(text: trimmed, source: .voice)
            self.candidate = parsed
        } catch {
            AppLogger.error("Failed to parse voice transcript", error: error)
        }
    }
    
    // MARK: - Transaction Saving
    
    public func saveCandidate() async -> Bool {
        guard let item = candidate, item.amount > .zero else {
            errorMessage = "Please specify a valid amount."
            return false
        }
        
        isSaving = true
        defer { isSaving = false }
        
        do {
            let selectedAccount = availableAccounts.first { $0.name.localizedCaseInsensitiveContains(item.accountSuggestion ?? "") }
                ?? availableAccounts.first
            let selectedCategory = availableCategories.first { $0.name.localizedCaseInsensitiveContains(item.categorySuggestion ?? "") }
                ?? availableCategories.first
            
            _ = try await transactionService.createTransaction(
                amount: item.amount,
                currencyCode: item.currencyCode,
                type: item.type,
                merchant: item.merchantName.isEmpty ? "Voice Expense" : item.merchantName,
                notes: item.notes ?? liveTranscript,
                categoryID: selectedCategory?.id,
                accountID: selectedAccount?.id,
                destinationAccountID: nil,
                paymentMethod: item.paymentMethod ?? .cash,
                status: .cleared,
                date: item.transactionDate,
                tags: item.tags,
                source: "voice"
            )
            
            // Persist learned merchant rule if category was specified
            if let ruleService = merchantRuleService,
               let categoryID = selectedCategory?.id,
               !item.merchantName.isEmpty,
               item.merchantName != "Voice Expense" {
                try? await ruleService.learnRule(
                    merchantPattern: item.merchantName,
                    categoryID: categoryID,
                    accountID: selectedAccount?.id,
                    confidence: 0.95
                )
            }
            
            return true
        } catch {
            errorMessage = "Failed to save transaction: \(error.localizedDescription)"
            return false
        }
    }
}
