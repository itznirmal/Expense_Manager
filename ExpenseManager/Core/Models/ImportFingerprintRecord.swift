//
//  ImportFingerprintRecord.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  SwiftData Canonical Import Fingerprint Duplicate Detection Entity.
//

import Foundation
import SwiftData

/// Canonical persistent duplicate detection fingerprint stored in SwiftData.
@Model
public final class ImportFingerprintRecord {
    @Attribute(.unique) public var id: String
    @Attribute(.unique) public var sourceHash: String
    public var amount: Decimal
    public var normalizedMerchant: String
    public var accountLastFour: String?
    public var transactionReference: String?
    public var approximateTimestamp: Date
    public var source: String
    public var createdAt: Date
    
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
