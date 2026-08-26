//
//  CategoryRecord.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  SwiftData Canonical Category Entity.
//

import Foundation
import SwiftData

/// Canonical persistent category entity stored in SwiftData.
@Model
public final class CategoryRecord {
    @Attribute(.unique) public var id: String
    public var name: String
    public var parentCategoryID: String?
    public var icon: String
    public var colorToken: String
    public var type: String
    public var isSystem: Bool
    public var sortOrder: Int
    
    @Relationship(deleteRule: .nullify, inverse: \TransactionRecord.category)
    public var transactions: [TransactionRecord]?
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        parentCategoryID: String? = nil,
        icon: String = "tag.fill",
        colorToken: String = "blue",
        type: CategoryType = .expense,
        isSystem: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.parentCategoryID = parentCategoryID
        self.icon = icon
        self.colorToken = colorToken
        self.type = type.rawValue
        self.isSystem = isSystem
        self.sortOrder = sortOrder
        self.transactions = []
    }
    
    // MARK: - Computed Properties for Enums
    
    public var categoryType: CategoryType {
        get { CategoryType(rawValue: type) ?? .expense }
        set { type = newValue.rawValue }
    }
    
    // MARK: - DTO Conversion
    
    public func toDTO() -> CategoryDTO {
        CategoryDTO(
            id: id,
            name: name,
            parentCategoryID: parentCategoryID,
            icon: icon,
            colorToken: colorToken,
            type: categoryType,
            isSystem: isSystem
        )
    }
}
