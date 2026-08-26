//
//  DataExportServiceProtocol.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Data Export, Backup, CSV Neutralization & Data Management Protocol.
//

import Foundation

// MARK: - CSV Formula Injection Sanitizer (AC-SEC-1 / GT-58)

/// Sanitizer protecting against CSV Formula Injection (CWE-1236 / AC-SEC-1).
/// Prefixes any text field beginning with `=`, `+`, `-`, `@`, `\t`, `\r` (even if padded with leading whitespace)
/// with a single quote `'` to neutralize formula execution in Microsoft Excel, Apple Numbers, and Google Sheets.
public enum CSVFormulaSanitizer {
    /// Dangerous characters that can trigger formula evaluation in spreadsheet software.
    public static let formulaTriggers: [Character] = ["=", "+", "-", "@", "\t", "\r"]
    
    /// Neutralizes formula execution by prepending a single quote `'` if the string or trimmed string starts with a trigger character.
    public static func neutralize(_ input: String) -> String {
        guard let firstChar = input.first else { return input }
        if formulaTriggers.contains(firstChar) {
            return "'" + input
        }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedFirst = trimmed.first, formulaTriggers.contains(trimmedFirst) {
            return "'" + input
        }
        return input
    }
    
    /// Sanitizes and escapes a string for standard RFC-4180 CSV representation.
    public static func sanitizeAndEscape(_ input: String) -> String {
        let neutralized = neutralize(input)
        
        let needsQuoting = neutralized.contains(",") ||
                           neutralized.contains("\"") ||
                           neutralized.contains("\n") ||
                           neutralized.contains("\r") ||
                           neutralized.hasPrefix("'") ||
                           neutralized.hasPrefix(" ") ||
                           neutralized.hasSuffix(" ")
        
        if needsQuoting {
            let escaped = neutralized.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        } else {
            return neutralized
        }
    }
}

// MARK: - Backup DTOs & Payloads

/// Account backup payload representation.
public struct AccountBackupDTO: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let type: String
    public let currencyCode: String
    public let openingBalance: Decimal
    public let currentBalance: Decimal
    public let icon: String
    public let colorToken: String
    public let lastFour: String?
    public let isArchived: Bool
    public let createdAt: Date
    
    public init(
        id: String,
        name: String,
        type: String,
        currencyCode: String,
        openingBalance: Decimal,
        currentBalance: Decimal,
        icon: String,
        colorToken: String,
        lastFour: String?,
        isArchived: Bool,
        createdAt: Date
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
    }
}

/// Category backup payload representation.
public struct CategoryBackupDTO: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let parentCategoryID: String?
    public let icon: String
    public let colorToken: String
    public let type: String
    public let isSystem: Bool
    public let sortOrder: Int
    
    public init(
        id: String,
        name: String,
        parentCategoryID: String?,
        icon: String,
        colorToken: String,
        type: String,
        isSystem: Bool,
        sortOrder: Int
    ) {
        self.id = id
        self.name = name
        self.parentCategoryID = parentCategoryID
        self.icon = icon
        self.colorToken = colorToken
        self.type = type
        self.isSystem = isSystem
        self.sortOrder = sortOrder
    }
}

/// Tag backup payload representation.
public struct TagBackupDTO: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let colorToken: String
    public let createdAt: Date
    
    public init(id: String, name: String, colorToken: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.colorToken = colorToken
        self.createdAt = createdAt
    }
}

/// Budget backup payload representation.
public struct BudgetBackupDTO: Codable, Sendable, Equatable {
    public let id: String
    public let categoryID: String?
    public let limitAmount: Decimal
    public let month: Date
    public let alertThresholdPercent: Int
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: String,
        categoryID: String?,
        limitAmount: Decimal,
        month: Date,
        alertThresholdPercent: Int,
        createdAt: Date,
        updatedAt: Date
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

/// Merchant Rule backup payload representation.
public struct MerchantRuleBackupDTO: Codable, Sendable, Equatable {
    public let id: String
    public let normalizedMerchant: String
    public let preferredCategoryID: String?
    public let preferredAccountID: String?
    public let preferredTags: [String]
    public let matchPattern: String
    public let confidence: Double
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: String,
        normalizedMerchant: String,
        preferredCategoryID: String?,
        preferredAccountID: String?,
        preferredTags: [String],
        matchPattern: String,
        confidence: Double,
        createdAt: Date,
        updatedAt: Date
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

/// Import Fingerprint backup payload representation (GT-68).
public struct ImportFingerprintBackupDTO: Codable, Sendable, Equatable {
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
        id: String,
        sourceHash: String,
        amount: Decimal,
        normalizedMerchant: String,
        accountLastFour: String?,
        transactionReference: String?,
        approximateTimestamp: Date,
        source: String,
        createdAt: Date
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

/// Transaction backup payload representation.
public struct TransactionBackupDTO: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
    public let amount: Decimal
    public let currencyCode: String
    public let merchantName: String
    public let categoryID: String?
    public let accountID: String?
    public let destinationAccountID: String?
    public let paymentMethod: String?
    public let transactionDate: Date
    public let notes: String?
    public let tags: [String]
    public let source: String
    public let sourceReference: String?
    public let confidence: Double
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: String,
        type: String,
        amount: Decimal,
        currencyCode: String,
        merchantName: String,
        categoryID: String?,
        accountID: String?,
        destinationAccountID: String?,
        paymentMethod: String?,
        transactionDate: Date,
        notes: String?,
        tags: [String],
        source: String,
        sourceReference: String?,
        confidence: Double,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.currencyCode = currencyCode
        self.merchantName = merchantName
        self.categoryID = categoryID
        self.accountID = accountID
        self.destinationAccountID = destinationAccountID
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

/// Inner database backup payload containing all collections.
public struct BackupData: Codable, Sendable, Equatable {
    public let accounts: [AccountBackupDTO]
    public let categories: [CategoryBackupDTO]
    public let tags: [TagBackupDTO]
    public let transactions: [TransactionBackupDTO]
    public let budgets: [BudgetBackupDTO]
    public let merchantRules: [MerchantRuleBackupDTO]
    public var importFingerprints: [ImportFingerprintBackupDTO]?
    
    public init(
        accounts: [AccountBackupDTO] = [],
        categories: [CategoryBackupDTO] = [],
        tags: [TagBackupDTO] = [],
        transactions: [TransactionBackupDTO] = [],
        budgets: [BudgetBackupDTO] = [],
        merchantRules: [MerchantRuleBackupDTO] = [],
        importFingerprints: [ImportFingerprintBackupDTO]? = []
    ) {
        self.accounts = accounts
        self.categories = categories
        self.tags = tags
        self.transactions = transactions
        self.budgets = budgets
        self.merchantRules = merchantRules
        self.importFingerprints = importFingerprints
    }
}

/// Root versioned JSON backup payload with SHA-256 integrity checksum.
public struct BackupPayload: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let appVersion: String
    public let exportedAt: Date
    public let checksum: String
    public let data: BackupData
    
    public init(
        schemaVersion: Int = 1,
        appVersion: String = "1.0.0",
        exportedAt: Date = Date(),
        checksum: String,
        data: BackupData
    ) {
        self.schemaVersion = schemaVersion
        self.appVersion = appVersion
        self.exportedAt = exportedAt
        self.checksum = checksum
        self.data = data
    }
}

/// Summary report returned after a successful backup restoration.
public struct BackupRestoreResult: Sendable, Equatable {
    public let accountsRestored: Int
    public let categoriesRestored: Int
    public let tagsRestored: Int
    public let transactionsRestored: Int
    public let budgetsRestored: Int
    public let rulesRestored: Int
    public let fingerprintsRestored: Int
    
    public init(
        accountsRestored: Int,
        categoriesRestored: Int,
        tagsRestored: Int,
        transactionsRestored: Int,
        budgetsRestored: Int,
        rulesRestored: Int,
        fingerprintsRestored: Int = 0
    ) {
        self.accountsRestored = accountsRestored
        self.categoriesRestored = categoriesRestored
        self.tagsRestored = tagsRestored
        self.transactionsRestored = transactionsRestored
        self.budgetsRestored = budgetsRestored
        self.rulesRestored = rulesRestored
        self.fingerprintsRestored = fingerprintsRestored
    }
    
    public var totalRecordsRestored: Int {
        accountsRestored + categoriesRestored + tagsRestored + transactionsRestored + budgetsRestored + rulesRestored + fingerprintsRestored
    }
}

// MARK: - Errors

public enum DataExportError: LocalizedError, Sendable, Equatable {
    case exportFailed(String)
    case backupDecodingFailed(String)
    case checksumMismatch(expected: String, actual: String)
    case unsupportedSchemaVersion(Int)
    case databasePurgeFailed(String)
    case databaseRestoreFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .exportFailed(let reason):
            return "Data export failed: \(reason)"
        case .backupDecodingFailed(let reason):
            return "Unable to decode backup file: \(reason)"
        case .checksumMismatch(let expected, let actual):
            return "Backup integrity checksum mismatch. Expected \(expected.prefix(8))..., but calculated \(actual.prefix(8))..."
        case .unsupportedSchemaVersion(let version):
            return "Unsupported backup schema version: \(version). Please update the application."
        case .databasePurgeFailed(let reason):
            return "Failed to reset database: \(reason)"
        case .databaseRestoreFailed(let reason):
            return "Failed to restore database: \(reason)"
        }
    }
}

// MARK: - Service Protocol

/// Service protocol defining CSV export, JSON backup creation, JSON restoration with SHA-256 checksum verification, and data purging.
public protocol DataExportServiceProtocol: Sendable {
    /// Exports transactions to a standardized CSV format with formula neutralization (AC-SEC-1).
    func exportTransactionsToCSV(startDate: Date?, endDate: Date?) async throws -> String
    
    /// Exports the full SwiftData database to a versioned JSON backup payload with SHA-256 checksum.
    func exportJSONBackup() async throws -> Data
    
    /// Validates a backup JSON payload's structure, schema version, and SHA-256 integrity checksum.
    func validateBackupPayload(_ data: Data) throws -> BackupPayload
    
    /// Restores full database state from a validated JSON backup payload.
    func restoreJSONBackup(from data: Data) async throws -> BackupRestoreResult
    
    /// Securely purges all user data and optionally seeds default system categories.
    func purgeAllData(restoreDefaultCategories: Bool) async throws
}
