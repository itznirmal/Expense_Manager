//
//  CategoryDTO.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Domain Layer Category Data Transfer Object.
//

import Foundation

/// Domain representation of a transaction categorization bucket.
public struct CategoryDTO: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var name: String
    public var parentCategoryID: String?
    public var icon: String
    public var colorToken: String
    public var type: CategoryType
    public var isSystem: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        parentCategoryID: String? = nil,
        icon: String = "tag.fill",
        colorToken: String = "blue",
        type: CategoryType = .expense,
        isSystem: Bool = false
    ) {
        self.id = id
        self.name = name
        self.parentCategoryID = parentCategoryID
        self.icon = icon
        self.colorToken = colorToken
        self.type = type
        self.isSystem = isSystem
    }
}
