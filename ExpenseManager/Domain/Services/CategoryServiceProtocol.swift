//
//  CategoryServiceProtocol.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Category Management Service Protocol.
//

import Foundation

/// Service protocol defining category management and taxonomy operations.
public protocol CategoryServiceProtocol: Sendable {
    
    /// Fetches all categories filtered optionally by type (expense/income/both).
    func fetchCategories(type: CategoryType?) async throws -> [CategoryDTO]
    
    /// Fetches a specific category by ID.
    func getCategory(id: String) async throws -> CategoryDTO?
    
    /// Creates a custom user category. Returns the category ID.
    @discardableResult
    func createCategory(
        name: String,
        parentCategoryID: String?,
        icon: String,
        colorToken: String,
        type: CategoryType
    ) async throws -> String
    
    /// Updates a custom (non-system) category.
    func updateCategory(
        id: String,
        name: String,
        icon: String,
        colorToken: String,
        type: CategoryType
    ) async throws
    
    /// Deletes a custom category. System categories cannot be deleted.
    /// Existing transactions keep their historical category name via nil relationship.
    func deleteCategory(id: String) async throws
    
    /// Seeds default system categories if the category store is empty.
    func seedDefaultCategoriesIfNeeded() async throws
}

public extension CategoryServiceProtocol {
    func fetchCategories() async throws -> [CategoryDTO] {
        try await fetchCategories(type: nil)
    }
}
