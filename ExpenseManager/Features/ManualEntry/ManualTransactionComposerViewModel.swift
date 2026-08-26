//
//  ManualTransactionComposerViewModel.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Observable ViewModel for Fast Manual Transaction Entry.
//

import SwiftUI
import Observation

@Observable
@MainActor
public final class ManualTransactionComposerViewModel {
    
    // MARK: - State Properties
    
    public var type: TransactionType = .expense
    public var amountText: String = ""
    public var currencyCode: String = CurrencyFormatter.defaultCurrencyCode
    public var merchantName: String = ""
    public var selectedCategoryID: String? = nil
    public var selectedAccountID: String? = nil
    public var selectedDestinationAccountID: String? = nil
    public var transactionDate: Date = Date()
    public var notes: String = ""
    public var tags: [String] = []
    public var tagInput: String = ""
    public var rememberRule: Bool = true
    
    public var availableCategories: [CategoryDTO] = []
    public var availableAccounts: [AccountDTO] = []
    public var recentMerchants: [String] = []
    
    public var isSaving: Bool = false
    public var isLoading: Bool = false
    public var validationError: String? = nil
    
    public let editingCandidateId: UUID?
    
    // MARK: - Computed Properties
    
    public var amount: Decimal {
        CurrencyFormatter.shared.parse(from: amountText) ?? .zero
    }
    
    public var filteredCategories: [CategoryDTO] {
        switch type {
        case .expense:
            return availableCategories.filter { $0.type == .expense }
        case .income:
            return availableCategories.filter { $0.type == .income }
        case .transfer, .cashWithdrawal, .refund, .unknown:
            return availableCategories
        }
    }
    
    public var isTransfer: Bool {
        type == .transfer
    }
    
    public var isCashWithdrawal: Bool {
        type == .cashWithdrawal
    }
    
    public var canSave: Bool {
        amount > .zero && (!merchantName.trimmingCharacters(in: .whitespaces).isEmpty || selectedCategoryID != nil || isTransfer || isCashWithdrawal)
    }
    
    // MARK: - Initializer
    
    public init(candidate: TransactionCandidate? = nil) {
        if let candidate = candidate {
            self.editingCandidateId = candidate.id
            self.type = candidate.type
            self.amountText = candidate.amount > 0 ? "\(candidate.amount)" : ""
            self.currencyCode = candidate.currencyCode
            self.merchantName = candidate.merchantName
            self.selectedCategoryID = candidate.categorySuggestion
            self.selectedAccountID = candidate.accountSuggestion
            self.selectedDestinationAccountID = candidate.destinationAccountSuggestion
            self.transactionDate = candidate.transactionDate
            self.notes = candidate.notes ?? ""
            self.tags = candidate.tags
        } else {
            self.editingCandidateId = nil
        }
    }
    
    // MARK: - Actions
    
    public func loadData(container: DependencyContainer) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let fetchedCategories = container.categoryService.fetchCategories(type: nil)
            async let fetchedAccounts = container.accountService.fetchAccounts(includeArchived: false)
            async let recentTransactions = container.transactionService.fetchRecentTransactions(limit: 15)
            
            let (categories, accounts, recents) = try await (fetchedCategories, fetchedAccounts, recentTransactions)
            
            self.availableCategories = categories
            self.availableAccounts = accounts
            
            // Set default account if none selected
            if self.selectedAccountID == nil, let firstAccount = accounts.first {
                self.selectedAccountID = firstAccount.id
            }
            
            // Set default destination account for transfers
            if self.selectedDestinationAccountID == nil && accounts.count > 1 {
                self.selectedDestinationAccountID = accounts.first(where: { $0.id != self.selectedAccountID })?.id ?? accounts.last?.id
            }
            
            // Set default category if none selected
            if self.selectedCategoryID == nil {
                self.selectedCategoryID = self.filteredCategories.first?.id
            }
            
            // Extract unique recent merchants
            var uniqueMerchants: [String] = []
            for tx in recents {
                let name = tx.merchantName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty && !uniqueMerchants.contains(name) {
                    uniqueMerchants.append(name)
                }
            }
            self.recentMerchants = Array(uniqueMerchants.prefix(6))
        } catch {
            self.validationError = "Failed to load accounts & categories: \(error.localizedDescription)"
        }
    }
    
    public func applyPresetAmount(_ delta: Decimal) {
        let current = self.amount
        let newAmount = current + delta
        self.amountText = "\(newAmount)"
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    public func selectMerchant(_ name: String) {
        self.merchantName = name
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    public func addTag() {
        let cleaned = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !tags.contains(cleaned) else { return }
        tags.append(cleaned)
        tagInput = ""
    }
    
    public func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
    
    public func saveTransaction(container: DependencyContainer, appState: AppState) async -> Bool {
        guard canSave else {
            if amount <= .zero {
                validationError = "Please enter a valid amount greater than 0."
            } else {
                validationError = "Please specify a merchant or select a category."
            }
            return false
        }
        
        // Strict Transfer Validation: Requires distinct source and destination accounts
        if isTransfer {
            guard let src = selectedAccountID, let dst = selectedDestinationAccountID, !src.isEmpty, !dst.isEmpty else {
                validationError = "Transfers require both a source and destination account."
                return false
            }
            if src == dst {
                validationError = "Source and destination accounts must be different for a transfer."
                return false
            }
        }
        
        isSaving = true
        validationError = nil
        defer { isSaving = false }
        
        // Resolve category & account names
        let categoryName = availableCategories.first(where: { $0.id == selectedCategoryID })?.name ?? selectedCategoryID
        let accountName = availableAccounts.first(where: { $0.id == selectedAccountID })?.name ?? selectedAccountID
        
        // Auto-route ATM Cash Withdrawals to Cash Account
        var destinationAccountName: String? = nil
        if isTransfer {
            destinationAccountName = availableAccounts.first(where: { $0.id == selectedDestinationAccountID })?.name ?? selectedDestinationAccountID
        } else if isCashWithdrawal {
            let cashAccount = availableAccounts.first(where: { $0.type == .cash })
            destinationAccountName = cashAccount?.name ?? "Cash"
        }
        
        let candidateID = editingCandidateId ?? UUID()
        let resolvedMerchant: String
        if !merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolvedMerchant = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if isCashWithdrawal {
            resolvedMerchant = "ATM Cash Withdrawal"
        } else if isTransfer {
            resolvedMerchant = "Account Transfer"
        } else {
            resolvedMerchant = categoryName ?? type.displayName
        }
        
        let candidate = TransactionCandidate(
            id: candidateID,
            type: type,
            amount: amount,
            currencyCode: currencyCode,
            merchantName: resolvedMerchant,
            categorySuggestion: isTransfer || isCashWithdrawal ? nil : categoryName,
            accountSuggestion: accountName,
            destinationAccountSuggestion: destinationAccountName,
            paymentMethod: isTransfer ? .netBanking : (isCashWithdrawal ? .cash : .upi),
            transactionDate: transactionDate,
            notes: notes.isEmpty ? nil : notes,
            tags: tags,
            source: .manual,
            confidence: .manual,
            needsReview: false,
            warnings: []
        )
        
        do {
            if let editingID = editingCandidateId {
                // Update existing transaction
                try await container.transactionService.updateTransaction(id: editingID.uuidString, candidate: candidate)
            } else {
                // Create new transaction
                try await container.transactionService.createTransaction(candidate)
            }
            
            // Save merchant categorization rule if enabled
            if rememberRule, !merchantName.isEmpty, let categoryID = selectedCategoryID, !isTransfer, !isCashWithdrawal {
                try? await container.merchantRuleService?.saveRule(
                    merchant: merchantName,
                    categoryID: categoryID,
                    accountID: selectedAccountID,
                    tags: tags,
                    pattern: merchantName,
                    confidence: 0.95
                )
            }
            
            // Trigger success haptic
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            
            appState.showToast(
                title: editingCandidateId != nil ? "Transaction Updated" : "Transaction Logged",
                message: "\(CurrencyFormatter.shared.format(amount: candidate.amount)) • \(candidate.merchantName)",
                type: .success
            )
            
            return true
        } catch {
            validationError = "Failed to save: \(error.localizedDescription)"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return false
        }
    }
}
