//
//  ImportFingerprintService.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  SwiftData Implementation of Import Fingerprint Duplicate Detection Service.
//

import Foundation
import SwiftData
import CryptoKit

/// Service protocol defining duplicate ingestion detection operations.
public protocol ImportFingerprintServiceProtocol: Sendable {
    func hasFingerprint(hash: String) async throws -> Bool
    func isDuplicate(
        amount: Decimal,
        merchant: String,
        date: Date,
        accountLastFour: String?,
        windowSeconds: TimeInterval
    ) async throws -> Bool
    func recordFingerprint(
        sourceHash: String,
        amount: Decimal,
        merchant: String,
        accountLastFour: String?,
        reference: String?,
        timestamp: Date,
        source: String
    ) async throws
    func fetchRecentFingerprints(limit: Int) async throws -> [ImportFingerprintRecord]
}

/// SwiftData persistent implementation of the Import Fingerprint Duplicate Detection Service.
@MainActor
public final class ImportFingerprintService: ImportFingerprintServiceProtocol, Sendable {
    
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }
    
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    // MARK: - Duplicate Checking
    
    public func hasFingerprint(hash: String) async throws -> Bool {
        let descriptor = FetchDescriptor<ImportFingerprintRecord>(
            predicate: #Predicate { $0.sourceHash == hash }
        )
        let matches = try modelContext.fetch(descriptor)
        return !matches.isEmpty
    }
    
    public func isDuplicate(
        amount: Decimal,
        merchant: String,
        date: Date,
        accountLastFour: String?,
        windowSeconds: TimeInterval = 300 // 5-minute default window
    ) async throws -> Bool {
        let normalized = merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let windowStart = date.addingTimeInterval(-windowSeconds)
        let windowEnd = date.addingTimeInterval(windowSeconds)
        
        let descriptor = FetchDescriptor<ImportFingerprintRecord>(
            sortBy: [SortDescriptor(\.approximateTimestamp, order: .reverse)]
        )
        let records = try modelContext.fetch(descriptor)
        
        return records.contains { item in
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
    
    public func recordFingerprint(
        sourceHash: String,
        amount: Decimal,
        merchant: String,
        accountLastFour: String?,
        reference: String?,
        timestamp: Date = Date(),
        source: String = "manual"
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
        
        modelContext.insert(record)
        try modelContext.save()
    }
    
    public func fetchRecentFingerprints(limit: Int) async throws -> [ImportFingerprintRecord] {
        var descriptor = FetchDescriptor<ImportFingerprintRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - SHA-256 Hash Helper
    
    public static func computeSourceHash(
        amount: Decimal,
        merchant: String,
        timestamp: Date,
        reference: String?
    ) -> String {
        let payload = "\(amount.description)|\(merchant.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))|\(Int(timestamp.timeIntervalSince1970))|\(reference ?? "")"
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
