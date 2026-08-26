//
//  TransactionsListView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Transactions Ledger List with Search, Multi-Facet Filters, Sticky Date Headers & Bulk Actions.
//

import SwiftUI

public struct TransactionsListView: View {
    @Environment(\.appState) private var appState
    @Environment(\.dependencyContainer) private var container
    
    @State private var viewModel = TransactionsListViewModel()
    @State private var isShowingBulkDeleteAlert: Bool = false
    @State private var selectedBatchCategoryID: String = ""
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Filter Pills Bar
                    filterPillsBar
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(ColorTokens.backgroundPrimary)
                    
                    // Transactions List / Empty State
                    if viewModel.isLoading && viewModel.allTransactions.isEmpty {
                        ProgressView("Loading transactions...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.filteredTransactions.isEmpty {
                        EmptyStateView(
                            iconName: "magnifyingglass",
                            title: "No Transactions Found",
                            message: "Try modifying search query or clearing active filters.",
                            actionTitle: "Add Transaction"
                        ) {
                            appState.presentSheet(.smartTextEntry)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(viewModel.groupedTransactions, id: \.dateString) { group in
                                Section(header: sectionHeader(group.dateString, count: group.items.count)) {
                                    ForEach(group.items) { item in
                                        transactionRow(item)
                                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                            .listRowBackground(ColorTokens.cardBackground)
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                        .background(ColorTokens.backgroundPrimary)
                    }
                }
                
                // Bulk Actions Bottom Toolbar
                if viewModel.isBulkSelecting {
                    bulkActionBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(ColorTokens.backgroundPrimary)
            .navigationTitle("Transactions")
            .searchable(text: $viewModel.searchQuery, prompt: "Search merchant, notes, or VPA")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.isBulkSelecting.toggle()
                            if !viewModel.isBulkSelecting {
                                viewModel.deselectAll()
                            }
                        }
                    }) {
                        Text(viewModel.isBulkSelecting ? "Done" : "Select")
                            .font(Typography.subheadline.weight(.semibold))
                            .foregroundStyle(ColorTokens.brandPrimary)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: {
                            viewModel.isFilterSheetPresented = true
                        }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: viewModel.activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(ColorTokens.brandPrimary)
                                
                                if viewModel.activeFilterCount > 0 {
                                    Text("\(viewModel.activeFilterCount)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color.white)
                                        .frame(width: 16, height: 16)
                                        .background(ColorTokens.criticalAccent)
                                        .clipShape(Circle())
                                        .offset(x: 6, y: -6)
                                }
                            }
                        }
                        
                        Button(action: {
                            appState.presentSheet(.smartTextEntry)
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(ColorTokens.brandPrimary)
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.isFilterSheetPresented) {
                TransactionFilterSheetView(viewModel: viewModel)
            }
            .sheet(item: $viewModel.selectedDetailTransaction) { tx in
                TransactionDetailView(
                    transaction: tx,
                    onEdit: { candidate in
                        viewModel.selectedEditTransaction = candidate
                    },
                    onDelete: { id in
                        viewModel.allTransactions.removeAll { $0.id.uuidString == id }
                    }
                )
            }
            .sheet(item: $viewModel.selectedEditTransaction) { candidate in
                ManualTransactionComposerView(candidate: candidate)
            }
            .sheet(isPresented: $viewModel.isBatchCategorizePresented) {
                batchCategorizeSheet
            }
            .confirmationDialog(
                "Delete \(viewModel.selectedTransactionIDs.count) Transactions?",
                isPresented: $isShowingBulkDeleteAlert,
                titleVisibility: .visible
            ) {
                Button("Delete Selected", role: .destructive) {
                    Task {
                        await viewModel.bulkDeleteSelected(container: container, appState: appState)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action will delete all selected transactions and reverse their balances.")
            }
            .task {
                await viewModel.loadData(container: container)
            }
            .refreshable {
                await viewModel.loadData(container: container)
            }
        }
    }
    
    // MARK: - Filter Pills Bar
    
    private var filterPillsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Type Filter Menu
                Menu {
                    Button("All Types") { viewModel.selectedType = nil }
                    ForEach(TransactionType.allCases, id: \.self) { type in
                        Button(type.displayName) { viewModel.selectedType = type }
                    }
                } label: {
                    filterChip(
                        title: viewModel.selectedType?.displayName ?? "All Types",
                        isActive: viewModel.selectedType != nil
                    )
                }
                
                // Date Range Menu
                Menu {
                    ForEach(DateRangeFilter.allCases) { range in
                        Button(range.rawValue) { viewModel.selectedDateRange = range }
                    }
                } label: {
                    filterChip(
                        title: viewModel.selectedDateRange.rawValue,
                        isActive: viewModel.selectedDateRange != .all
                    )
                }
                
                // Clear Filters Pill
                if viewModel.activeFilterCount > 0 {
                    Button(action: {
                        viewModel.resetFilters()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Clear (\(viewModel.activeFilterCount))")
                        }
                        .font(Typography.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ColorTokens.criticalAccent.opacity(0.12))
                        .foregroundStyle(ColorTokens.criticalAccent)
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }
    
    private func filterChip(title: String, isActive: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
        }
        .font(Typography.caption.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? ColorTokens.brandPrimary.opacity(0.15) : ColorTokens.backgroundTertiary)
        .foregroundStyle(isActive ? ColorTokens.brandPrimary : ColorTokens.textPrimary)
        .clipShape(Capsule())
    }
    
    // MARK: - Section Header & Rows
    
    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(ColorTokens.textSecondary)
            Spacer()
            Text("\(count)")
                .font(Typography.caption2)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .textCase(nil)
    }
    
    private func transactionRow(_ item: TransactionCandidate) -> some View {
        let isSelected = viewModel.selectedTransactionIDs.contains(item.id.uuidString)
        
        return Button(action: {
            if viewModel.isBulkSelecting {
                viewModel.toggleSelection(for: item.id.uuidString)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                viewModel.selectedDetailTransaction = item
            }
        }) {
            HStack(spacing: 12) {
                // Bulk Selection Circle
                if viewModel.isBulkSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? ColorTokens.brandPrimary : ColorTokens.textQuaternary)
                }
                
                // Icon
                Image(systemName: item.type.iconName)
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.brandPrimary)
                    .frame(width: 38, height: 38)
                    .background(ColorTokens.brandPrimary.opacity(0.12))
                    .clipShape(Circle())
                
                // Merchant & Meta
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.merchantName.isEmpty ? item.type.displayName : item.merchantName)
                        .font(Typography.headline)
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    HStack(spacing: 6) {
                        Text(item.categorySuggestion ?? "General")
                        
                        if let acc = item.accountSuggestion, !acc.isEmpty {
                            Text("•")
                            Text(acc)
                        }
                        
                        if item.source != .manual {
                            Text("•")
                            Text(item.source.displayName)
                                .font(Typography.caption2.weight(.medium))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(ColorTokens.backgroundTertiary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
                }
                
                Spacer()
                
                // Amount
                AmountBadgeView(
                    amount: item.amount,
                    currencyCode: item.currencyCode,
                    type: item.type == .expense ? .expense : (item.type == .income ? .income : .transfer),
                    size: .medium
                )
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task {
                    await viewModel.deleteTransaction(id: item.id.uuidString, container: container, appState: appState)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            Button {
                viewModel.selectedEditTransaction = item
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(ColorTokens.brandPrimary)
        }
    }
    
    // MARK: - Bulk Action Bar
    
    private var bulkActionBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.selectedTransactionIDs.count) Selected")
                    .font(Typography.subheadline.weight(.bold))
                    .foregroundStyle(ColorTokens.textPrimary)
                
                Button(action: {
                    if viewModel.selectedTransactionIDs.count == viewModel.filteredTransactions.count {
                        viewModel.deselectAll()
                    } else {
                        viewModel.selectAll()
                    }
                }) {
                    Text(viewModel.selectedTransactionIDs.count == viewModel.filteredTransactions.count ? "Deselect All" : "Select All")
                        .font(Typography.caption2.weight(.semibold))
                        .foregroundStyle(ColorTokens.brandPrimary)
                }
            }
            
            Spacer()
            
            // Re-categorize Button
            Button(action: {
                viewModel.isBatchCategorizePresented = true
            }) {
                Label("Categorize", systemImage: "tag.fill")
                    .font(Typography.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ColorTokens.brandPrimary.opacity(0.12))
                    .foregroundStyle(ColorTokens.brandPrimary)
                    .clipShape(Capsule())
            }
            .disabled(viewModel.selectedTransactionIDs.isEmpty)
            
            // Delete Selected Button
            Button(action: {
                isShowingBulkDeleteAlert = true
            }) {
                Label("Delete", systemImage: "trash.fill")
                    .font(Typography.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ColorTokens.criticalAccent.opacity(0.12))
                    .foregroundStyle(ColorTokens.criticalAccent)
                    .clipShape(Capsule())
            }
            .disabled(viewModel.selectedTransactionIDs.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(ColorTokens.elevatedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ColorTokens.borderSubtle, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Batch Categorize Sheet
    
    private var batchCategorizeSheet: some View {
        NavigationStack {
            Form {
                Section("Select Category for \(viewModel.selectedTransactionIDs.count) Transactions") {
                    ForEach(viewModel.availableCategories) { cat in
                        Button(action: {
                            Task {
                                await viewModel.bulkCategorizeSelected(
                                    categoryName: cat.name,
                                    container: container,
                                    appState: appState
                                )
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: cat.icon)
                                    .foregroundStyle(ColorTokens.color(for: cat.colorToken))
                                    .frame(width: 32, height: 32)
                                    .background(ColorTokens.color(for: cat.colorToken).opacity(0.15))
                                    .clipShape(Circle())
                                
                                Text(cat.name)
                                    .font(Typography.body)
                                    .foregroundStyle(ColorTokens.textPrimary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(ColorTokens.textQuaternary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Re-Categorize Batch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.isBatchCategorizePresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    TransactionsListView()
        .environment(AppState())
        .environment(\.dependencyContainer, .mock())
}
