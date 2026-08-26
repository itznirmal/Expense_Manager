//
//  ConfidenceScore.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Transaction Candidate Confidence Valuation.
//

import Foundation

/// Represents the parser confidence valuation (0.0 to 1.0) and associated routing tiers.
public struct ConfidenceScore: Codable, Comparable, Sendable {
    public let value: Double
    
    public enum Tier: String, Codable, Sendable {
        /// 0.90 – 1.00: Highly confident extraction, eligible for auto-save
        case high
        /// 0.65 – 0.89: Good extraction, review recommended
        case medium
        /// 0.00 – 0.64: Ambiguous or incomplete extraction, manual review required
        case low
    }
    
    public init(_ value: Double) {
        // Clamp value strictly between 0.0 and 1.0
        self.value = max(0.0, min(1.0, value))
    }
    
    public var tier: Tier {
        switch value {
        case 0.90...1.00:
            return .high
        case 0.65..<0.90:
            return .medium
        default:
            return .low
        }
    }
    
    public var isAutoSaveEligible: Bool {
        tier == .high
    }
    
    public var requiresReview: Bool {
        tier != .high
    }
    
    public static func < (lhs: ConfidenceScore, rhs: ConfidenceScore) -> Bool {
        lhs.value < rhs.value
    }
    
    // Common presets
    public static let high = ConfidenceScore(0.95)
    public static let medium = ConfidenceScore(0.75)
    public static let low = ConfidenceScore(0.50)
    public static let manual = ConfidenceScore(1.00)
}
