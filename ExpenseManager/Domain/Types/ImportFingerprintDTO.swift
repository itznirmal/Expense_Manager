//
//  ImportFingerprintDTO.swift
//  ExpenseManager
//
//  Sendable value representation of an import fingerprint.
//

import Foundation

/// Actor-safe value returned by fingerprint services instead of a SwiftData model.
public struct ImportFingerprintDTO: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let sourceHash: String
    public let amount: Decimal
    public let normalizedMerchant: String
    public let accountLastFour: String?
    public let transactionReference: String?
    public let approximateTimestamp: Date
    public let source: String
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        sourceHash: String,
        amount: Decimal,
        normalizedMerchant: String,
        accountLastFour: String? = nil,
        transactionReference: String? = nil,
        approximateTimestamp: Date = Date(),
        source: String = "manual",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceHash = sourceHash
        self.amount = amount
        self.normalizedMerchant = normalizedMerchant
        self.accountLastFour = accountLastFour
        self.transactionReference = transactionReference
        self.approximateTimestamp = approximateTimestamp
        self.source = source
        self.createdAt = createdAt
    }
}
