//
//  MockCategoryService.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  In-Memory Mock Category Service.
//

import Foundation

public final class MockCategoryService: CategoryServiceProtocol, @unchecked Sendable {
    private var categories: [CategoryDTO] = []
    private let lock = NSLock()
    
    public init(sampleData: [CategoryDTO]? = nil) {
        if let sampleData = sampleData {
            self.categories = sampleData
        } else {
            self.categories = Self.defaultSystemCategories()
        }
    }
    
    public func fetchCategories(type: CategoryType?) async throws -> [CategoryDTO] {
        lock.lock()
        defer { lock.unlock() }
        guard let type = type else { return categories }
        return categories.filter { $0.type == type || $0.type == .both }
    }
    
    public func getCategory(id: String) async throws -> CategoryDTO? {
        lock.lock()
        defer { lock.unlock() }
        return categories.first(where: { $0.id == id })
    }
    
    public func createCategory(
        name: String,
        parentCategoryID: String?,
        icon: String,
        colorToken: String,
        type: CategoryType
    ) async throws -> String {
        lock.lock()
        defer { lock.unlock() }
        let newCat = CategoryDTO(
            id: UUID().uuidString,
            name: name,
            parentCategoryID: parentCategoryID,
            icon: icon,
            colorToken: colorToken,
            type: type,
            isSystem: false
        )
        categories.append(newCat)
        return newCat.id
    }
    
    public func seedDefaultCategoriesIfNeeded() async throws {
        lock.lock()
        defer { lock.unlock() }
        if categories.isEmpty {
            categories = Self.defaultSystemCategories()
        }
    }
    
    public static func defaultSystemCategories() -> [CategoryDTO] {
        [
            CategoryDTO(id: "cat_food", name: "Food & Dining", icon: "fork.knife", colorToken: "orange", type: .expense, isSystem: true),
            CategoryDTO(id: "cat_groceries", name: "Groceries", icon: "cart.fill", colorToken: "green", type: .expense, isSystem: true),
            CategoryDTO(id: "cat_transport", name: "Transport & Fuel", icon: "car.fill", colorToken: "blue", type: .expense, isSystem: true),
            CategoryDTO(id: "cat_shopping", name: "Shopping", icon: "bag.fill", colorToken: "purple", type: .expense, isSystem: true),
            CategoryDTO(id: "cat_bills", name: "Bills & Utilities", icon: "bolt.fill", colorToken: "yellow", type: .expense, isSystem: true),
            CategoryDTO(id: "cat_entertainment", name: "Entertainment", icon: "film.fill", colorToken: "pink", type: .expense, isSystem: true),
            CategoryDTO(id: "cat_health", name: "Health & Medical", icon: "cross.fill", colorToken: "red", type: .expense, isSystem: true),
            CategoryDTO(id: "cat_salary", name: "Salary", icon: "banknote.fill", colorToken: "green", type: .income, isSystem: true),
            CategoryDTO(id: "cat_investments", name: "Investments & Dividends", icon: "chart.line.uptrend.xyaxis", colorToken: "teal", type: .income, isSystem: true),
            CategoryDTO(id: "cat_freelance", name: "Freelance / Side Gig", icon: "laptopcomputer", colorToken: "indigo", type: .income, isSystem: true)
        ]
    }
}
