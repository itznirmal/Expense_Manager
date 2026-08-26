//
//  MerchantRuleRecord.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  SwiftData Canonical Merchant Categorization Rule Entity.
//

import Foundation
import SwiftData

/// Canonical persistent merchant matching rule entity stored in SwiftData.
@Model
public final class MerchantRuleRecord {
    @Attribute(.unique) public var id: String
    public var normalizedMerchant: String
    public var preferredCategoryID: String?
    public var preferredAccountID: String?
    public var preferredTags: [String]
    public var matchPattern: String
    public var confidence: Double
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        normalizedMerchant: String,
        preferredCategoryID: String? = nil,
        preferredAccountID: String? = nil,
        preferredTags: [String] = [],
        matchPattern: String = "",
        confidence: Double = 0.95,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.normalizedMerchant = normalizedMerchant
        self.preferredCategoryID = preferredCategoryID
        self.preferredAccountID = preferredAccountID
        self.preferredTags = preferredTags
        self.matchPattern = matchPattern
        self.confidence = confidence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
