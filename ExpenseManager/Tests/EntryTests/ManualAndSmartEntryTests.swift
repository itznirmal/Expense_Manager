//
//  ManualAndSmartEntryTests.swift
//  ExpenseManagerTests
//
//  Created for Expense Manager iOS.
//  Unit Test Suite for Manual Entry, Smart Text, and Review Queue ViewModels.
//

import XCTest
@testable import ExpenseManager

final class ManualAndSmartEntryTests: XCTestCase {
    
    // MARK: - 1. Manual Transaction Composer ViewModel Tests
    
    @MainActor
    func testManualComposerInitialStateAndPresets() async {
        let vm = ManualTransactionComposerViewModel()
        XCTAssertEqual(vm.amount, .zero)
        XCTAssertFalse(vm.canSave)
        
        vm.applyPresetAmount(500)
        XCTAssertEqual(vm.amount, Decimal(500))
        
        vm.applyPresetAmount(1000)
        XCTAssertEqual(vm.amount, Decimal(1500))
    }
    
    @MainActor
    func testManualComposerValidation() async {
        let container = DependencyContainer.inMemoryEmpty()
        let appState = AppState()
        let vm = ManualTransactionComposerViewModel()
        
        // Cannot save with 0 amount
        let savedZero = await vm.saveTransaction(container: container, appState: appState)
        XCTAssertFalse(savedZero)
        XCTAssertNotNil(vm.validationError)
        
        // Enter amount and merchant
        vm.amountText = "750"
        vm.merchantName = "Groceries"
        XCTAssertTrue(vm.canSave)
        
        let savedValid = await vm.saveTransaction(container: container, appState: appState)
        XCTAssertTrue(savedValid)
        XCTAssertNil(vm.validationError)
        
        // Verify transaction is in store
        let txs = try? await container.transactionService.fetchRecentTransactions(limit: 5)
        XCTAssertEqual(txs?.count, 1)
        XCTAssertEqual(txs?.first?.amount, Decimal(750))
        XCTAssertEqual(txs?.first?.merchantName, "Groceries")
    }
    
    @MainActor
    func testManualComposerPrefilledCandidate() async {
        let candidate = TransactionCandidate(
            id: UUID(),
            type: .income,
            amount: Decimal(12000),
            currencyCode: "INR",
            merchantName: "Freelance",
            categorySuggestion: "Salary",
            accountSuggestion: "HDFC Bank",
            source: .smartText
        )
        
        let vm = ManualTransactionComposerViewModel(candidate: candidate)
        XCTAssertEqual(vm.type, .income)
        XCTAssertEqual(vm.amount, Decimal(12000))
        XCTAssertEqual(vm.merchantName, "Freelance")
        XCTAssertEqual(vm.selectedCategoryID, "Salary")
        XCTAssertEqual(vm.selectedAccountID, "HDFC Bank")
    }
    
    @MainActor
    func testManualComposerTags() {
        let vm = ManualTransactionComposerViewModel()
        vm.tagInput = "dinner"
        vm.addTag()
        XCTAssertEqual(vm.tags, ["dinner"])
        XCTAssertEqual(vm.tagInput, "")
        
        vm.removeTag("dinner")
        XCTAssertTrue(vm.tags.isEmpty)
    }
    
    // MARK: - 2. Smart Text Composer ViewModel Tests
    
    @MainActor
    func testSmartTextComposerLiveParse() async {
        let vm = SmartTextComposerViewModel()
        let parser = ParserOrchestrator()
        
        await vm.parse(text: "Swiggy 520 yesterday", parserService: parser)
        
        XCTAssertNotNil(vm.parsedCandidate)
        XCTAssertEqual(vm.parsedCandidate?.amount, Decimal(520))
        XCTAssertEqual(vm.parsedCandidate?.merchantName, "Swiggy")
        XCTAssertEqual(vm.parsedCandidate?.categorySuggestion, "Food & Dining")
    }
    
    @MainActor
    func testSmartTextComposerCategoryOverride() async {
        let container = DependencyContainer.inMemoryEmpty()
        let appState = AppState()
        let vm = SmartTextComposerViewModel()
        
        await vm.parse(text: "Starbucks 350", parserService: container.parserService)
        XCTAssertEqual(vm.parsedCandidate?.categorySuggestion, "Food & Dining")
        XCTAssertFalse(vm.hasOverriddenCategory)
        
        // Override category
        vm.overrideCategoryID = "Work Snacks"
        XCTAssertTrue(vm.hasOverriddenCategory)
        XCTAssertEqual(vm.activeCandidate?.categorySuggestion, "Work Snacks")
        
        let saved = await vm.saveTransaction(container: container, appState: appState)
        XCTAssertTrue(saved)
        
        let recents = try? await container.transactionService.fetchRecentTransactions(limit: 5)
        XCTAssertEqual(recents?.first?.categorySuggestion, "Work Snacks")
    }
    
    // MARK: - 3. Review Queue ViewModel Tests
    
    @MainActor
    func testReviewQueueFilteringAndAcceptance() async {
        let candidate1 = TransactionCandidate(
            id: UUID(),
            type: .expense,
            amount: Decimal(1200),
            merchantName: "Uber",
            confidence: ConfidenceScore(0.92),
            needsReview: true
        )
        let candidate2 = TransactionCandidate(
            id: UUID(),
            type: .expense,
            amount: Decimal(450),
            merchantName: "Unknown",
            confidence: ConfidenceScore(0.50),
            needsReview: true
        )
        
        let vm = ReviewQueueViewModel(initialCandidates: [candidate1, candidate2])
        XCTAssertEqual(vm.queuedCandidates.count, 2)
        XCTAssertEqual(vm.highConfidenceEligibleCount, 1)
        
        // Filter by low
        vm.selectedFilter = .low
        XCTAssertEqual(vm.filteredCandidates.count, 1)
        XCTAssertEqual(vm.filteredCandidates.first?.merchantName, "Unknown")
        
        // Accept candidate 1
        let container = DependencyContainer.inMemoryEmpty()
        let appState = AppState()
        
        await vm.acceptCandidate(candidate1, container: container, appState: appState)
        XCTAssertEqual(vm.queuedCandidates.count, 1)
        XCTAssertEqual(vm.queuedCandidates.first?.id, candidate2.id)
        
        // Discard candidate 2
        await vm.discardCandidate(candidate2, container: container, appState: appState)
        XCTAssertTrue(vm.queuedCandidates.isEmpty)
    }
}
