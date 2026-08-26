//
//  CategoriesManagementView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Category Taxonomy & Custom Classification View.
//

import SwiftUI

public struct CategoriesManagementView: View {
    @Environment(\.appState) private var appState
    @Environment(\.dependencyContainer) private var container
    
    @State private var viewModel = CategoriesViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                // Type Filter Picker
                Section {
                    Picker("Category Filter", selection: $viewModel.selectedType) {
                        Text("All").tag(CategoryType?.none)
                        Text("Expense").tag(CategoryType?.some(.expense))
                        Text("Income").tag(CategoryType?.some(.income))
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                
                // Custom User Categories
                if !viewModel.customCategories.isEmpty {
                    Section("Custom Categories") {
                        ForEach(viewModel.customCategories) { cat in
                            categoryRow(cat)
                        }
                    }
                }
                
                // System Default Categories
                Section("System Categories") {
                    ForEach(viewModel.systemCategories) { cat in
                        categoryRow(cat)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(ColorTokens.backgroundPrimary)
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        viewModel.isComposerPresented = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(ColorTokens.brandPrimary)
                    }
                }
            }
            .sheet(isPresented: $viewModel.isComposerPresented) {
                CategoryComposerView()
            }
            .onChange(of: viewModel.isComposerPresented) { oldValue, newValue in
                if !newValue {
                    Task {
                        await viewModel.loadCategories(container: container)
                    }
                }
            }
            .task {
                await viewModel.loadCategories(container: container)
            }
            .refreshable {
                await viewModel.loadCategories(container: container)
            }
        }
    }
    
    private func categoryRow(_ category: CategoryDTO) -> some View {
        HStack(spacing: 14) {
            Image(systemName: category.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.white)
                .frame(width: 38, height: 38)
                .background(ColorTokens.color(for: category.colorToken))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(Typography.headline)
                    .foregroundStyle(ColorTokens.textPrimary)
                
                Text(category.type.displayName)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            
            Spacer()
            
            if category.isSystem {
                Text("Default")
                    .font(Typography.caption2.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(ColorTokens.backgroundTertiary)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .clipShape(Capsule())
            } else {
                Text("Custom")
                    .font(Typography.caption2.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(ColorTokens.brandPrimary.opacity(0.12))
                    .foregroundStyle(ColorTokens.brandPrimary)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(ColorTokens.cardBackground)
    }
}

#Preview {
    CategoriesManagementView()
        .environment(AppState())
        .environment(\.dependencyContainer, .mock())
}
