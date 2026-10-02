import Foundation

/// Immutable rule snapshot that can cross actor boundaries without a SwiftData model.
public struct MerchantRuleDTO: Identifiable, Sendable, Equatable {
    public let id: String
    public let normalizedMerchant: String
    public let preferredCategoryID: String?
    public let preferredAccountID: String?
    public let preferredTags: [String]
    public let matchPattern: String
    public let confidence: Double
    public let createdAt: Date
    public let updatedAt: Date
}
