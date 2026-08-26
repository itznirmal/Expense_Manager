//
//  TransactionsListViewModel.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Observable ViewModel for Advanced Transaction Ledger, Filtering & Bulk Operations.
//

import SwiftUI
import Observation

/// Preset date filter intervals for transaction querying.
public enum DateRangeFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All Time"
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case custom = "Custom Range"
    
    public var id: String { rawValue }
}

/// Supported sorting options for transaction lists.
public enum TransactionSortOption: String, CaseIterable, Identifiable, Sendable {
    case dateDesc = "Date (Newest First)"
    case dateAsc = "Date (Oldest First)"
    case amountDesc = "Amount (Highest First)"
    case amountAsc = "Amount (Lowest First)"
    
    public var id: String { rawValue }
}

@Observable
@MainActor
public final class TransactionsListViewModel {
    
    // MARK: - State Properties
    
    public var allTransactions: [TransactionCandidate] = []
    public var availableCategories: [CategoryDTO] = []
    public var availableAccounts: [AccountDTO] = []
    
    // Filters & Search
    public var searchQuery: String = ""
    public var selectedDateRange: DateRangeFilter = .all
    public var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    public var customEndDate: Date = Date()
    public var selectedType: TransactionType? = nil
    public var selectedCategoryID: String? = nil
    public var selectedAccountID: String? = nil
    public var sortOption: TransactionSortOption = .dateDesc
    public var minAmount: Decimal? = nil
    public var maxAmount: Decimal? = nil
    
    // Bulk Operations
    public var isBulkSelecting: Bool = false
    public var selectedTransactionIDs: Set<String> = []
    
    // Modals
    public var isFilterSheetPresented: Bool = false
    public var isBatchCategorizePresented: Bool = false
    public var selectedDetailTransaction: TransactionCandidate? = nil
    public var selectedEditTransaction: TransactionCandidate? = nil
    
    public var isLoading: Bool = false
    public var errorMessage: String? = nil
    
    public init() {}
    
    // MARK: - Filter Count & Filtering
    
    public var activeFilterCount: Int {
        var count = 0
        if selectedDateRange != .all { count += 1 }
        if selectedType != nil { count += 1 }
        if selectedCategoryID != nil { count += 1 }
        if selectedAccountID != nil { count += 1 }
        if minAmount != nil || maxAmount != nil { count += 1 }
        if sortOption != .dateDesc { count += 1 }
        return count
    }
    
    public var filteredTransactions: [TransactionCandidate] {
        let calendar = Calendar.current
        let now = Date()
        
        let filtered = allTransactions.filter { item in
            // 1. Search Query Filter
            if !searchQuery.isEmpty {
                let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                let matchesMerchant = item.merchantName.localizedCaseInsensitiveContains(q)
                let matchesNotes = item.notes?.localizedCaseInsensitiveContains(q) ?? false
                let matchesCategory = item.categorySuggestion?.localizedCaseInsensitiveContains(q) ?? false
                let matchesAccount = item.accountSuggestion?.localizedCaseInsensitiveContains(q) ?? false
                let matchesRef = item.sourceReference?.localizedCaseInsensitiveContains(q) ?? false
                let matchesTag = item.tags.contains { $0.localizedCaseInsensitiveContains(q) }
                if !matchesMerchant && !matchesNotes && !matchesCategory && !matchesAccount && !matchesRef && !matchesTag {
                    return false
                }
            }
            
            // 2. Type Filter
            if let type = selectedType, item.type != type {
                return false
            }
            
            // 3. Category Filter
            if let catID = selectedCategoryID {
                let catName = availableCategories.first(where: { $0.id == catID })?.name ?? catID
                if item.categorySuggestion != catID && item.categorySuggestion != catName {
                    return false
                }
            }
            
            // 4. Account Filter
            if let accID = selectedAccountID {
                let accName = availableAccounts.first(where: { $0.id == accID })?.name ?? accID
                let matchesSource = item.accountSuggestion == accID || item.accountSuggestion == accName
                let matchesDest = item.destinationAccountSuggestion == accID || item.destinationAccountSuggestion == accName
                if !matchesSource && !matchesDest {
                    return false
                }
            }
            
            // 5. Amount Range Filter
            if let min = minAmount, item.amount < min {
                return false
            }
            if let max = maxAmount, item.amount > max {
                return false
            }
            
            // 6. Date Range Filter
            switch selectedDateRange {
            case .all:
                break
            case .today:
                if !calendar.isDateInToday(item.transactionDate) { return false }
            case .thisWeek:
                if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now), item.transactionDate < weekAgo { return false }
            case .thisMonth:
                let start = DateFormatterHelper.shared.startOfMonth(for: now, calendar: calendar)
                let end = DateFormatterHelper.shared.endOfMonth(for: now, calendar: calendar)
                if item.transactionDate < start || item.transactionDate > end { return false }
            case .lastMonth:
                if let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: now) {
                    let start = DateFormatterHelper.shared.startOfMonth(for: lastMonthDate, calendar: calendar)
                    let end = DateFormatterHelper.shared.endOfMonth(for: lastMonthDate, calendar: calendar)
                    if item.transactionDate < start || item.transactionDate > end { return false }
                }
            case .custom:
                let start = calendar.startOfDay(for: customStartDate)
                let end = DateFormatterHelper.shared.endOfDay(for: customEndDate, calendar: calendar)
                if item.transactionDate < start || item.transactionDate > end { return false }
            }
            
            return true
        }
        
        // Sorting
        return filtered.sorted { a, b in
            switch sortOption {
            case .dateDesc:
                return a.transactionDate > b.transactionDate
            case .dateAsc:
                return a.transactionDate < b.transactionDate
            case .amountDesc:
                return a.amount > b.amount
            case .amountAsc:
                return a.amount < b.amount
            }
        }
    }
    
    /// Group transactions into sticky date sections.
    public var groupedTransactions: [(dateString: String, items: [TransactionCandidate])] {
        let calendar = Calendar.current
        var groups: [String: [TransactionCandidate]] = [:]
        var order: [String] = []
        
        for tx in filteredTransactions {
            let label = DateFormatterHelper.shared.relativeDateString(for: tx.transactionDate, calendar: calendar)
            if groups[label] == nil {
                groups[label] = []
                order.append(label)
            }
            groups[label]?.append(tx)
        }
        
        return order.compactMap { label in
            guard let items = groups[label] else { return nil }
            return (dateString: label, items: items)
        }
    }
    
    // MARK: - Actions
    
    public func loadData(container: DependencyContainer) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            async let fetchedTx = container.transactionService.fetchTransactions(startDate: nil, endDate: nil, categoryID: nil, accountID: nil)
            async let fetchedCategories = container.categoryService.fetchCategories(type: nil)
            async let fetchedAccounts = container.accountService.fetchAccounts(includeArchived: false)
            
            let (txList, categories, accounts) = try await (fetchedTx, fetchedCategories, fetchedAccounts)
            self.allTransactions = txList
            self.availableCategories = categories
            self.availableAccounts = accounts
        } catch {
            errorMessage = "Failed to load transactions: \(error.localizedDescription)"
        }
    }
    
    public func toggleSelection(for id: String) {
        if selectedTransactionIDs.contains(id) {
            selectedTransactionIDs.remove(id)
        } else {
            selectedTransactionIDs.insert(id)
        }
    }
    
    public func selectAll() {
        let allIDs = filteredTransactions.map { $0.id.uuidString }
        selectedTransactionIDs = Set(allIDs)
    }
    
    public func deselectAll() {
        selectedTransactionIDs.removeAll()
    }
    
    public func deleteTransaction(id: String, container: DependencyContainer, appState: AppState) async {
        do {
            try await container.transactionService.deleteTransaction(id: id)
            allTransactions.removeAll { $0.id.uuidString == id }
            selectedTransactionIDs.remove(id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            appState.showToast(title: "Transaction Deleted", type: .info)
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    public func bulkDeleteSelected(container: DependencyContainer, appState: AppState) async {
        let idsToDelete = Array(selectedTransactionIDs)
        guard !idsToDelete.isEmpty else { return }
        
        var deletedCount = 0
        for id in idsToDelete {
            do {
                try await container.transactionService.deleteTransaction(id: id)
                deletedCount += 1
            } catch {
                AppLogger.shared.error("Failed to delete transaction \(id): \(error.localizedDescription)")
            }
        }
        
        allTransactions.removeAll { idsToDelete.contains($0.id.uuidString) }
        selectedTransactionIDs.removeAll()
        isBulkSelecting = false
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        appState.showToast(
            title: "Deleted \(deletedCount) Transactions",
            type: .info
        )
    }
    
    public func bulkCategorizeSelected(categoryName: String, container: DependencyContainer, appState: AppState) async {
        let idsToUpdate = Array(selectedTransactionIDs)
        guard !idsToUpdate.isEmpty else { return }
        
        var updatedCount = 0
        for id in idsToUpdate {
            if let index = allTransactions.firstIndex(where: { $0.id.uuidString == id }) {
                var candidate = allTransactions[index]
                candidate.categorySuggestion = categoryName
                do {
                    try await container.transactionService.updateTransaction(id: id, candidate: candidate)
                    allTransactions[index] = candidate
                    updatedCount += 1
                } catch {
                    AppLogger.shared.error("Failed to re-categorize transaction \(id): \(error.localizedDescription)")
                }
            }
        }
        
        selectedTransactionIDs.removeAll()
        isBulkSelecting = false
        isBatchCategorizePresented = false
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        appState.showToast(
            title: "Categorized \(updatedCount) Transactions",
            message: "Assigned to \(categoryName)",
            type: .success
        )
    }
    
    public func resetFilters() {
        searchQuery = ""
        selectedDateRange = .all
        selectedType = nil
        selectedCategoryID = nil
        selectedAccountID = nil
        sortOption = .dateDesc
        minAmount = nil
        maxAmount = nil
    }
}
