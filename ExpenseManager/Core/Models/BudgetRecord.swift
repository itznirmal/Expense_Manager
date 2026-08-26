//
//  BudgetRecord.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  SwiftData Canonical Budget Entity.
//

import Foundation
import SwiftData

/// Canonical persistent budget limit entity stored in SwiftData.
@Model
public final class BudgetRecord {
    @Attribute(.unique) public var id: String
    public var categoryID: String?
    public var limitAmount: Decimal
    public var month: Date
    public var alertThresholdPercent: Int
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        categoryID: String? = nil,
        limitAmount: Decimal = .zero,
        month: Date = Date(),
        alertThresholdPercent: Int = 80,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.categoryID = categoryID
        self.limitAmount = limitAmount
        self.month = month
        self.alertThresholdPercent = alertThresholdPercent
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
