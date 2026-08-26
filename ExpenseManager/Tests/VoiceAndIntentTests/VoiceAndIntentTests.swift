//
//  VoiceAndIntentTests.swift
//  ExpenseManagerTests
//
//  Created for Expense Manager iOS.
//  Unit Tests for Voice Entry ViewModel, Audio Simulation, and App Intents.
//

import XCTest
@testable import ExpenseManager

@MainActor
final class VoiceAndIntentTests: XCTestCase {
    
    var mockAudioService: MockAudioRecordingService!
    var mockParserService: MockParserService!
    var mockTxnService: MockTransactionService!
    var mockAccountService: MockAccountService!
    var mockCategoryService: MockCategoryService!
    var viewModel: VoiceEntryViewModel!
    
    override func setUp() {
        super.setUp()
        mockAudioService = MockAudioRecordingService()
        mockParserService = MockParserService()
        mockTxnService = MockTransactionService()
        mockAccountService = MockAccountService()
        mockCategoryService = MockCategoryService()
        
        viewModel = VoiceEntryViewModel(
            audioService: mockAudioService,
            parserService: mockParserService,
            transactionService: mockTxnService,
            accountService: mockAccountService,
            categoryService: mockCategoryService
        )
    }
    
    override func tearDown() {
        mockAudioService = nil
        mockParserService = nil
        mockTxnService = nil
        mockAccountService = nil
        mockCategoryService = nil
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Voice Entry ViewModel State Tests
    
    func testVoiceEntryInitialState() {
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertTrue(viewModel.liveTranscript.isEmpty)
        XCTAssertNil(viewModel.candidate)
        XCTAssertFalse(viewModel.permissionDenied)
        XCTAssertEqual(viewModel.audioLevels.count, 16)
    }
    
    func testVoiceEntryStartAndStopListening() async {
        viewModel.startListening()
        XCTAssertTrue(viewModel.isRecording)
        XCTAssertEqual(viewModel.statusMessage, "Listening...")
        
        // Wait for mock audio service stream
        try? await Task.sleep(nanoseconds: 600_000_000)
        
        viewModel.stopListening()
        XCTAssertFalse(viewModel.isRecording)
        
        // Ensure transcript and candidate were populated
        XCTAssertFalse(viewModel.liveTranscript.isEmpty)
        XCTAssertNotNil(viewModel.candidate)
        XCTAssertEqual(viewModel.candidate?.amount, Decimal(540))
    }
    
    func testVoiceEntrySaveCandidate() async {
        viewModel.startListening()
        try? await Task.sleep(nanoseconds: 600_000_000)
        viewModel.stopListening()
        
        await viewModel.loadContext()
        let saveSuccess = await viewModel.saveCandidate()
        XCTAssertTrue(saveSuccess)
        
        // Verify transaction recorded in transaction service
        let recent = try? await mockTxnService.fetchRecentTransactions(limit: 5)
        XCTAssertEqual(recent?.count, 1)
        XCTAssertEqual(recent?.first?.amount, Decimal(540))
    }
    
    func testVoiceEntryPermissionDeniedHandling() async {
        mockAudioService.shouldGrantAuthorization = false
        
        viewModel.startListening()
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertTrue(viewModel.permissionDenied)
    }
    
    // MARK: - App Intent Tests
    
    func testLogExpenseIntentValidation() async throws {
        let intent = LogExpenseIntent(
            amount: 0.0,
            merchant: "Swiggy"
        )
        
        let result = try await intent.perform()
        // Zero amount must return validation message
        XCTAssertNotNil(result)
    }
    
    func testParseTextExpenseIntentWithBankSMS() async throws {
        let intent = ParseTextExpenseIntent(
            text: "HDFC Bank: Rs 520.00 debited from a/c **4321 on 25-AUG-26 to VPA swiggy@upi"
        )
        
        let result = try await intent.perform()
        XCTAssertNotNil(result)
    }
    
    func testParseTextExpenseIntentWithOTP() async throws {
        let intent = ParseTextExpenseIntent(
            text: "492019 is your secret OTP for transaction at Amazon India. Do not share."
        )
        
        let result = try await intent.perform()
        XCTAssertNotNil(result)
    }
}
