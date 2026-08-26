//
//  TagRecord.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  SwiftData Canonical Tag Entity.
//

import Foundation
import SwiftData

/// Canonical persistent tag entity stored in SwiftData.
@Model
public final class TagRecord {
    @Attribute(.unique) public var id: String
    public var name: String
    public var colorToken: String
    public var createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        colorToken: String = "blue",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorToken = colorToken
        self.createdAt = createdAt
    }
}
