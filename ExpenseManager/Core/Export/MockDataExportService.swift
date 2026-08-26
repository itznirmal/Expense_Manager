//
//  MockDataExportService.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  In-Memory Mock Implementation of DataExportServiceProtocol for Previews and Unit Testing.
//

import Foundation

/// In-memory mock export service for previews and unit testing.
public final class MockDataExportService: DataExportServiceProtocol, @unchecked Sendable {
    
    // MARK: - Configurable Test State
    
    public var shouldFail: Bool = false
    public var failureError: DataExportError = .exportFailed("Mock simulated export failure")
    public var mockCSV: String?
    public var purged: Bool = false
    public var lastRestoreResult: BackupRestoreResult?
    
    public init(mockCSV: String? = nil) {
        self.mockCSV = mockCSV
    }
    
    // MARK: - DataExportServiceProtocol
    
    public func exportTransactionsToCSV(startDate: Date? = nil, endDate: Date? = nil) async throws -> String {
        if shouldFail { throw failureError }
        if let mock = mockCSV { return mock }
        
        let header = "ID,Date,Type,Amount,Currency,Merchant,Category,Account,DestinationAccount,PaymentMethod,ReferenceNumber,Source,Notes,Tags"
        let row1 = "tx_1,2026-08-25T12:00:00Z,expense,1450.00,INR,Swiggy,Food & Dining,HDFC Bank,,upi,UPI-123456,sms,\"Dinner with team\",food; personal"
        let row2 = "tx_2,2026-08-24T09:30:00Z,income,75000.00,INR,Acme Corp,Salary,HDFC Bank,,netBanking,NEFT-998877,manual,Monthly Salary,salary"
        let row3 = "tx_3,2026-08-23T18:15:00Z,expense,250.00,INR,\"'+cmd|' /C calc'!A0\",Shopping,Cash,,cash,,smartText,\"Formulas sanitized\",security"
        
        return [header, row1, row2, row3].joined(separator: "\r\n")
    }
    
    public func exportJSONBackup() async throws -> Data {
        if shouldFail { throw failureError }
        
        let sampleData = BackupData(
            accounts: [
                AccountBackupDTO(id: "acc_1", name: "HDFC Primary", type: "bank", currencyCode: "INR", openingBalance: 50000, currentBalance: 50000, icon: "building.columns.fill", colorToken: "blue", lastFour: "1234", isArchived: false, createdAt: Date())
            ],
            categories: [
                CategoryBackupDTO(id: "cat_1", name: "Food & Dining", parentCategoryID: nil, icon: "fork.knife", colorToken: "orange", type: "expense", isSystem: true, sortOrder: 1)
            ],
            tags: [
                TagBackupDTO(id: "tag_1", name: "personal", colorToken: "blue", createdAt: Date())
            ],
            transactions: [
                TransactionBackupDTO(id: "tx_1", type: "expense", amount: 1450, currencyCode: "INR", merchantName: "Swiggy", categoryID: "cat_1", accountID: "acc_1", destinationAccountID: nil, paymentMethod: "upi", transactionDate: Date(), notes: "Dinner", tags: ["personal"], source: "sms", sourceReference: "UPI-123", confidence: 0.95, createdAt: Date(), updatedAt: Date())
            ],
            budgets: [
                BudgetBackupDTO(id: "bud_1", categoryID: "cat_1", limitAmount: 15000, month: Date(), alertThresholdPercent: 80, createdAt: Date(), updatedAt: Date())
            ],
            merchantRules: [
                MerchantRuleBackupDTO(id: "rule_1", normalizedMerchant: "swiggy", preferredCategoryID: "cat_1", preferredAccountID: "acc_1", preferredTags: ["food"], matchPattern: "swiggy", confidence: 0.95, createdAt: Date(), updatedAt: Date())
            ],
            importFingerprints: [
                ImportFingerprintBackupDTO(id: "fp_1", sourceHash: "HASH123", amount: 1450, normalizedMerchant: "swiggy", accountLastFour: "1234", transactionReference: "UPI-123", approximateTimestamp: Date(), source: "sms", createdAt: Date())
            ]
        )
        
        let encoder = DataExportService.createJSONEncoder()
        let backupDataBytes = try encoder.encode(sampleData)
        let checksum = DataExportService.computeSHA256(for: backupDataBytes)
        
        let payload = BackupPayload(
            schemaVersion: 1,
            appVersion: "1.0.0",
            exportedAt: Date(),
            checksum: checksum,
            data: sampleData
        )
        
        return try encoder.encode(payload)
    }
    
    public func validateBackupPayload(_ data: Data) throws -> BackupPayload {
        if shouldFail { throw failureError }
        let decoder = DataExportService.createJSONDecoder()
        let payload = try decoder.decode(BackupPayload.self, from: data)
        
        let encoder = DataExportService.createJSONEncoder()
        let reencoded = try encoder.encode(payload.data)
        let computed = DataExportService.computeSHA256(for: reencoded)
        
        guard computed.lowercased() == payload.checksum.lowercased() else {
            throw DataExportError.checksumMismatch(expected: payload.checksum, actual: computed)
        }
        
        return payload
    }
    
    public func restoreJSONBackup(from data: Data) async throws -> BackupRestoreResult {
        let payload = try validateBackupPayload(data)
        let result = BackupRestoreResult(
            accountsRestored: payload.data.accounts.count,
            categoriesRestored: payload.data.categories.count,
            tagsRestored: payload.data.tags.count,
            transactionsRestored: payload.data.transactions.count,
            budgetsRestored: payload.data.budgets.count,
            rulesRestored: payload.data.merchantRules.count,
            fingerprintsRestored: payload.data.importFingerprints.count
        )
        self.lastRestoreResult = result
        return result
    }
    
    public func purgeAllData(restoreDefaultCategories: Bool = true) async throws {
        if shouldFail { throw failureError }
        self.purged = true
    }
}
