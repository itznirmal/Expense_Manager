import Foundation
import SwiftData

/// Historical SwiftData model definitions used as the migration source before
/// budgets carried an explicit currency. These types intentionally remain
/// separate from the current model classes; changing `BudgetRecord` in place
/// would make the migration source ambiguous.
public enum ExpenseManagerSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            TransactionRecord.self,
            AccountRecord.self,
            CategoryRecord.self,
            BudgetRecord.self,
            TagRecord.self,
            MerchantRuleRecord.self,
            ImportFingerprintRecord.self
        ]
    }

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
        @Attribute public var isPendingReview: Bool = false
        public var isAccepted: Bool = true
        public var reviewReasons: [String] = []
        public var parentTransactionID: String?
        public var splitGroupID: String?

        public init(
            id: String = UUID().uuidString,
            type: String = TransactionType.expense.rawValue,
            amount: Decimal = .zero,
            currencyCode: String = "INR",
            merchantName: String = "",
            category: CategoryRecord? = nil,
            account: AccountRecord? = nil,
            destinationAccount: AccountRecord? = nil,
            paymentMethod: String? = nil,
            transactionDate: Date = Date(),
            notes: String? = nil,
            tags: [String] = [],
            source: String = InputSource.manual.rawValue,
            sourceReference: String? = nil,
            confidence: Double = 1.0,
            createdAt: Date = Date(),
            updatedAt: Date = Date()
        ) {
            self.id = id
            self.type = type
            self.amount = amount
            self.currencyCode = currencyCode
            self.merchantName = merchantName
            self.category = category
            self.account = account
            self.destinationAccount = destinationAccount
            self.paymentMethod = paymentMethod
            self.transactionDate = transactionDate
            self.notes = notes
            self.tags = tags
            self.source = source
            self.sourceReference = sourceReference
            self.confidence = confidence
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    @Model
    public final class AccountRecord {
        @Attribute(.unique) public var id: String
        public var name: String
        public var type: String
        public var currencyCode: String
        public var openingBalance: Decimal
        public var currentBalance: Decimal
        public var icon: String
        public var colorToken: String
        public var lastFour: String?
        public var isArchived: Bool
        public var createdAt: Date
        @Relationship(deleteRule: .nullify, inverse: \ExpenseManagerSchemaV1.TransactionRecord.account)
        public var transactions: [TransactionRecord]?
        @Relationship(deleteRule: .nullify, inverse: \ExpenseManagerSchemaV1.TransactionRecord.destinationAccount)
        public var destinationTransactions: [TransactionRecord]?

        public init(
            id: String = UUID().uuidString,
            name: String,
            type: String = AccountType.bank.rawValue,
            currencyCode: String = "INR",
            openingBalance: Decimal = .zero,
            currentBalance: Decimal = .zero,
            icon: String = "building.columns.fill",
            colorToken: String = "blue",
            lastFour: String? = nil,
            isArchived: Bool = false,
            createdAt: Date = Date()
        ) {
            self.id = id
            self.name = name
            self.type = type
            self.currencyCode = currencyCode
            self.openingBalance = openingBalance
            self.currentBalance = currentBalance
            self.icon = icon
            self.colorToken = colorToken
            self.lastFour = lastFour
            self.isArchived = isArchived
            self.createdAt = createdAt
            self.transactions = []
            self.destinationTransactions = []
        }
    }

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
        @Relationship(deleteRule: .nullify, inverse: \ExpenseManagerSchemaV1.TransactionRecord.category)
        public var transactions: [TransactionRecord]?

        public init(
            id: String = UUID().uuidString,
            name: String,
            parentCategoryID: String? = nil,
            icon: String = "tag.fill",
            colorToken: String = "blue",
            type: String = CategoryType.expense.rawValue,
            isSystem: Bool = false,
            sortOrder: Int = 0
        ) {
            self.id = id
            self.name = name
            self.parentCategoryID = parentCategoryID
            self.icon = icon
            self.colorToken = colorToken
            self.type = type
            self.isSystem = isSystem
            self.sortOrder = sortOrder
            self.transactions = []
        }
    }

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
}

/// Current schema. `BudgetRecord.currencyCode` is the V2 addition; all other
/// current model types retain the V1 persisted fields, including split lines.
public enum ExpenseManagerSchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            TransactionRecord.self,
            AccountRecord.self,
            CategoryRecord.self,
            BudgetRecord.self,
            TagRecord.self,
            MerchantRuleRecord.self,
            ImportFingerprintRecord.self
        ]
    }
}

public enum ExpenseManagerMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [ExpenseManagerSchemaV1.self, ExpenseManagerSchemaV2.self]
    }

    public static var stages: [MigrationStage] {
        [.lightweight(fromVersion: ExpenseManagerSchemaV1.self, toVersion: ExpenseManagerSchemaV2.self)]
    }
}
