//
//  MockTransactionService.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  In-Memory Mock Transaction Service for Previews and Unit Tests.
//

import Foundation

public final class MockTransactionService: TransactionServiceProtocol, @unchecked Sendable {
    private struct ImportedFingerprint {
        let sourceHash: String
        let amount: Decimal
        let merchant: String
        let accountLastFour: String?
        let reference: String?
        let timestamp: Date
    }

    private var transactions: [TransactionCandidate] = []
    private var importedFingerprints: [ImportedFingerprint] = []
    private let lock = NSLock()
    
    public init(sampleData: [TransactionCandidate]? = nil) {
        if let sampleData = sampleData {
            self.transactions = sampleData
        } else {
            self.transactions = Self.defaultSampleTransactions()
        }
    }
    
    public func fetchRecentTransactions(limit: Int) async throws -> [TransactionCandidate] {
        lock.lock()
        defer { lock.unlock() }
        let sorted = transactions
            .filter { !$0.needsReview }
            .sorted(by: { $0.transactionDate > $1.transactionDate })
        return Array(sorted.prefix(limit))
    }

    public func fetchPendingReviewTransactions() async throws -> [TransactionCandidate] {
        lock.lock()
        defer { lock.unlock() }
        return transactions
            .filter { $0.needsReview }
            .sorted(by: { $0.transactionDate > $1.transactionDate })
    }
    
    public func fetchTransactions(
        startDate: Date?,
        endDate: Date?,
        categoryID: String?,
        accountID: String?
    ) async throws -> [TransactionCandidate] {
        lock.lock()
        defer { lock.unlock() }
        return transactions.filter { item in
            if let start = startDate, item.transactionDate < start { return false }
            if let end = endDate, item.transactionDate > end { return false }
            if item.needsReview { return false }
            if let cat = categoryID, item.categorySuggestion != cat { return false }
            if let acc = accountID, item.accountSuggestion != acc { return false }
            return true
        }
    }
    
    public func createTransaction(_ candidate: TransactionCandidate) async throws -> String {
        lock.lock()
        defer { lock.unlock() }
        var normalized = candidate
        normalized.amount = abs(candidate.amount)
        transactions.append(normalized)
        return normalized.id.uuidString
    }

    public func createTransactionAndFingerprint(
        _ candidate: TransactionCandidate,
        sourceHash: String,
        accountLastFour: String?,
        source: String
    ) async throws -> TransactionImportResult {
        lock.lock()
        defer { lock.unlock() }

        let amount = abs(candidate.amount)
        let normalizedMerchant = candidate.merchantName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let windowStart = candidate.transactionDate.addingTimeInterval(-300)
        let windowEnd = candidate.transactionDate.addingTimeInterval(300)
        let isDuplicate = importedFingerprints.contains { fingerprint in
            if fingerprint.sourceHash == sourceHash {
                return true
            }
            if let reference = candidate.sourceReference,
               let existingReference = fingerprint.reference,
               !reference.isEmpty,
               reference == existingReference {
                return true
            }
            guard fingerprint.amount == amount,
                  fingerprint.timestamp >= windowStart,
                  fingerprint.timestamp <= windowEnd else {
                return false
            }
            let existingMerchant = fingerprint.merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let merchantMatches = existingMerchant == normalizedMerchant ||
                existingMerchant.contains(normalizedMerchant) ||
                normalizedMerchant.contains(existingMerchant)
            guard merchantMatches else { return false }

            if let accountLastFour,
               let existingAccountLastFour = fingerprint.accountLastFour {
                return accountLastFour == existingAccountLastFour
            }
            return true
        }

        if isDuplicate {
            return .duplicate
        }

        var normalized = candidate
        normalized.amount = amount
        transactions.append(normalized)
        importedFingerprints.append(
            ImportedFingerprint(
                sourceHash: sourceHash,
                amount: amount,
                merchant: candidate.merchantName,
                accountLastFour: accountLastFour,
                reference: candidate.sourceReference,
                timestamp: candidate.transactionDate
            )
        )
        return .saved(transactionID: normalized.id.uuidString)
    }
    
    public func updateTransaction(id: String, candidate: TransactionCandidate) async throws {
        lock.lock()
        defer { lock.unlock() }
        var normalized = candidate
        normalized.amount = abs(candidate.amount)
        if let index = transactions.firstIndex(where: { $0.id.uuidString == id }) {
            transactions[index] = normalized
        }
    }

    public func acceptTransaction(id: String) async throws {
        lock.lock()
        defer { lock.unlock() }
        guard let index = transactions.firstIndex(where: { $0.id.uuidString == id }) else {
            throw TransactionServiceError.transactionNotFound(id: id)
        }
        guard transactions[index].needsReview else { return }
        transactions[index].needsReview = false
    }
    
    public func deleteTransaction(id: String) async throws {
        lock.lock()
        defer { lock.unlock() }
        transactions.removeAll(where: { $0.id.uuidString == id })
    }
    
    public func calculateTotals(startDate: Date, endDate: Date, currencyCode: String) async throws -> (income: Decimal, expense: Decimal) {
        lock.lock()
        defer { lock.unlock() }
        var totalIncome: Decimal = .zero
        var totalExpense: Decimal = .zero
        
        for item in transactions where item.transactionDate >= startDate && item.transactionDate <= endDate && !item.needsReview && item.currencyCode == currencyCode {
            switch item.type {
            case .income:
                totalIncome += item.amount
            case .expense:
                totalExpense += item.amount
            case .refund:
                totalIncome += item.amount
            case .transfer, .cashWithdrawal, .unknown:
                break
            }
        }
        return (totalIncome, totalExpense)
    }
    
    public static func defaultSampleTransactions() -> [TransactionCandidate] {
        [
            TransactionCandidate(
                id: UUID(),
                type: .expense,
                amount: Decimal(520),
                currencyCode: "INR",
                merchantName: "Swiggy",
                categorySuggestion: "Dining",
                accountSuggestion: "HDFC Credit Card",
                paymentMethod: .creditCard,
                transactionDate: Date(),
                notes: "Dinner delivery",
                source: .smartText,
                confidence: .high
            ),
            TransactionCandidate(
                id: UUID(),
                type: .expense,
                amount: Decimal(1450),
                currencyCode: "INR",
                merchantName: "Shell Fuel Station",
                categorySuggestion: "Fuel",
                accountSuggestion: "HDFC Bank",
                paymentMethod: .upi,
                transactionDate: Date().addingTimeInterval(-86400),
                notes: "Petrol top-up",
                source: .sms,
                confidence: .high
            ),
            TransactionCandidate(
                id: UUID(),
                type: .income,
                amount: Decimal(85000),
                currencyCode: "INR",
                merchantName: "Acme Corp",
                categorySuggestion: "Salary",
                accountSuggestion: "HDFC Bank",
                paymentMethod: .netBanking,
                transactionDate: Date().addingTimeInterval(-86400 * 3),
                notes: "Monthly salary",
                source: .manual,
                confidence: .high
            ),
            TransactionCandidate(
                id: UUID(),
                type: .expense,
                amount: Decimal(350),
                currencyCode: "INR",
                merchantName: "Starbucks",
                categorySuggestion: "Coffee",
                accountSuggestion: "Apple Pay Wallet",
                paymentMethod: .wallet,
                transactionDate: Date().addingTimeInterval(-86400 * 5),
                notes: "Flat white with almond milk",
                source: .voice,
                confidence: .medium
            )
        ]
    }
}
