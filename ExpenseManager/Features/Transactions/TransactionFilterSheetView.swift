//
//  TransactionFilterSheetView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Multi-Facet Ledger Search & Filter Sheet Modal.
//

import SwiftUI

public struct TransactionFilterSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: TransactionsListViewModel
    
    public init(viewModel: TransactionsListViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                // Date Range Section
                Section("Date Range") {
                    Picker("Timeframe", selection: $viewModel.selectedDateRange) {
                        ForEach(DateRangeFilter.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    
                    if viewModel.selectedDateRange == .custom {
                        DatePicker("From", selection: $viewModel.customStartDate, displayedComponents: [.date])
                        DatePicker("To", selection: $viewModel.customEndDate, displayedComponents: [.date])
                    }
                }
                
                // Transaction Type Section
                Section("Transaction Type") {
                    Picker("Type", selection: $viewModel.selectedType) {
                        Text("All Types").tag(TransactionType?.none)
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(TransactionType?.some(type))
                        }
                    }
                }
                
                // Category Section
                Section("Category") {
                    Picker("Category", selection: $viewModel.selectedCategoryID) {
                        Text("All Categories").tag(String?.none)
                        ForEach(viewModel.availableCategories) { cat in
                            HStack {
                                Image(systemName: cat.icon)
                                Text(cat.name)
                            }
                            .tag(String?.some(cat.id))
                        }
                    }
                }
                
                // Account Section
                Section("Account") {
                    Picker("Account", selection: $viewModel.selectedAccountID) {
                        Text("All Accounts").tag(String?.none)
                        ForEach(viewModel.availableAccounts) { acc in
                            HStack {
                                Image(systemName: acc.icon)
                                Text(acc.name)
                            }
                            .tag(String?.some(acc.id))
                        }
                    }
                }
                
                // Amount Range Section
                Section("Amount Range") {
                    HStack {
                        Text("Min Amount")
                        Spacer()
                        TextField("₹0", value: $viewModel.minAmount, format: .number)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Max Amount")
                        Spacer()
                        TextField("No limit", value: $viewModel.maxAmount, format: .number)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // Sort Option Section
                Section("Sort By") {
                    Picker("Sorting Order", selection: $viewModel.sortOption) {
                        ForEach(TransactionSortOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                }
            }
            .navigationTitle("Filter Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        viewModel.resetFilters()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .foregroundStyle(ColorTokens.criticalAccent)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(Typography.headline)
                }
            }
        }
    }
}

#Preview {
    TransactionFilterSheetView(viewModel: TransactionsListViewModel())
}
