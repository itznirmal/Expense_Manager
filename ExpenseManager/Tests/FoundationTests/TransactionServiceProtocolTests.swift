//
//  TransactionServiceProtocolTests.swift
//  ExpenseManagerTests
//
//  Focused conformance and pending-review behavior tests for transaction services.
//

import XCTest
@testable import ExpenseManager

final class TransactionServiceProtocolTests: XCTestCase {
    func testMockTransactionServiceConformsAndSeparatesPendingTransactions() async throws {
        let pending = TransactionCandidate(
            type: .expense,
            amount: Decimal(250),
            currencyCode: "INR",
            merchantName: "Pending Merchant",
            source: .sms,
            needsReview: true
        )
        let accepted = TransactionCandidate(
            type: .income,
            amount: Decimal(1_000),
            currencyCode: "INR",
            merchantName: "Accepted Merchant",
            source: .manual
        )
        let acceptedNonINR = TransactionCandidate(
            type: .expense,
            amount: Decimal(50),
            currencyCode: "USD",
            merchantName: "Accepted USD Merchant",
            source: .manual
        )
        let service: any TransactionServiceProtocol = MockTransactionService(sampleData: [pending, accepted, acceptedNonINR])

        let pendingTransactions = try await service.fetchPendingReviewTransactions()
        XCTAssertEqual(pendingTransactions.map(\.id), [pending.id])

        let recentTransactions = try await service.fetchRecentTransactions(limit: 10)
        XCTAssertEqual(recentTransactions.count, 2)
        XCTAssertTrue(recentTransactions.contains(where: { $0.id == accepted.id }))
        XCTAssertTrue(recentTransactions.contains(where: { $0.id == acceptedNonINR.id }))

        let totals = try await service.calculateTotals(
            startDate: Date.distantPast,
            endDate: Date.distantFuture,
            currencyCode: "INR"
        )
        XCTAssertEqual(totals.income, Decimal(1_000))
        XCTAssertEqual(totals.expense, .zero, "Accepted USD expenses must be excluded from INR totals")

        try await service.acceptTransaction(id: pending.id.uuidString)
        let pendingAfterAcceptance = try await service.fetchPendingReviewTransactions()
        XCTAssertTrue(pendingAfterAcceptance.isEmpty)
        let recentAfterAcceptance = try await service.fetchRecentTransactions(limit: 10)
        XCTAssertEqual(recentAfterAcceptance.count, 3)
    }
}
