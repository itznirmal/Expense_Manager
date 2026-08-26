//
//  BudgetsEngineTests.swift
//  ExpenseManagerTests
//
//  Created for Expense Manager iOS.
//  Unit Tests for Budget Limits, Month Pace Projections, Daily Allowance & Alert Triggers.
//

import XCTest
import SwiftData
@testable import ExpenseManager

final class BudgetsEngineTests: XCTestCase {
    
    private var modelContainer: ModelContainer!
    private var dependencyContainer: DependencyContainer!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        modelContainer = try DatabaseContainer.inMemory()
        dependencyContainer = DependencyContainer.live(modelContainer: modelContainer)
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        dependencyContainer = nil
        try await super.tearDown()
    }
    
    // MARK: - 1. Budget Limits & Spent Tracking
    
    @MainActor
    func testBudgetLimitsAndSpentTracking() async throws {
        let now = Date()
        
        // 1. Set Dining category budget = ₹15,000
        try await dependencyContainer.budgetService.setBudget(
            categoryID: "cat_food",
            limitAmount: Decimal(15000),
            month: now,
            alertThresholdPercent: 80
        )
        
        // 2. Add an account and log ₹6,000 Dining expense
        let accId = try await dependencyContainer.accountService.createAccount(
            name: "Wallet",
            type: .cash,
            openingBalance: Decimal(20000),
            currencyCode: "INR",
            icon: "banknote.fill",
            colorToken: "green",
            lastFour: nil
        )
        
        try await dependencyContainer.transactionService.createTransaction(
            TransactionCandidate(
                type: .expense,
                amount: Decimal(6000),
                currencyCode: "INR",
                merchantName: "Restaurant",
                categorySuggestion: "cat_food",
                accountSuggestion: accId,
                transactionDate: now
            )
        )
        
        let vm = BudgetsViewModel()
        vm.selectedMonth = now
        await vm.loadBudgets(container: dependencyContainer)
        
        XCTAssertEqual(vm.categoryBudgets.count, 1)
        let foodBudget = vm.categoryBudgets.first
        XCTAssertEqual(foodBudget?.limitAmount, Decimal(15000))
        XCTAssertEqual(foodBudget?.spentAmount, Decimal(6000))
        XCTAssertEqual(foodBudget?.remainingAmount, Decimal(9000))
        XCTAssertEqual(foodBudget?.progressPercent ?? 0, 0.40, accuracy: 0.001)
        XCTAssertFalse(foodBudget?.isExceeded ?? true)
    }
    
    // MARK: - 2. Daily Budget Allowance Formula Test
    
    @MainActor
    func testDailyBudgetAllowanceCalculation() {
        let vm = BudgetsViewModel()
        let calendar = Calendar.current
        let now = Date()
        
        // Set up mock budget with limit ₹30,000 and spent ₹10,000 (Remaining = ₹20,000)
        vm.selectedMonth = now
        vm.budgets = [
            BudgetDTO(
                id: "b_test",
                categoryID: nil,
                categoryName: "Overall Monthly Budget",
                limitAmount: Decimal(30000),
                spentAmount: Decimal(10000),
                month: now,
                alertThresholdPercent: 80
            )
        ]
        
        let totalDays = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let currentDay = calendar.component(.day, from: now)
        let remainingDays = max(1, totalDays - currentDay + 1)
        
        XCTAssertEqual(vm.remainingTotalBudget, Decimal(20000))
        XCTAssertEqual(vm.remainingDaysInMonth, remainingDays)
        
        let expectedDaily = Decimal(20000) / Decimal(remainingDays)
        XCTAssertEqual(vm.dailyAllowance, expectedDaily, "Daily allowance must equal remaining budget / remaining days")
    }
    
    // MARK: - 3. Projected Month Spend Formula Test
    
    @MainActor
    func testProjectedMonthSpendFormula() {
        let vm = BudgetsViewModel()
        let calendar = Calendar.current
        let now = Date()
        
        vm.selectedMonth = now
        vm.budgets = [
            BudgetDTO(
                id: "b_overall",
                categoryID: nil,
                categoryName: "Overall Monthly Budget",
                limitAmount: Decimal(50000),
                spentAmount: Decimal(20000),
                month: now,
                alertThresholdPercent: 80
            )
        ]
        
        let totalDays = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let currentDay = max(1, calendar.component(.day, from: now))
        
        let expectedDailyBurn = Decimal(20000) / Decimal(currentDay)
        let expectedProjected = expectedDailyBurn * Decimal(totalDays)
        
        XCTAssertEqual(vm.projectedMonthSpend, expectedProjected, "Projected spend must match (spentSoFar / dayOfMonth) * daysInMonth")
    }
    
    // MARK: - 4. At-Risk Overspending Detection Test
    
    @MainActor
    func testAtRiskCategoryDetection() {
        let vm = BudgetsViewModel()
        let now = Date()
        
        vm.selectedMonth = now
        // Category 1: spent 90% (exceeded threshold)
        // Category 2: spent 20% (safe)
        vm.budgets = [
            BudgetDTO(
                id: "b_food",
                categoryID: "cat_food",
                categoryName: "Dining",
                limitAmount: Decimal(10000),
                spentAmount: Decimal(9500),
                month: now,
                alertThresholdPercent: 80
            ),
            BudgetDTO(
                id: "b_fuel",
                categoryID: "cat_fuel",
                categoryName: "Fuel",
                limitAmount: Decimal(5000),
                spentAmount: Decimal(1000),
                month: now,
                alertThresholdPercent: 80
            )
        ]
        
        let atRisk = vm.atRiskBudgets
        XCTAssertEqual(atRisk.count, 1)
        XCTAssertEqual(atRisk.first?.categoryID, "cat_food")
    }
}
