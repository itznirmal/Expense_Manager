//
//  MockImportFingerprintService.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  In-Memory Mock Duplicate Detection Service.
//

import Foundation

/// In-memory mock implementation of ImportFingerprintServiceProtocol for previews and unit tests.
public final class MockImportFingerprintService: ImportFingerprintServiceProtocol, @unchecked Sendable {

    private let lock = NSLock()
    private var recordedFingerprints: [ImportFingerprintDTO] = []

    public init(sampleData: [ImportFingerprintDTO] = []) {
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
        referenceNumber: String? = nil,
        windowSeconds: TimeInterval = 300
    ) async throws -> Bool {
        lock.withLock {
            let normalized = merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let windowStart = date.addingTimeInterval(-windowSeconds)
            let windowEnd = date.addingTimeInterval(windowSeconds)

            return recordedFingerprints.contains { item in
                if let referenceNumber,
                   let itemReference = item.transactionReference,
                   !referenceNumber.isEmpty,
                   referenceNumber == itemReference {
                    return true
                }

                guard item.amount == amount,
                      item.approximateTimestamp >= windowStart,
                      item.approximateTimestamp <= windowEnd else {
                    return false
                }

                let itemMerchant = item.normalizedMerchant
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                let merchantMatches = itemMerchant == normalized ||
                    itemMerchant.contains(normalized) ||
                    normalized.contains(itemMerchant)
                guard merchantMatches else { return false }

                if let accountLastFour, let itemAccountLastFour = item.accountLastFour {
                    return accountLastFour == itemAccountLastFour
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
        let record = ImportFingerprintDTO(
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

    public func fetchRecentFingerprints(limit: Int) async throws -> [ImportFingerprintDTO] {
        lock.withLock {
            Array(recordedFingerprints.reversed().prefix(max(0, limit)))
        }
    }

    public func clear() {
        lock.withLock {
            recordedFingerprints.removeAll()
        }
    }
}
