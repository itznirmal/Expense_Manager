//
//  DuplicatePreventionBenchmarkTests.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//

import XCTest
import SwiftData
@testable import ExpenseManager

@MainActor
final class DuplicatePreventionBenchmarkTests: XCTestCase {
    
    var container: ModelContainer!
    var service: ImportFingerprintService!
    
    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: ImportFingerprintRecord.self, configurations: config)
        service = ImportFingerprintService(modelContainer: container)
    }
    
    func testExactReferenceCollision() async throws {
        let date = Date()
        try await service.recordFingerprint(
            sourceHash: "hash123",
            amount: 500,
            merchant: "Swiggy",
            accountLastFour: "1234",
            reference: "REF123",
            timestamp: date,
            source: "sms"
        )
        
        let isDuplicate = try await service.isDuplicate(
            amount: 500,
            merchant: "Swiggy",
            date: date.addingTimeInterval(100),
            accountLastFour: "1234",
            referenceNumber: "REF123",
            windowSeconds: 300
        )
        
        XCTAssertTrue(isDuplicate)
    }
    
    func testTimeWindowCollision() async throws {
        let date = Date()
        try await service.recordFingerprint(
            sourceHash: "hash1",
            amount: 1500,
            merchant: "Amazon",
            accountLastFour: "5678",
            reference: nil,
            timestamp: date,
            source: "sms"
        )
        
        let isDuplicate = try await service.isDuplicate(
            amount: 1500,
            merchant: "Amazon",
            date: date.addingTimeInterval(60), // Within 5 mins
            accountLastFour: "5678",
            referenceNumber: nil,
            windowSeconds: 300
        )
        
        XCTAssertTrue(isDuplicate)
    }
    
    func testNonDuplicateLegitimateRepeat() async throws {
        let date = Date()
        try await service.recordFingerprint(
            sourceHash: "hash1",
            amount: 200,
            merchant: "Zomato",
            accountLastFour: "1111",
            reference: "REF_A",
            timestamp: date.addingTimeInterval(-600), // 10 mins ago
            source: "sms"
        )
        
        let isDuplicate = try await service.isDuplicate(
            amount: 200,
            merchant: "Zomato",
            date: date, // Now
            accountLastFour: "1111",
            referenceNumber: "REF_B", // Different ref
            windowSeconds: 300
        )
        
        XCTAssertFalse(isDuplicate)
    }
}
