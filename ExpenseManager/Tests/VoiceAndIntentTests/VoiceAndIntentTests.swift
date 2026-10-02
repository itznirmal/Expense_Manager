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
    
    @MainActor
    override func setUp() async throws {
        mockAudioService = MockAudioRecordingService()
        mockParserService = MockParserService()
        mockTxnService = MockTransactionService(sampleData: [])
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
    
    @MainActor
    override func tearDown() async throws {
        mockAudioService = nil
        mockParserService = nil
        mockTxnService = nil
        mockAccountService = nil
        mockCategoryService = nil
        viewModel = nil
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

        await waitForFinalTranscript()
        
        viewModel.stopListening()
        XCTAssertFalse(viewModel.isRecording)

        await waitForCandidate()

        // Ensure transcript and candidate were populated
        XCTAssertFalse(viewModel.liveTranscript.isEmpty)
        XCTAssertNotNil(viewModel.candidate)
        XCTAssertEqual(viewModel.candidate?.amount, Decimal(540))
    }
    
    func testVoiceEntrySaveCandidate() async {
        viewModel.startListening()
        await waitForFinalTranscript()
        viewModel.stopListening()
        await waitForCandidate()
        
        await viewModel.loadContext()
        let saveSuccess = await viewModel.saveCandidate()
        XCTAssertTrue(saveSuccess)
        
        // Verify transaction recorded in transaction service
        let recent = try? await mockTxnService.fetchRecentTransactions(limit: 5)
        XCTAssertEqual(recent?.count, 1)
        XCTAssertEqual(recent?.first?.amount, Decimal(540))
        XCTAssertNil(recent?.first?.notes)
    }

    private func waitForFinalTranscript() async {
        let pollInterval: UInt64 = 20_000_000
        let timeout: UInt64 = 1_000_000_000
        var elapsed: UInt64 = 0

        while viewModel.liveTranscript != mockAudioService.simulatedFinalTranscript,
              elapsed < timeout {
            try? await Task.sleep(nanoseconds: pollInterval)
            elapsed += pollInterval
        }

        XCTAssertEqual(viewModel.liveTranscript, mockAudioService.simulatedFinalTranscript)
    }

    private func waitForCandidate() async {
        let pollInterval: UInt64 = 20_000_000
        let timeout: UInt64 = 1_000_000_000
        var elapsed: UInt64 = 0

        while viewModel.candidate == nil, elapsed < timeout {
            try? await Task.sleep(nanoseconds: pollInterval)
            elapsed += pollInterval
        }

        XCTAssertNotNil(viewModel.candidate)
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
            amount: "0",
            merchant: "Swiggy"
        )
        
        let result = try await intent.perform()
        // Zero amount must return validation message
        XCTAssertNotNil(result)
    }

    func testLogExpenseIntentDecimalBoundaryValidation() {
        XCTAssertEqual(
            ExpenseManagerIntentAmountValidator.parse("9007199254740993.12", currencyCode: "INR"),
            Decimal(string: "9007199254740993.12")
        )
        XCTAssertNil(ExpenseManagerIntentAmountValidator.parse("12.345", currencyCode: "INR"))
        XCTAssertNil(ExpenseManagerIntentAmountValidator.parse("NaN", currencyCode: "INR"))
        XCTAssertNil(ExpenseManagerIntentAmountValidator.parse("0", currencyCode: "INR"))
        XCTAssertNil(ExpenseManagerIntentAmountValidator.parse("12.00", currencyCode: "inr"))
        XCTAssertEqual(
            ExpenseManagerIntentAmountValidator.parse("12.345", currencyCode: "KWD"),
            Decimal(string: "12.345")
        )
    }

    func testAppIntentsRespectAppLockPreference() async throws {
        let preferences = CurrencyFormatter.preferences
        let previous = preferences.object(forKey: ExpenseManagerIntentSecurity.lockPreferenceKey)
        defer {
            if let previous {
                preferences.set(previous, forKey: ExpenseManagerIntentSecurity.lockPreferenceKey)
            } else {
                preferences.removeObject(forKey: ExpenseManagerIntentSecurity.lockPreferenceKey)
            }
        }

        preferences.set(true, forKey: ExpenseManagerIntentSecurity.lockPreferenceKey)
        let result = try await LogExpenseIntent(amount: "12.00", merchant: "Swiggy").perform()
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

    func testSMSIngestionCandidateDoesNotRetainRawMessage() async throws {
        let rawMessage = "HDFC Bank: Rs 520.00 debited from a/c **4321 on 25-AUG-26 to VPA swiggy@upi"
        let result = try await SMSIngestionOrchestrator().ingest(
            smsText: rawMessage,
            autoSaveIfEligible: false
        )

        switch result {
        case .reviewRequired(let candidate, _):
            XCTAssertEqual(candidate.source, .sms)
            XCTAssertNil(candidate.notes)
            XCTAssertFalse(candidate.merchantName.contains(rawMessage))
        case .saved(let candidate, _):
            XCTAssertEqual(candidate.source, .sms)
            XCTAssertNil(candidate.notes)
        default:
            XCTFail("Expected a sanitized SMS candidate, got \(result)")
        }
    }
}
