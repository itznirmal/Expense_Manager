//
//  DataExportService.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  SwiftData Implementation of DataExportServiceProtocol with CSV Formula Neutralization & SHA-256 Checksums.
//

import Foundation
import SwiftData
import CryptoKit

/// SwiftData persistent implementation of Data Export, JSON Backup, and Data Purge operations.
@MainActor
public final class DataExportService: DataExportServiceProtocol, Sendable {
    
    // MARK: - Properties
    
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }
    
    // MARK: - Initializer
    
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    // MARK: - CSV Export (with AC-SEC-1 Formula Neutralization)
    
    public func exportTransactionsToCSV(startDate: Date? = nil, endDate: Date? = nil) async throws -> String {
        let descriptor = FetchDescriptor<TransactionRecord>(
            sortBy: [SortDescriptor(\.transactionDate, order: .reverse)]
        )
        let records = try modelContext.fetch(descriptor)
        
        let filteredRecords = records.filter { record in
            if let start = startDate, record.transactionDate < start { return false }
            if let end = endDate, record.transactionDate > end { return false }
            return true
        }
        
        // Canonical CSV Header
        let headers = [
            "ID",
            "Date",
            "Type",
            "Amount",
            "Currency",
            "Merchant",
            "Category",
            "Account",
            "DestinationAccount",
            "PaymentMethod",
            "ReferenceNumber",
            "Source",
            "Notes",
            "Tags"
        ].joined(separator: ",")
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        
        var rows: [String] = [headers]
        
        for tx in filteredRecords {
            let rowFields: [String] = [
                CSVFormulaSanitizer.sanitizeAndEscape(tx.id),
                CSVFormulaSanitizer.sanitizeAndEscape(dateFormatter.string(from: tx.transactionDate)),
                CSVFormulaSanitizer.sanitizeAndEscape(tx.type),
                NSDecimalNumber(decimal: tx.amount).stringValue,
                CSVFormulaSanitizer.sanitizeAndEscape(tx.currencyCode),
                CSVFormulaSanitizer.sanitizeAndEscape(tx.merchantName),
                CSVFormulaSanitizer.sanitizeAndEscape(tx.category?.name ?? ""),
                CSVFormulaSanitizer.sanitizeAndEscape(tx.account?.name ?? ""),
                CSVFormulaSanitizer.sanitizeAndEscape(tx.destinationAccount?.name ?? ""),
                CSVFormulaSanitizer.sanitizeAndEscape(tx.paymentMethod ?? ""),
                CSVFormulaSanitizer.sanitizeAndEscape(tx.sourceReference ?? ""),
                CSVFormulaSanitizer.sanitizeAndEscape(tx.source),
                CSVFormulaSanitizer.sanitizeAndEscape(tx.notes ?? ""),
                CSVFormulaSanitizer.sanitizeAndEscape(tx.tags.joined(separator: "; "))
            ]
            rows.append(rowFields.joined(separator: ","))
        }
        
        return rows.joined(separator: "\r\n")
    }
    
    // MARK: - JSON Backup Export
    
    public func exportJSONBackup() async throws -> Data {
        // 1. Fetch Accounts
        let accountDescriptor = FetchDescriptor<AccountRecord>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        let accounts = try modelContext.fetch(accountDescriptor).map { acc in
            AccountBackupDTO(
                id: acc.id,
                name: acc.name,
                type: acc.type,
                currencyCode: acc.currencyCode,
                openingBalance: acc.openingBalance,
                currentBalance: acc.currentBalance,
                icon: acc.icon,
                colorToken: acc.colorToken,
                lastFour: acc.lastFour,
                isArchived: acc.isArchived,
                createdAt: acc.createdAt
            )
        }
        
        // 2. Fetch Categories
        let categoryDescriptor = FetchDescriptor<CategoryRecord>(sortBy: [SortDescriptor(\.sortOrder, order: .forward)])
        let categories = try modelContext.fetch(categoryDescriptor).map { cat in
            CategoryBackupDTO(
                id: cat.id,
                name: cat.name,
                parentCategoryID: cat.parentCategoryID,
                icon: cat.icon,
                colorToken: cat.colorToken,
                type: cat.type,
                isSystem: cat.isSystem,
                sortOrder: cat.sortOrder
            )
        }
        
        // 3. Fetch Tags
        let tagDescriptor = FetchDescriptor<TagRecord>(sortBy: [SortDescriptor(\.name, order: .forward)])
        let tags = try modelContext.fetch(tagDescriptor).map { tag in
            TagBackupDTO(
                id: tag.id,
                name: tag.name,
                colorToken: tag.colorToken,
                createdAt: tag.createdAt
            )
        }
        
        // 4. Fetch Transactions
        let txDescriptor = FetchDescriptor<TransactionRecord>(sortBy: [SortDescriptor(\.transactionDate, order: .forward)])
        let transactions = try modelContext.fetch(txDescriptor).map { tx in
            TransactionBackupDTO(
                id: tx.id,
                type: tx.type,
                amount: tx.amount,
                currencyCode: tx.currencyCode,
                merchantName: tx.merchantName,
                categoryID: tx.category?.id,
                accountID: tx.account?.id,
                destinationAccountID: tx.destinationAccount?.id,
                paymentMethod: tx.paymentMethod,
                transactionDate: tx.transactionDate,
                notes: tx.notes,
                tags: tx.tags,
                source: tx.source,
                sourceReference: tx.sourceReference,
                confidence: tx.confidence,
                createdAt: tx.createdAt,
                updatedAt: tx.updatedAt
            )
        }
        
        // 5. Fetch Budgets
        let budgetDescriptor = FetchDescriptor<BudgetRecord>(sortBy: [SortDescriptor(\.month, order: .forward)])
        let budgets = try modelContext.fetch(budgetDescriptor).map { bud in
            BudgetBackupDTO(
                id: bud.id,
                categoryID: bud.categoryID,
                limitAmount: bud.limitAmount,
                month: bud.month,
                alertThresholdPercent: bud.alertThresholdPercent,
                createdAt: bud.createdAt,
                updatedAt: bud.updatedAt
            )
        }
        
        // 6. Fetch Merchant Rules
        let ruleDescriptor = FetchDescriptor<MerchantRuleRecord>(sortBy: [SortDescriptor(\.confidence, order: .reverse)])
        let rules = try modelContext.fetch(ruleDescriptor).map { rule in
            MerchantRuleBackupDTO(
                id: rule.id,
                normalizedMerchant: rule.normalizedMerchant,
                preferredCategoryID: rule.preferredCategoryID,
                preferredAccountID: rule.preferredAccountID,
                preferredTags: rule.preferredTags,
                matchPattern: rule.matchPattern,
                confidence: rule.confidence,
                createdAt: rule.createdAt,
                updatedAt: rule.updatedAt
            )
        }
        
        // 7. Fetch Import Fingerprints (GT-68)
        let fpDescriptor = FetchDescriptor<ImportFingerprintRecord>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        let fingerprints = try modelContext.fetch(fpDescriptor).map { fp in
            ImportFingerprintBackupDTO(
                id: fp.id,
                sourceHash: fp.sourceHash,
                amount: fp.amount,
                normalizedMerchant: fp.normalizedMerchant,
                accountLastFour: fp.accountLastFour,
                transactionReference: fp.transactionReference,
                approximateTimestamp: fp.approximateTimestamp,
                source: fp.source,
                createdAt: fp.createdAt
            )
        }
        
        let backupData = BackupData(
            accounts: accounts,
            categories: categories,
            tags: tags,
            transactions: transactions,
            budgets: budgets,
            merchantRules: rules,
            importFingerprints: fingerprints
        )
        
        // Compute SHA-256 Checksum on deterministic JSON serialization
        let encoder = Self.createJSONEncoder()
        let backupDataBytes = try encoder.encode(backupData)
        let checksum = Self.computeSHA256(for: backupDataBytes)
        
        let payload = BackupPayload(
            schemaVersion: 1,
            appVersion: "1.0.0",
            exportedAt: Date(),
            checksum: checksum,
            data: backupData
        )
        
        return try encoder.encode(payload)
    }
    
    // MARK: - Validation & Restoration
    
    public func validateBackupPayload(_ data: Data) throws -> BackupPayload {
        let decoder = Self.createJSONDecoder()
        let payload: BackupPayload
        do {
            payload = try decoder.decode(BackupPayload.self, from: data)
        } catch {
            throw DataExportError.backupDecodingFailed(error.localizedDescription)
        }
        
        guard payload.schemaVersion <= 1 else {
            throw DataExportError.unsupportedSchemaVersion(payload.schemaVersion)
        }
        
        // Validate SHA-256 checksum integrity
        let encoder = Self.createJSONEncoder()
        let reencodedData = try encoder.encode(payload.data)
        let computedChecksum = Self.computeSHA256(for: reencodedData)
        
        guard computedChecksum.lowercased() == payload.checksum.lowercased() else {
            throw DataExportError.checksumMismatch(expected: payload.checksum, actual: computedChecksum)
        }
        
        return payload
    }
    
    public func restoreJSONBackup(from data: Data) async throws -> BackupRestoreResult {
        // Strict staging: Validate payload completely BEFORE mutating database (GT-68)
        let payload = try validateBackupPayload(data)
        
        do {
            // 1. Clear existing database
            try modelContext.delete(model: TransactionRecord.self)
            try modelContext.delete(model: AccountRecord.self)
            try modelContext.delete(model: CategoryRecord.self)
            try modelContext.delete(model: BudgetRecord.self)
            try modelContext.delete(model: MerchantRuleRecord.self)
            try modelContext.delete(model: TagRecord.self)
            try modelContext.delete(model: ImportFingerprintRecord.self)
            
            // 2. Restore Categories
            var categoryMap: [String: CategoryRecord] = [:]
            for cat in payload.data.categories {
                let record = CategoryRecord(
                    id: cat.id,
                    name: cat.name,
                    parentCategoryID: cat.parentCategoryID,
                    icon: cat.icon,
                    colorToken: cat.colorToken,
                    type: CategoryType(rawValue: cat.type) ?? .expense,
                    isSystem: cat.isSystem,
                    sortOrder: cat.sortOrder
                )
                modelContext.insert(record)
                categoryMap[cat.id] = record
            }
            
            // 3. Restore Accounts
            var accountMap: [String: AccountRecord] = [:]
            for acc in payload.data.accounts {
                let record = AccountRecord(
                    id: acc.id,
                    name: acc.name,
                    type: AccountType(rawValue: acc.type) ?? .bank,
                    currencyCode: acc.currencyCode,
                    openingBalance: acc.openingBalance,
                    currentBalance: acc.currentBalance,
                    icon: acc.icon,
                    colorToken: acc.colorToken,
                    lastFour: acc.lastFour,
                    isArchived: acc.isArchived,
                    createdAt: acc.createdAt
                )
                modelContext.insert(record)
                accountMap[acc.id] = record
            }
            
            // 4. Restore Tags
            for tag in payload.data.tags {
                let record = TagRecord(
                    id: tag.id,
                    name: tag.name,
                    colorToken: tag.colorToken,
                    createdAt: tag.createdAt
                )
                modelContext.insert(record)
            }
            
            // 5. Restore Transactions
            for tx in payload.data.transactions {
                let record = TransactionRecord(
                    id: tx.id,
                    type: TransactionType(rawValue: tx.type) ?? .expense,
                    amount: tx.amount,
                    currencyCode: tx.currencyCode,
                    merchantName: tx.merchantName,
                    category: tx.categoryID.flatMap { categoryMap[$0] },
                    account: tx.accountID.flatMap { accountMap[$0] },
                    destinationAccount: tx.destinationAccountID.flatMap { accountMap[$0] },
                    paymentMethod: tx.paymentMethod.flatMap { PaymentMethod(rawValue: $0) },
                    transactionDate: tx.transactionDate,
                    notes: tx.notes,
                    tags: tx.tags,
                    source: InputSource(rawValue: tx.source) ?? .manual,
                    sourceReference: tx.sourceReference,
                    confidence: tx.confidence,
                    createdAt: tx.createdAt,
                    updatedAt: tx.updatedAt
                )
                modelContext.insert(record)
            }
            
            // 6. Restore Budgets
            for bud in payload.data.budgets {
                let record = BudgetRecord(
                    id: bud.id,
                    categoryID: bud.categoryID,
                    limitAmount: bud.limitAmount,
                    month: bud.month,
                    alertThresholdPercent: bud.alertThresholdPercent,
                    createdAt: bud.createdAt,
                    updatedAt: bud.updatedAt
                )
                modelContext.insert(record)
            }
            
            // 7. Restore Merchant Rules
            for rule in payload.data.merchantRules {
                let record = MerchantRuleRecord(
                    id: rule.id,
                    normalizedMerchant: rule.normalizedMerchant,
                    preferredCategoryID: rule.preferredCategoryID,
                    preferredAccountID: rule.preferredAccountID,
                    preferredTags: rule.preferredTags,
                    matchPattern: rule.matchPattern,
                    confidence: rule.confidence,
                    createdAt: rule.createdAt,
                    updatedAt: rule.updatedAt
                )
                modelContext.insert(record)
            }
            
            // 8. Restore Import Fingerprints (GT-68)
            for fp in (payload.data.importFingerprints ?? []) {
                let record = ImportFingerprintRecord(
                    id: fp.id,
                    sourceHash: fp.sourceHash,
                    amount: fp.amount,
                    normalizedMerchant: fp.normalizedMerchant,
                    accountLastFour: fp.accountLastFour,
                    transactionReference: fp.transactionReference,
                    approximateTimestamp: fp.approximateTimestamp,
                    source: fp.source,
                    createdAt: fp.createdAt
                )
                modelContext.insert(record)
            }
            
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                throw error
            }
            
            return BackupRestoreResult(
                accountsRestored: payload.data.accounts.count,
                categoriesRestored: payload.data.categories.count,
                tagsRestored: payload.data.tags.count,
                transactionsRestored: payload.data.transactions.count,
                budgetsRestored: payload.data.budgets.count,
                rulesRestored: payload.data.merchantRules.count,
                fingerprintsRestored: payload.data.importFingerprints?.count ?? 0
            )
        } catch {
            throw DataExportError.databaseRestoreFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Data Purge / Factory Reset
    
    public func purgeAllData(restoreDefaultCategories: Bool = true) async throws {
        do {
            try modelContext.delete(model: TransactionRecord.self)
            try modelContext.delete(model: AccountRecord.self)
            try modelContext.delete(model: CategoryRecord.self)
            try modelContext.delete(model: BudgetRecord.self)
            try modelContext.delete(model: MerchantRuleRecord.self)
            try modelContext.delete(model: TagRecord.self)
            try modelContext.delete(model: ImportFingerprintRecord.self)
            
            if restoreDefaultCategories {
                let defaults: [(id: String, name: String, icon: String, color: String, type: CategoryType, sort: Int)] = [
                    ("cat_food", "Food & Dining", "fork.knife", "orange", .expense, 1),
                    ("cat_groceries", "Groceries", "cart.fill", "green", .expense, 2),
                    ("cat_transport", "Transport & Fuel", "car.fill", "blue", .expense, 3),
                    ("cat_shopping", "Shopping", "bag.fill", "purple", .expense, 4),
                    ("cat_bills", "Bills & Utilities", "bolt.fill", "yellow", .expense, 5),
                    ("cat_entertainment", "Entertainment", "film.fill", "pink", .expense, 6),
                    ("cat_health", "Health & Medical", "cross.fill", "red", .expense, 7),
                    ("cat_salary", "Salary", "banknote.fill", "green", .income, 8),
                    ("cat_investments", "Investments & Dividends", "chart.line.uptrend.xyaxis", "teal", .income, 9),
                    ("cat_freelance", "Freelance / Side Gig", "laptopcomputer", "indigo", .income, 10)
                ]
                
                for item in defaults {
                    let record = CategoryRecord(
                        id: item.id,
                        name: item.name,
                        parentCategoryID: nil,
                        icon: item.icon,
                        colorToken: item.color,
                        type: item.type,
                        isSystem: true,
                        sortOrder: item.sort
                    )
                    modelContext.insert(record)
                }
            }
            
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                throw error
            }
        } catch {
            throw DataExportError.databasePurgeFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Helper Methods
    
    public static func createJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return encoder
    }
    
    public static func createJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    
    public static func computeSHA256(for data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
