//
//  MockImportFingerprintService.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  In-Memory Mock Duplicate Detection Service.
//

import Foundation

/// In-memory mock implementation of ImportFingerprintServiceProtocol for Previews and Unit Tests.
public final class MockImportFingerprintService: ImportFingerprintServiceProtocol, @unchecked Sendable {
    
    private let lock = NSLock()
    private var recordedFingerprints: [ImportFingerprintRecord] = []
    
    public init(sampleData: [ImportFingerprintRecord] = []) {
        self.recordedFingerprints = sampleData
    }
    
    public func hasFingerprint(hash: String) async throws -> Bool {
        lock.withLock {
            recordedFingerprints.contains { $0.sourceHash == hash }
        }
    }
    
    public func isDuplicate(
        amount: Decimal,
        merchant: String,
        date: Date,
        accountLastFour: String?,
        windowSeconds: TimeInterval = 300
    ) async throws -> Bool {
        lock.withLock {
            let normalized = merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let windowStart = date.addingTimeInterval(-windowSeconds)
            let windowEnd = date.addingTimeInterval(windowSeconds)
            
            return recordedFingerprints.contains { item in
                guard item.amount == amount else { return false }
                guard item.approximateTimestamp >= windowStart && item.approximateTimestamp <= windowEnd else { return false }
                
                let itemMerchant = item.normalizedMerchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let merchantMatches = itemMerchant == normalized || itemMerchant.contains(normalized) || normalized.contains(itemMerchant)
                guard merchantMatches else { return false }
                
                if let lastFour = accountLastFour, let itemLastFour = item.accountLastFour {
                    return lastFour == itemLastFour
                }
                return true
            }
        }
    }
    
    public func recordFingerprint(
        sourceHash: String,
        amount: Decimal,
        merchant: String,
        accountLastFour: String?,
        reference: String?,
        timestamp: Date = Date(),
        source: String = "mock"
    ) async throws {
        let record = ImportFingerprintRecord(
            id: UUID().uuidString,
            sourceHash: sourceHash,
            amount: amount,
            normalizedMerchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
            accountLastFour: accountLastFour,
            transactionReference: reference,
            approximateTimestamp: timestamp,
            source: source,
            createdAt: Date()
        )
        lock.withLock {
            recordedFingerprints.append(record)
        }
    }
    
    public func fetchRecentFingerprints(limit: Int) async throws -> [ImportFingerprintRecord] {
        lock.withLock {
            Array(recordedFingerprints.reversed().prefix(limit))
        }
    }
    
    public func clear() {
        lock.withLock {
            recordedFingerprints.removeAll()
        }
    }
}
