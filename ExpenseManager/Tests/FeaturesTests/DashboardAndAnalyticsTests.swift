//
//  DashboardAndAnalyticsTests.swift
//  ExpenseManagerTests
//
//  Created for Expense Manager iOS.
//  Unit Tests for Glanceable Dashboard, Net Worth, Cash Flows & Financial Analytics.
//

import XCTest
import SwiftData
@testable import ExpenseManager

final class DashboardAndAnalyticsTests: XCTestCase {
    
    private var modelContainer: ModelContainer!
    private var dependencyContainer: DependencyContainer!
    private var appState: AppState!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        modelContainer = try DatabaseContainer.inMemory()
        dependencyContainer = DependencyContainer.live(modelContainer: modelContainer)
        appState = AppState()
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        dependencyContainer = nil
        appState = nil
        try await super.tearDown()
    }
    
    // MARK: - 1. Net Worth & Asset / Liability Segregation Tests
    
    @MainActor
    func testNetWorthAssetsAndLiabilitiesCalculation() async throws {
        // 1. Create Bank Account with ₹1,00,000 (Asset)
        try await dependencyContainer.accountService.createAccount(
            name: "HDFC Savings",
            type: .bank,
            openingBalance: Decimal(100000),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: "1111"
        )
        
        // 2. Create Cash Wallet with ₹5,000 (Asset)
        try await dependencyContainer.accountService.createAccount(
            name: "Cash in Hand",
            type: .cash,
            openingBalance: Decimal(5000),
            currencyCode: "INR",
            icon: "banknote.fill",
            colorToken: "green",
            lastFour: nil
        )
        
        // 3. Create Credit Card with -₹15,000 (Liability / Debt)
        try await dependencyContainer.accountService.createAccount(
            name: "HDFC Regalia",
            type: .creditCard,
            openingBalance: Decimal(-15000),
            currencyCode: "INR",
            icon: "creditcard.fill",
            colorToken: "purple",
            lastFour: "9999"
        )
        
        let viewModel = DashboardViewModel()
        await viewModel.loadDashboardData(container: dependencyContainer, appState: appState)
        
        XCTAssertEqual(viewModel.totalAssets, Decimal(105000), "Assets must equal 100,000 + 5,000 = 105,000")
        XCTAssertEqual(viewModel.totalLiabilities, Decimal(15000), "Liabilities must equal 15,000")
        XCTAssertEqual(viewModel.netWorth, Decimal(90000), "Net Worth must equal Assets (105,000) - Liabilities (15,000) = 90,000")
    }
    
    // MARK: - 2. Monthly Cash Flow & Exact Savings Rate Tests
    
    @MainActor
    func testMonthlyCashFlowAndSavingsRateCalculation() async throws {
        let bankId = try await dependencyContainer.accountService.createAccount(
            name: "Main Checking",
            type: .bank,
            openingBalance: Decimal(10000),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: "1234"
        )
        
        let now = Date()
        
        // Add Salary Income of ₹1,00,000
        try await dependencyContainer.transactionService.createTransaction(
            TransactionCandidate(
                type: .income,
                amount: Decimal(100000),
                currencyCode: "INR",
                merchantName: "Acme Corp",
                categorySuggestion: "Salary",
                accountSuggestion: bankId,
                transactionDate: now
            )
        )
        
        // Add Rent Expense of ₹30,000
        try await dependencyContainer.transactionService.createTransaction(
            TransactionCandidate(
                type: .expense,
                amount: Decimal(30000),
                currencyCode: "INR",
                merchantName: "Landlord",
                categorySuggestion: "Rent",
                accountSuggestion: bankId,
                transactionDate: now
            )
        )
        
        // Add Groceries Expense of ₹10,000
        try await dependencyContainer.transactionService.createTransaction(
            TransactionCandidate(
                type: .expense,
                amount: Decimal(10000),
                currencyCode: "INR",
                merchantName: "Supermarket",
                categorySuggestion: "Groceries",
                accountSuggestion: bankId,
                transactionDate: now
            )
        )
        
        let viewModel = DashboardViewModel()
        await viewModel.loadDashboardData(container: dependencyContainer, appState: appState)
        
        XCTAssertEqual(viewModel.monthlyIncome, Decimal(100000))
        XCTAssertEqual(viewModel.monthlyExpense, Decimal(40000))
        XCTAssertEqual(viewModel.netSavings, Decimal(60000), "100,000 - 40,000 = 60,000")
        
        // Savings rate = (100,000 - 40,000) / 100,000 * 100 = 60.0%
        XCTAssertEqual(viewModel.savingsRate, 60.0, accuracy: 0.01)
    }
    
    // MARK: - 3. Analytics Time Series & Category Distributions
    
    @MainActor
    func testAnalyticsTimeHorizonAggregates() async throws {
        let bankId = try await dependencyContainer.accountService.createAccount(
            name: "Checking",
            type: .bank,
            openingBalance: Decimal(50000),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: "5555"
        )
        
        let now = Date()
        
        // Add expense transactions across different categories
        try await dependencyContainer.transactionService.createTransaction(
            TransactionCandidate(
                type: .expense,
                amount: Decimal(5000),
                currencyCode: "INR",
                merchantName: "Food Place",
                categorySuggestion: "Food & Dining",
                accountSuggestion: bankId,
                transactionDate: now
            )
        )
        
        try await dependencyContainer.transactionService.createTransaction(
            TransactionCandidate(
                type: .expense,
                amount: Decimal(15000),
                currencyCode: "INR",
                merchantName: "Flight Ticket",
                categorySuggestion: "Travel",
                accountSuggestion: bankId,
                transactionDate: now
            )
        )
        
        let analyticsVM = AnalyticsViewModel()
        await analyticsVM.loadAnalytics(container: dependencyContainer)
        
        XCTAssertEqual(analyticsVM.totalExpense, Decimal(20000))
        XCTAssertEqual(analyticsVM.categoryBreakdowns.count, 2)
        
        let topCategory = analyticsVM.categoryBreakdowns.first
        XCTAssertEqual(topCategory?.categoryName, "Travel")
        XCTAssertEqual(topCategory?.totalAmount, Decimal(15000))
        XCTAssertEqual(topCategory?.percentage ?? 0, 0.75, accuracy: 0.01, "15,000 / 20,000 = 75%")
    }
    
    // MARK: - 4. Merchant Intelligence Subscription Detection & Anomaly Detection
    
    @MainActor
    func testMerchantIntelligenceSubscriptionAndAnomalyDetection() {
        let intelligenceService = MerchantIntelligenceService()
        let now = Date()
        let calendar = Calendar.current
        
        // Create 3 consecutive monthly Netflix charges of ₹649
        let d1 = calendar.date(byAdding: .day, value: -60, to: now)!
        let d2 = calendar.date(byAdding: .day, value: -30, to: now)!
        let d3 = now
        
        let txList = [
            TransactionCandidate(
                type: .expense,
                amount: Decimal(649),
                currencyCode: "INR",
                merchantName: "Netflix",
                categorySuggestion: "Entertainment",
                transactionDate: d1
            ),
            TransactionCandidate(
                type: .expense,
                amount: Decimal(649),
                currencyCode: "INR",
                merchantName: "Netflix",
                categorySuggestion: "Entertainment",
                transactionDate: d2
            ),
            TransactionCandidate(
                type: .expense,
                amount: Decimal(649),
                currencyCode: "INR",
                merchantName: "Netflix",
                categorySuggestion: "Entertainment",
                transactionDate: d3
            ),
            // Normal Swiggy orders
            TransactionCandidate(
                type: .expense,
                amount: Decimal(400),
                currencyCode: "INR",
                merchantName: "Swiggy",
                categorySuggestion: "Dining",
                transactionDate: calendar.date(byAdding: .day, value: -20, to: now)!
            ),
            TransactionCandidate(
                type: .expense,
                amount: Decimal(500),
                currencyCode: "INR",
                merchantName: "Swiggy",
                categorySuggestion: "Dining",
                transactionDate: calendar.date(byAdding: .day, value: -10, to: now)!
            ),
            // Anomalous Swiggy order (₹3,500 > 2x average ₹450)
            TransactionCandidate(
                type: .expense,
                amount: Decimal(3500),
                currencyCode: "INR",
                merchantName: "Swiggy",
                categorySuggestion: "Dining",
                transactionDate: now
            )
        ]
        
        // 1. Subscription detection
        let subscriptions = intelligenceService.detectRecurringSubscriptions(from: txList)
        XCTAssertFalse(subscriptions.isEmpty)
        let netflixSub = subscriptions.first(where: { $0.merchantName == "Netflix" })
        XCTAssertNotNil(netflixSub)
        XCTAssertEqual(netflixSub?.amount, Decimal(649))
        XCTAssertEqual(netflixSub?.frequency, .monthly)
        
        // 2. Anomaly identification
        let anomalies = intelligenceService.identifyAnomalies(in: txList, historicalDays: 90)
        XCTAssertFalse(anomalies.isEmpty)
        let swiggyAnomaly = anomalies.first(where: { $0.transaction.merchantName == "Swiggy" })
        XCTAssertNotNil(swiggyAnomaly)
        XCTAssertEqual(swiggyAnomaly?.transaction.amount, Decimal(3500))
        XCTAssertGreaterThan(swiggyAnomaly?.ratio ?? 0, 2.0)
    }
    
    // MARK: - 5. Multi-Currency Separation Tests
    
    @MainActor
    func testMultiCurrencySeparationOnDashboard() async throws {
        // 1. Create INR Account with ₹50,000
        try await dependencyContainer.accountService.createAccount(
            name: "HDFC Savings",
            type: .bank,
            openingBalance: Decimal(50000),
            currencyCode: "INR",
            icon: "building.columns.fill",
            colorToken: "blue",
            lastFour: "1234"
        )
        
        // 2. Create USD Account with $1,500
        try await dependencyContainer.accountService.createAccount(
            name: "US Chase Checking",
            type: .bank,
            openingBalance: Decimal(1500),
            currencyCode: "USD",
            icon: "dollarsign.circle.fill",
            colorToken: "green",
            lastFour: "5678"
        )
        
        // 3. Create EUR Account with €300
        try await dependencyContainer.accountService.createAccount(
            name: "EU N26",
            type: .bank,
            openingBalance: Decimal(300),
            currencyCode: "EUR",
            icon: "eurosign.circle.fill",
            colorToken: "orange",
            lastFour: "9012"
        )
        
        let viewModel = DashboardViewModel()
        await viewModel.loadDashboardData(container: dependencyContainer, appState: appState)
        
        // Base currency (INR) must only include INR accounts
        XCTAssertEqual(viewModel.netWorth, Decimal(50000))
        XCTAssertEqual(viewModel.totalAssets, Decimal(50000))
        
        // Other currencies must be segregated cleanly
        XCTAssertEqual(viewModel.otherCurrencyBalances.count, 2)
        let usdBalance = viewModel.otherCurrencyBalances.first(where: { $0.currencyCode == "USD" })
        XCTAssertNotNil(usdBalance)
        XCTAssertEqual(usdBalance?.netBalance, Decimal(1500))
        
        let eurBalance = viewModel.otherCurrencyBalances.first(where: { $0.currencyCode == "EUR" })
        XCTAssertNotNil(eurBalance)
        XCTAssertEqual(eurBalance?.netBalance, Decimal(300))
    }
}
