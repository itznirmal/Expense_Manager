//
//  CategoriesViewModel.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Observable ViewModel for Category Taxonomy Management.
//

import SwiftUI
import Observation

@Observable
@MainActor
public final class CategoriesViewModel {
    
    // MARK: - State Properties
    
    public var allCategories: [CategoryDTO] = []
    public var selectedType: CategoryType? = nil
    public var isLoading: Bool = false
    public var errorMessage: String? = nil
    
    public var isComposerPresented: Bool = false
    
    // MARK: - Computed Properties
    
    public var filteredCategories: [CategoryDTO] {
        guard let selectedType = selectedType else { return allCategories }
        return allCategories.filter { $0.type == selectedType || $0.type == .both }
    }
    
    public var systemCategories: [CategoryDTO] {
        filteredCategories.filter { $0.isSystem }
    }
    
    public var customCategories: [CategoryDTO] {
        filteredCategories.filter { !$0.isSystem }
    }
    
    public init() {}
    
    // MARK: - Actions
    
    public func loadCategories(container: DependencyContainer) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            try await container.categoryService.seedDefaultCategoriesIfNeeded()
            allCategories = try await container.categoryService.fetchCategories(type: nil)
        } catch {
            errorMessage = "Failed to load categories: \(error.localizedDescription)"
        }
    }
    
    public func createCategory(
        name: String,
        icon: String,
        colorToken: String,
        type: CategoryType,
        container: DependencyContainer
    ) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Category name cannot be empty."
            return false
        }
        
        do {
            try await container.categoryService.createCategory(
                name: trimmedName,
                parentCategoryID: nil,
                icon: icon,
                colorToken: colorToken,
                type: type
            )
            await loadCategories(container: container)
            return true
        } catch {
            errorMessage = "Failed to create category: \(error.localizedDescription)"
            return false
        }
    }
}
