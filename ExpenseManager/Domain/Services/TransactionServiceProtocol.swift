//
//  TransactionServiceProtocol.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Transaction Ledger Service Protocol.
//

import Foundation

/// Service protocol defining core transaction persistence and query operations.
public protocol TransactionServiceProtocol: Sendable {
    
    /// Fetches the most recent transactions up to a maximum count.
    func fetchRecentTransactions(limit: Int) async throws -> [TransactionCandidate]
    
    /// Fetches all transactions within an optional date range and filters.
    func fetchTransactions(
        startDate: Date?,
        endDate: Date?,
        categoryID: String?,
        accountID: String?
    ) async throws -> [TransactionCandidate]
    
    /// Persists a new transaction candidate into the ledger.
    /// Returns the assigned transaction ID.
    @discardableResult
    func createTransaction(_ candidate: TransactionCandidate) async throws -> String
    
    /// Updates an existing transaction.
    func updateTransaction(id: String, candidate: TransactionCandidate) async throws
    
    /// Deletes a transaction by ID.
    func deleteTransaction(id: String) async throws
    
    /// Calculates aggregate expense and income totals for a specific date range.
    func calculateTotals(startDate: Date, endDate: Date) async throws -> (income: Decimal, expense: Decimal)
}
