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

/// Validates a decoded backup completely before any persistent store mutation.
/// The checksum is an unkeyed corruption check; it does not provide encryption or a signature.
public enum BackupPayloadValidator {
    public static func validate(_ data: Data) throws -> BackupPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let payload: BackupPayload
        do {
            payload = try decoder.decode(BackupPayload.self, from: data)
        } catch {
            throw DataExportError.backupDecodingFailed(error.localizedDescription)
        }

        guard payload.schemaVersion == 1 else {
            throw DataExportError.unsupportedSchemaVersion(payload.schemaVersion)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let canonicalData: Data
        do {
            canonicalData = try encoder.encode(payload.data)
        } catch {
            throw DataExportError.backupDecodingFailed("Unable to canonicalize backup payload: \(error.localizedDescription)")
        }

        let computedChecksum = computeSHA256(for: canonicalData)
        guard computedChecksum.caseInsensitiveCompare(payload.checksum) == .orderedSame else {
            throw DataExportError.checksumMismatch(expected: payload.checksum, actual: computedChecksum)
        }

        try validateData(payload.data)
        return payload
    }

    public static func computeSHA256(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func validateData(_ data: BackupData) throws {
        let accountIDs = try uniqueIDs(data.accounts.map(\.id), label: "accounts")
        let categoryIDs = try uniqueIDs(data.categories.map(\.id), label: "categories")
        _ = try uniqueIDs(data.tags.map(\.id), label: "tags")
        _ = try uniqueIDs(data.transactions.map(\.id), label: "transactions")
        _ = try uniqueIDs(data.budgets.map(\.id), label: "budgets")
        _ = try uniqueIDs(data.merchantRules.map(\.id), label: "merchant rules")
        _ = try uniqueIDs((data.importFingerprints ?? []).map(\.id), label: "import fingerprints")

        var accountsByID: [String: AccountBackupDTO] = [:]
        for account in data.accounts {
            guard AccountType(rawValue: account.type) != nil else {
                throw invalid("Unknown account type '\(account.type)' for account '\(account.id)'.")
            }
            try validateCurrency(account.currencyCode, label: "account \(account.id)")
            try validateFinite(account.openingBalance, label: "opening balance for account \(account.id)")
            try validateFinite(account.currentBalance, label: "current balance for account \(account.id)")
            try validateScale(account.openingBalance, currencyCode: account.currencyCode, label: "opening balance for account \(account.id)")
            try validateScale(account.currentBalance, currencyCode: account.currencyCode, label: "current balance for account \(account.id)")
            accountsByID[account.id] = account
        }

        for category in data.categories {
            guard CategoryType(rawValue: category.type) != nil else {
                throw invalid("Unknown category type '\(category.type)' for category '\(category.id)'.")
            }
            if let parentID = category.parentCategoryID {
                guard categoryIDs.contains(parentID), parentID != category.id else {
                    throw invalid("Category '\(category.id)' references an invalid parent category.")
                }
            }
        }

        for transaction in data.transactions {
            guard let type = TransactionType(rawValue: transaction.type), type != .unknown else {
                throw invalid("Unknown transaction type '\(transaction.type)' for transaction '\(transaction.id)'.")
            }
            guard InputSource(rawValue: transaction.source) != nil else {
                throw invalid("Unknown transaction source '\(transaction.source)' for transaction '\(transaction.id)'.")
            }
            if let paymentMethod = transaction.paymentMethod {
                guard PaymentMethod(rawValue: paymentMethod) != nil else {
                    throw invalid("Unknown payment method '\(paymentMethod)' for transaction '\(transaction.id)'.")
                }
            }
            try validateCurrency(transaction.currencyCode, label: "transaction \(transaction.id)")
            try validateFinite(transaction.amount, label: "amount for transaction \(transaction.id)")
            try validateScale(transaction.amount, currencyCode: transaction.currencyCode, label: "amount for transaction \(transaction.id)")
            guard transaction.amount >= .zero else {
                throw invalid("Negative amount found for transaction '\(transaction.id)'.")
            }
            guard transaction.isAccepted == !transaction.isPendingReview else {
                throw invalid("Review state is inconsistent for transaction '\(transaction.id)'.")
            }
            if let categoryID = transaction.categoryID {
                guard categoryIDs.contains(categoryID) else {
                    throw invalid("Transaction '\(transaction.id)' references an unknown category.")
                }
            }
            if let accountID = transaction.accountID {
                guard let account = accountsByID[accountID] else {
                    throw invalid("Transaction '\(transaction.id)' references an unknown account.")
                }
                guard account.currencyCode == transaction.currencyCode else {
                    throw invalid("Transaction '\(transaction.id)' currency does not match its account.")
                }
            }
            if let destinationID = transaction.destinationAccountID {
                guard let destination = accountsByID[destinationID] else {
                    throw invalid("Transaction '\(transaction.id)' references an unknown destination account.")
                }
                guard destination.currencyCode == transaction.currencyCode else {
                    throw invalid("Transaction '\(transaction.id)' currency does not match its destination account.")
                }
                if let accountID = transaction.accountID, accountID == destinationID {
                    throw invalid("Transaction '\(transaction.id)' uses the same source and destination account.")
                }
            }
            // Split replaces the original row, so parentTransactionID is historical
            // provenance rather than a live relationship that must exist in this payload.
            switch (transaction.parentTransactionID, transaction.splitGroupID) {
            case let (parentID?, splitGroupID?):
                guard !parentID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      parentID != transaction.id,
                      !splitGroupID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw invalid("Transaction '\(transaction.id)' has invalid split provenance metadata.")
                }
            case (nil, nil):
                break
            default:
                throw invalid("Transaction '\(transaction.id)' has incomplete split provenance metadata.")
            }
        }

        for budget in data.budgets {
            try validateCurrency(budget.currencyCode, label: "budget \(budget.id)")
            try validateFinite(budget.limitAmount, label: "limit for budget \(budget.id)")
            try validateScale(budget.limitAmount, currencyCode: budget.currencyCode, label: "limit for budget \(budget.id)")
            guard budget.limitAmount >= .zero else {
                throw invalid("Negative limit found for budget '\(budget.id)'.")
            }
            guard (0...100).contains(budget.alertThresholdPercent) else {
                throw invalid("Alert threshold for budget '\(budget.id)' must be between 0 and 100.")
            }
            if let categoryID = budget.categoryID {
                guard categoryIDs.contains(categoryID) else {
                    throw invalid("Budget '\(budget.id)' references an unknown category.")
                }
            }
        }

        for rule in data.merchantRules {
            try validateFinite(rule.confidence, label: "confidence for merchant rule \(rule.id)")
            guard (0.0...1.0).contains(rule.confidence) else {
                throw invalid("Confidence for merchant rule '\(rule.id)' must be between 0 and 1.")
            }
            if let categoryID = rule.preferredCategoryID {
                guard categoryIDs.contains(categoryID) else {
                    throw invalid("Merchant rule '\(rule.id)' references an unknown category.")
                }
            }
            if let accountID = rule.preferredAccountID {
                guard accountIDs.contains(accountID) else {
                    throw invalid("Merchant rule '\(rule.id)' references an unknown account.")
                }
            }
        }

        for fingerprint in data.importFingerprints ?? [] {
            try validateFinite(fingerprint.amount, label: "amount for import fingerprint \(fingerprint.id)")
            guard fingerprint.amount >= .zero else {
                throw invalid("Negative amount found for import fingerprint '\(fingerprint.id)'.")
            }
            guard !fingerprint.sourceHash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw invalid("Import fingerprint '\(fingerprint.id)' has an empty source hash.")
            }
        }

        // Transaction tags and learned-rule tags are user-facing labels in the current schema,
        // rather than relationship keys to the TagRecord collection.
    }

    private static func uniqueIDs(_ ids: [String], label: String) throws -> Set<String> {
        var result = Set<String>(minimumCapacity: ids.count)
        for id in ids {
            guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw invalid("Empty identifier found in \(label).")
            }
            guard result.insert(id).inserted else {
                throw invalid("Duplicate identifier '\(id)' found in \(label).")
            }
        }
        return result
    }

    private static func validateCurrency(_ code: String, label: String) throws {
        let scalars = Array(code.unicodeScalars)
        guard scalars.count == 3,
              scalars.allSatisfy({ $0.value >= 65 && $0.value <= 90 }),
              Locale.commonISOCurrencyCodes.contains(code) else {
            throw invalid("Invalid currency code '\(code)' for \(label).")
        }
    }

    private static func validateFinite(_ amount: Decimal, label: String) throws {
        guard !amount.isNaN else {
            throw invalid("Non-finite number found for \(label).")
        }
    }

    private static func validateFinite(_ value: Double, label: String) throws {
        guard value.isFinite else {
            throw invalid("Non-finite number found for \(label).")
        }
    }

    private static func validateScale(_ amount: Decimal, currencyCode: String, label: String) throws {
        let fractionDigits = CurrencyFormatter.fractionDigits(for: currencyCode)
        var original = amount
        var rounded = amount
        NSDecimalRound(&rounded, &original, fractionDigits, .plain)
        guard rounded == amount else {
            throw invalid("Too many fractional digits for \(label).")
        }
    }

    private static func invalid(_ reason: String) -> DataExportError {
        .backupDecodingFailed(reason)
    }
}

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
            return record.isPosted
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
                updatedAt: tx.updatedAt,
                isPendingReview: tx.isPendingReview,
                isAccepted: tx.isAccepted,
                reviewReasons: tx.reviewReasons,
                parentTransactionID: tx.parentTransactionID,
                splitGroupID: tx.splitGroupID
            )
        }
        
        // 5. Fetch Budgets
        let budgetDescriptor = FetchDescriptor<BudgetRecord>(sortBy: [SortDescriptor(\.month, order: .forward)])
        let budgets = try modelContext.fetch(budgetDescriptor).map { bud in
            BudgetBackupDTO(
                id: bud.id,
                categoryID: bud.categoryID,
                currencyCode: bud.currencyCode,
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
    
    /// Pure backup validation that performs no store I/O or mutation.
    public nonisolated static func validateBackupPayloadData(_ data: Data) throws -> BackupPayload {
        try BackupPayloadValidator.validate(data)
    }

    public func validateBackupPayload(_ data: Data) throws -> BackupPayload {
        try Self.validateBackupPayloadData(data)
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
                guard let categoryType = CategoryType(rawValue: cat.type) else {
                    throw DataExportError.backupDecodingFailed("Unknown category type '\(cat.type)'.")
                }
                let record = CategoryRecord(
                    id: cat.id,
                    name: cat.name,
                    parentCategoryID: cat.parentCategoryID,
                    icon: cat.icon,
                    colorToken: cat.colorToken,
                    type: categoryType,
                    isSystem: cat.isSystem,
                    sortOrder: cat.sortOrder
                )
                modelContext.insert(record)
                categoryMap[cat.id] = record
            }
            
            // 3. Restore Accounts
            var accountMap: [String: AccountRecord] = [:]
            for acc in payload.data.accounts {
                guard let accountType = AccountType(rawValue: acc.type) else {
                    throw DataExportError.backupDecodingFailed("Unknown account type '\(acc.type)'.")
                }
                let record = AccountRecord(
                    id: acc.id,
                    name: acc.name,
                    type: accountType,
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
                guard let transactionType = TransactionType(rawValue: tx.type),
                      let inputSource = InputSource(rawValue: tx.source) else {
                    throw DataExportError.backupDecodingFailed("Unknown transaction enum value for '\(tx.id)'.")
                }
                let paymentMethod = tx.paymentMethod.flatMap(PaymentMethod.init(rawValue:))
                let record = TransactionRecord(
                    id: tx.id,
                    type: transactionType,
                    amount: tx.amount,
                    currencyCode: tx.currencyCode,
                    merchantName: tx.merchantName,
                    category: tx.categoryID.flatMap { categoryMap[$0] },
                    account: tx.accountID.flatMap { accountMap[$0] },
                    destinationAccount: tx.destinationAccountID.flatMap { accountMap[$0] },
                    paymentMethod: paymentMethod,
                    transactionDate: tx.transactionDate,
                    notes: tx.notes,
                    tags: tx.tags,
                    source: inputSource,
                    sourceReference: tx.sourceReference,
                    confidence: tx.confidence,
                    createdAt: tx.createdAt,
                    updatedAt: tx.updatedAt
                )
                record.isPendingReview = tx.isPendingReview
                record.isAccepted = tx.isAccepted
                record.reviewReasons = tx.reviewReasons
                record.parentTransactionID = tx.parentTransactionID
                record.splitGroupID = tx.splitGroupID
                modelContext.insert(record)
            }
            
            // 6. Restore Budgets
            for bud in payload.data.budgets {
                let record = BudgetRecord(
                    id: bud.id,
                    categoryID: bud.categoryID,
                    currencyCode: bud.currencyCode,
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
            // All replacement work is staged in this context until the single save below.
            // Rollback restores the prior store when any delete, insert, or save fails.
            modelContext.rollback()
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
