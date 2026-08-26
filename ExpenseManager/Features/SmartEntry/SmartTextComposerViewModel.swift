//
//  SmartTextComposerViewModel.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Observable ViewModel for Smart Text Natural Language Entry.
//

import SwiftUI
import Observation

@Observable
@MainActor
public final class SmartTextComposerViewModel {
    
    // MARK: - State Properties
    
    public var inputText: String = ""
    public var parsedCandidate: TransactionCandidate? = nil
    public var isParsing: Bool = false
    public var isSaving: Bool = false
    public var showFullEditor: Bool = false
    
    public var availableCategories: [CategoryDTO] = []
    public var availableAccounts: [AccountDTO] = []
    
    public var overrideCategoryID: String? = nil
    public var overrideAccountID: String? = nil
    public var rememberCategoryRule: Bool = true
    public var originalSuggestedCategory: String? = nil
    
    public var errorMessage: String? = nil
    
    private var debounceTask: Task<Void, Never>?
    
    public init() {}
    
    // MARK: - Computed Properties
    
    public var hasOverriddenCategory: Bool {
        guard let override = overrideCategoryID, let original = originalSuggestedCategory else {
            return overrideCategoryID != nil && originalSuggestedCategory == nil
        }
        return override != original
    }
    
    public var activeCandidate: TransactionCandidate? {
        guard var candidate = parsedCandidate else { return nil }
        if let category = overrideCategoryID {
            candidate.categorySuggestion = category
        }
        if let account = overrideAccountID {
            candidate.accountSuggestion = account
        }
        return candidate
    }
    
    // MARK: - Actions
    
    public func loadDependencies(container: DependencyContainer) async {
        do {
            async let fetchedCategories = container.categoryService.fetchCategories(type: nil)
            async let fetchedAccounts = container.accountService.fetchAccounts(includeArchived: false)
            let (categories, accounts) = try await (fetchedCategories, fetchedAccounts)
            self.availableCategories = categories
            self.availableAccounts = accounts
        } catch {
            self.errorMessage = "Failed to load dependencies: \(error.localizedDescription)"
        }
    }
    
    public func handleInputChanged(_ text: String, parserService: ParserServiceProtocol) {
        debounceTask?.cancel()
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.parsedCandidate = nil
            self.overrideCategoryID = nil
            self.overrideAccountID = nil
            self.originalSuggestedCategory = nil
            return
        }
        
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
            guard !Task.isCancelled else { return }
            await self.parse(text: trimmed, parserService: parserService)
        }
    }
    
    public func parse(text: String, parserService: ParserServiceProtocol) async {
        isParsing = true
        errorMessage = nil
        defer { isParsing = false }
        
        do {
            let candidate = try await parserService.parse(text: text, source: .smartText)
            self.parsedCandidate = candidate
            self.originalSuggestedCategory = candidate.categorySuggestion
            self.overrideCategoryID = candidate.categorySuggestion
            self.overrideAccountID = candidate.accountSuggestion
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    public func applyExample(_ text: String, parserService: ParserServiceProtocol) {
        self.inputText = text
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            await self.parse(text: text, parserService: parserService)
        }
    }
    
    public func saveTransaction(container: DependencyContainer, appState: AppState) async -> Bool {
        guard let candidate = activeCandidate, candidate.amount > .zero else {
            errorMessage = "Cannot save transaction without a valid amount."
            return false
        }
        
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        
        do {
            try await container.transactionService.createTransaction(candidate)
            
            // Save merchant category rule if user customized category
            if rememberCategoryRule, hasOverriddenCategory, !candidate.merchantName.isEmpty, let cat = overrideCategoryID {
                try? await container.merchantRuleService?.saveRule(
                    merchant: candidate.merchantName,
                    categoryID: cat,
                    accountID: overrideAccountID,
                    tags: candidate.tags,
                    pattern: candidate.merchantName,
                    confidence: 0.95
                )
            }
            
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            
            appState.showToast(
                title: "Transaction Saved",
                message: "\(CurrencyFormatter.shared.format(amount: candidate.amount)) • \(candidate.merchantName)",
                type: .success
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return false
        }
    }
}
