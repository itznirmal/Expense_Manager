//
//  DuplicatePreventionTests.swift
//  ExpenseManagerTests
//
//  Created for Expense Manager iOS.
//  Unit Tests for Duplicate Prevention Engine and Time-Window Ingestion Guards.
//

import XCTest
import SwiftData
@testable import ExpenseManager

final class DuplicatePreventionTests: XCTestCase {
    
    var mockFingerprintService: MockImportFingerprintService!
    var mockTxnService: MockTransactionService!
    var orchestrator: SMSIngestionOrchestrator!
    
    override func setUp() {
        super.setUp()
        mockFingerprintService = MockImportFingerprintService()
        mockTxnService = MockTransactionService()
        orchestrator = SMSIngestionOrchestrator(
            transactionService: mockTxnService,
            merchantRuleService: nil,
            fingerprintService: mockFingerprintService
        )
    }
    
    override func tearDown() {
        mockFingerprintService = nil
        mockTxnService = nil
        orchestrator = nil
        super.tearDown()
    }
    
    // MARK: - Exact SHA-256 Duplicate Blocking
    
    func testExactHashDuplicateDetection() async throws {
        let amount = Decimal(520.00)
        let merchant = "Swiggy"
        let timestamp = Date()
        let ref = "482019283741"
        
        let hash = ImportFingerprintService.computeSourceHash(
            amount: amount,
            merchant: merchant,
            accountLastFour: "4321",
            timestamp: timestamp,
            reference: ref
        )
        
        // Initial state: not duplicate
        let hasHashBefore = try await mockFingerprintService.hasFingerprint(hash: hash)
        XCTAssertFalse(hasHashBefore)
        
        // Record fingerprint
        try await mockFingerprintService.recordFingerprint(
            sourceHash: hash,
            amount: amount,
            merchant: merchant,
            accountLastFour: "4321",
            reference: ref,
            timestamp: timestamp,
            source: "sms"
        )
        
        // Subsequent state: duplicate detected
        let hasHashAfter = try await mockFingerprintService.hasFingerprint(hash: hash)
        XCTAssertTrue(hasHashAfter)
    }

    func testExactHashIncludesAccountIdentity() {
        let timestamp = Date()
        let firstAccountHash = ImportFingerprintService.computeSourceHash(
            amount: Decimal(520),
            merchant: "Swiggy",
            accountLastFour: "4321",
            timestamp: timestamp,
            reference: "REF-1"
        )
        let secondAccountHash = ImportFingerprintService.computeSourceHash(
            amount: Decimal(520),
            merchant: "Swiggy",
            accountLastFour: "9876",
            timestamp: timestamp,
            reference: "REF-1"
        )

        XCTAssertNotEqual(
            firstAccountHash,
            secondAccountHash,
            "The exact fingerprint must distinguish otherwise identical events from different accounts."
        )
    }
    
    // MARK: - Time Window (5-Minute) Duplicate Prevention
    
    func testTimeWindowFuzzyDuplicateDetection() async throws {
        let baseDate = Date()
        
        // Record initial transaction
        try await mockFingerprintService.recordFingerprint(
            sourceHash: "hash123",
            amount: Decimal(350.00),
            merchant: "Blinkit",
            accountLastFour: "9876",
            reference: "REF1",
            timestamp: baseDate,
            source: "sms"
        )
        
        // 1. Same transaction 2 minutes (120s) later -> Must be detected as duplicate
        let isDup2Min = try await mockFingerprintService.isDuplicate(
            amount: Decimal(350.00),
            merchant: "Blinkit",
            date: baseDate.addingTimeInterval(120),
            accountLastFour: "9876",
            windowSeconds: 300
        )
        XCTAssertTrue(isDup2Min, "Transaction within 5-minute window must be detected as duplicate.")
        
        // 2. Different amount ($450) -> Must NOT be duplicate
        let isDifferentAmount = try await mockFingerprintService.isDuplicate(
            amount: Decimal(450.00),
            merchant: "Blinkit",
            date: baseDate.addingTimeInterval(120),
            accountLastFour: "9876",
            windowSeconds: 300
        )
        XCTAssertFalse(isDifferentAmount, "Different amount should not trigger duplicate.")
        
        // 3. Different merchant (Zomato) -> Must NOT be duplicate
        let isDifferentMerchant = try await mockFingerprintService.isDuplicate(
            amount: Decimal(350.00),
            merchant: "Zomato",
            date: baseDate.addingTimeInterval(120),
            accountLastFour: "9876",
            windowSeconds: 300
        )
        XCTAssertFalse(isDifferentMerchant, "Different merchant should not trigger duplicate.")
        
        // 4. Same transaction 10 minutes (600s) later -> Outside window, NOT duplicate
        let isOutsideWindow = try await mockFingerprintService.isDuplicate(
            amount: Decimal(350.00),
            merchant: "Blinkit",
            date: baseDate.addingTimeInterval(600),
            accountLastFour: "9876",
            windowSeconds: 300
        )
        XCTAssertFalse(isOutsideWindow, "Transaction outside 5-minute window should not be duplicate.")
    }
    
    // MARK: - Orchestrator End-to-End Duplicate Handling
    
    func testOrchestratorBlocksDuplicateSMSIngestion() async throws {
        let sms = "HDFC Bank: Rs 520.00 debited from a/c **4321 on 25-AUG-26 to VPA swiggy@upi (UPI Ref no 482019283741). Avl bal: Rs 15,400.00"
        
        // First ingestion: should succeed and save
        let firstResult = try await orchestrator.ingest(smsText: sms, autoSaveIfEligible: true)
        if case .saved(let candidate, _) = firstResult {
            XCTAssertEqual(candidate.amount, Decimal(520.00))
            XCTAssertEqual(candidate.accountLastFour, "4321")
            XCTAssertNil(candidate.notes)
        } else {
            XCTFail("First ingestion expected to save, got: \(firstResult)")
        }
        
        // Second identical ingestion: should be blocked as duplicate
        let secondResult = try await orchestrator.ingest(smsText: sms, autoSaveIfEligible: true)
        if case .duplicate(let reason, let candidate) = secondResult {
            XCTAssertEqual(candidate.amount, Decimal(520.00))
            XCTAssertTrue(reason.contains("duplicate") || reason.contains("Duplicate"))
        } else {
            XCTFail("Second ingestion expected duplicate rejection, got: \(secondResult)")
        }
    }

    @MainActor
    func testSMSAccountMaskResolvesDifferentlyNamedAccountAndDoesNotRetainRawText() async throws {
        let container = try DatabaseContainer.inMemory()
        let accountService = SwiftDataAccountService(modelContainer: container)
        let accountID = try await accountService.createAccount(
            name: "Primary spending wallet",
            type: .bank,
            openingBalance: 10_000,
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: "4321"
        )
        let transactionService = SwiftDataTransactionService(modelContainer: container)
        let fingerprintService = ImportFingerprintService(modelContainer: container)
        let parser = SMSIngestionOrchestrator(
            transactionService: transactionService,
            fingerprintService: fingerprintService
        )
        let sms = "HDFC Bank: Rs 520.00 debited from a/c **4321 on 25-AUG-26 to VPA swiggy@upi (UPI Ref no MASK-1). Avl bal: Rs 9,480.00"

        let result = try await parser.ingest(smsText: sms, autoSaveIfEligible: true)
        guard case .saved(let candidate, _) = result else {
            XCTFail("Expected the masked account to resolve, got \(result)")
            return
        }
        XCTAssertEqual(candidate.accountLastFour, "4321")
        XCTAssertNil(candidate.notes)

        let records = try container.mainContext.fetch(FetchDescriptor<TransactionRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.account?.id, accountID)
        XCTAssertNil(records.first?.notes)
    }

    @MainActor
    func testAmbiguousSameBankMaskRoutesSMSToReviewWithoutArbitraryPosting() async throws {
        let container = try DatabaseContainer.inMemory()
        let accountService = SwiftDataAccountService(modelContainer: container)
        for name in ["HDFC daily", "HDFC travel"] {
            _ = try await accountService.createAccount(
                name: name,
                type: .bank,
                openingBalance: 10_000,
                currencyCode: "INR",
                icon: "building.columns.fill",
                colorToken: "blue",
                lastFour: "4321"
            )
        }
        let parser = SMSIngestionOrchestrator(
            transactionService: SwiftDataTransactionService(modelContainer: container),
            fingerprintService: ImportFingerprintService(modelContainer: container)
        )
        let sms = "HDFC Bank: Rs 520.00 debited from a/c **4321 on 25-AUG-26 to VPA swiggy@upi (UPI Ref no MASK-AMBIGUOUS-1). Avl bal: Rs 9,480.00"

        let result = try await parser.ingest(smsText: sms, autoSaveIfEligible: true)
        guard case .reviewRequired(let candidate, let warnings) = result else {
            XCTFail("Ambiguous account identity must route to review, got \(result)")
            return
        }
        XCTAssertTrue(candidate.needsReview)
        XCTAssertEqual(candidate.accountLastFour, "4321")
        XCTAssertTrue(warnings.contains { $0.localizedCaseInsensitiveContains("account") })
        let records = try container.mainContext.fetch(FetchDescriptor<TransactionRecord>())
        XCTAssertTrue(records.isEmpty)
    }
}
