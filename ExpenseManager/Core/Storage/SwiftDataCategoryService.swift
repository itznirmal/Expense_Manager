//
//  SwiftDataCategoryService.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  SwiftData Implementation of CategoryServiceProtocol.
//

import Foundation
import SwiftData

/// SwiftData persistent implementation of the Category Taxonomy Service.
@MainActor
public final class SwiftDataCategoryService: CategoryServiceProtocol, Sendable {
    
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }
    
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    // MARK: - CategoryServiceProtocol
    
    public func fetchCategories(type: CategoryType?) async throws -> [CategoryDTO] {
        let descriptor = FetchDescriptor<CategoryRecord>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward), SortDescriptor(\.name, order: .forward)]
        )
        let records = try modelContext.fetch(descriptor)
        
        return records
            .filter { record in
                guard let filterType = type else { return true }
                return record.categoryType == filterType || record.categoryType == .both
            }
            .map { $0.toDTO() }
    }
    
    public func getCategory(id: String) async throws -> CategoryDTO? {
        let record = try fetchRecord(by: id)
        return record?.toDTO()
    }
    
    @discardableResult
    public func createCategory(
        name: String,
        parentCategoryID: String?,
        icon: String,
        colorToken: String,
        type: CategoryType
    ) async throws -> String {
        let descriptor = FetchDescriptor<CategoryRecord>()
        let allCategories = try modelContext.fetch(descriptor)
        let maxSortOrder = allCategories.map(\.sortOrder).max() ?? 0
        
        let record = CategoryRecord(
            id: UUID().uuidString,
            name: name,
            parentCategoryID: parentCategoryID,
            icon: icon,
            colorToken: colorToken,
            type: type,
            isSystem: false,
            sortOrder: maxSortOrder + 1
        )
        
        modelContext.insert(record)
        try modelContext.save()
        
        return record.id
    }
    
    public func seedDefaultCategoriesIfNeeded() async throws {
        let descriptor = FetchDescriptor<CategoryRecord>()
        let existing = try modelContext.fetch(descriptor)
        guard existing.isEmpty else { return }
        
        let defaults: [(id: String, name: String, icon: String, color: String, type: CategoryType, sort: Int)] = [
            ("cat_food", "Food & Dining", "fork.knife", "orange", .expense, 1),
            ("cat_groceries", "Groceries", "cart.fill", "green", .expense, 2),
            ("cat_transport", "Transport & Fuel", "car.fill", "blue", .expense, 3),
            ("cat_shopping", "Shopping", "bag.fill", "purple", .expense, 4),
            ("cat_bills", "Bills & Utilities", "bolt.fill", "yellow", .expense, 5),
            ("cat_entertainment", "Entertainment", "film.fill", "pink", .expense, 6),
            ("cat_health", "Health & Medical", "cross.fill", "red", .expense, 7),
            ("cat_salary", "Salary", "banknote.fill", "green", .income, 8),
            ("cat_investments", "Investments & Dividends", "chart.line.uptrend.xyaxis", "teal", .income, 9),
            ("cat_freelance", "Freelance / Side Gig", "laptopcomputer", "indigo", .income, 10)
        ]
        
        for item in defaults {
            let record = CategoryRecord(
                id: item.id,
                name: item.name,
                parentCategoryID: nil,
                icon: item.icon,
                colorToken: item.color,
                type: item.type,
                isSystem: true,
                sortOrder: item.sort
            )
            modelContext.insert(record)
        }
        
        try modelContext.save()
    }
    
    // MARK: - Private Helpers
    
    private func fetchRecord(by id: String) throws -> CategoryRecord? {
        let descriptor = FetchDescriptor<CategoryRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
}
