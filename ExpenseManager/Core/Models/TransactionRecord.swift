//
//  TransactionRecord.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  SwiftData Canonical Transaction Entity.
//

import Foundation
import SwiftData

/// Canonical persistent transaction entity stored in SwiftData.
@Model
public final class TransactionRecord {
    @Attribute(.unique) public var id: String
    public var type: String
    public var amount: Decimal
    public var currencyCode: String
    public var merchantName: String
    
    public var category: CategoryRecord?
    public var account: AccountRecord?
    public var destinationAccount: AccountRecord?
    
    public var paymentMethod: String?
    public var transactionDate: Date
    public var notes: String?
    public var tags: [String]
    public var source: String
    public var sourceReference: String?
    public var confidence: Double
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        type: TransactionType = .expense,
        amount: Decimal = .zero,
        currencyCode: String = CurrencyFormatter.defaultCurrencyCode,
        merchantName: String = "",
        category: CategoryRecord? = nil,
        account: AccountRecord? = nil,
        destinationAccount: AccountRecord? = nil,
        paymentMethod: PaymentMethod? = nil,
        transactionDate: Date = Date(),
        notes: String? = nil,
        tags: [String] = [],
        source: InputSource = .manual,
        sourceReference: String? = nil,
        confidence: Double = 1.0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.type = type.rawValue
        self.amount = amount
        self.currencyCode = currencyCode
        self.merchantName = merchantName
        self.category = category
        self.account = account
        self.destinationAccount = destinationAccount
        self.paymentMethod = paymentMethod?.rawValue
        self.transactionDate = transactionDate
        self.notes = notes
        self.tags = tags
        self.source = source.rawValue
        self.sourceReference = sourceReference
        self.confidence = confidence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Computed Properties for Enums
    
    public var transactionType: TransactionType {
        get { TransactionType(rawValue: type) ?? .expense }
        set { type = newValue.rawValue }
    }
    
    public var resolvedPaymentMethod: PaymentMethod? {
        get { paymentMethod.flatMap { PaymentMethod(rawValue: $0) } }
        set { paymentMethod = newValue?.rawValue }
    }
    
    public var inputSource: InputSource {
        get { InputSource(rawValue: source) ?? .manual }
        set { source = newValue.rawValue }
    }
    
    // MARK: - DTO Conversion
    
    public func toCandidate() -> TransactionCandidate {
        TransactionCandidate(
            id: UUID(uuidString: id) ?? UUID(),
            type: transactionType,
            amount: amount,
            currencyCode: currencyCode,
            merchantName: merchantName,
            categorySuggestion: category?.name,
            accountSuggestion: account?.name,
            destinationAccountSuggestion: destinationAccount?.name,
            paymentMethod: resolvedPaymentMethod,
            transactionDate: transactionDate,
            notes: notes,
            tags: tags,
            source: inputSource,
            sourceReference: sourceReference,
            confidence: ConfidenceScore(confidence),
            needsReview: confidence < 0.90,
            warnings: []
        )
    }
}
