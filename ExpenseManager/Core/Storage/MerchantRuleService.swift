//
//  MerchantRuleService.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  SwiftData Implementation of Merchant Categorization Rules Service.
//

import Foundation
import SwiftData

/// Service protocol defining merchant categorization rule management.
public protocol MerchantRuleServiceProtocol: Sendable {
    func findMatchingRule(for merchantName: String) async throws -> MerchantRuleRecord?
    @discardableResult
    func saveRule(
        merchant: String,
        categoryID: String?,
        accountID: String?,
        tags: [String],
        pattern: String,
        confidence: Double
    ) async throws -> String
    
    @discardableResult
    func learnRule(
        merchantPattern: String,
        categoryID: String?,
        accountID: String?,
        confidence: Double
    ) async throws -> String
    
    func fetchRules() async throws -> [MerchantRuleRecord]
    func deleteRule(id: String) async throws
}

public extension MerchantRuleServiceProtocol {
    @discardableResult
    func learnRule(
        merchantPattern: String,
        categoryID: String?,
        accountID: String?,
        confidence: Double = 0.95
    ) async throws -> String {
        try await saveRule(
            merchant: merchantPattern,
            categoryID: categoryID,
            accountID: accountID,
            tags: [],
            pattern: merchantPattern,
            confidence: confidence
        )
    }
}

/// SwiftData persistent implementation of the Merchant Rule Service.
@MainActor
public final class MerchantRuleService: MerchantRuleServiceProtocol, Sendable {
    
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }
    
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    public func findMatchingRule(for merchantName: String) async throws -> MerchantRuleRecord? {
        let cleaned = merchantName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else { return nil }
        
        let descriptor = FetchDescriptor<MerchantRuleRecord>(
            sortBy: [SortDescriptor(\.confidence, order: .reverse)]
        )
        let rules = try modelContext.fetch(descriptor)
        
        for rule in rules {
            // 1. Exact normalized merchant match
            if rule.normalizedMerchant.lowercased() == cleaned {
                return rule
            }
            // 2. Pattern regex match if pattern is non-empty
            if !rule.matchPattern.isEmpty,
               let regex = try? NSRegularExpression(pattern: rule.matchPattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: merchantName.utf16.count)
                if regex.firstMatch(in: merchantName, options: [], range: range) != nil {
                    return rule
                }
            }
            // 3. Substring match fallback
            if cleaned.contains(rule.normalizedMerchant.lowercased()) {
                return rule
            }
        }
        
        return nil
    }
    
    @discardableResult
    public func saveRule(
        merchant: String,
        categoryID: String?,
        accountID: String?,
        tags: [String],
        pattern: String,
        confidence: Double = 0.95
    ) async throws -> String {
        let normalized = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<MerchantRuleRecord>()
        let existingRules = try modelContext.fetch(descriptor)
        
        if let existing = existingRules.first(where: { $0.normalizedMerchant.localizedCaseInsensitiveCompare(normalized) == .orderedSame }) {
            existing.preferredCategoryID = categoryID
            existing.preferredAccountID = accountID
            existing.preferredTags = tags
            existing.matchPattern = pattern
            existing.confidence = confidence
            existing.updatedAt = Date()
            try modelContext.save()
            return existing.id
        } else {
            let record = MerchantRuleRecord(
                id: UUID().uuidString,
                normalizedMerchant: normalized,
                preferredCategoryID: categoryID,
                preferredAccountID: accountID,
                preferredTags: tags,
                matchPattern: pattern,
                confidence: confidence,
                createdAt: Date(),
                updatedAt: Date()
            )
            modelContext.insert(record)
            try modelContext.save()
            return record.id
        }
    }
    
    public func fetchRules() async throws -> [MerchantRuleRecord] {
        let descriptor = FetchDescriptor<MerchantRuleRecord>(
            sortBy: [SortDescriptor(\.normalizedMerchant, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    public func deleteRule(id: String) async throws {
        let descriptor = FetchDescriptor<MerchantRuleRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let record = try modelContext.fetch(descriptor).first {
            modelContext.delete(record)
            try modelContext.save()
        }
    }
}
