//
//  DependencyContainer.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Dependency Injection Container & Service Registry.
//

import SwiftUI
import SwiftData

/// Central Dependency Injection container for Expense Manager.
/// Provides access to domain services with support for live SwiftData backends and in-memory test/preview backends.
@MainActor
public final class DependencyContainer {
    
    // MARK: - Registered Services
    
    public let transactionService: TransactionServiceProtocol
    public let accountService: AccountServiceProtocol
    public let categoryService: CategoryServiceProtocol
    public let parserService: ParserServiceProtocol
    public let budgetService: BudgetServiceProtocol
    public let merchantIntelligenceService: MerchantIntelligenceServiceProtocol
    public let merchantRuleService: MerchantRuleServiceProtocol?
    public let fingerprintService: ImportFingerprintServiceProtocol?
    public let dataExportService: DataExportServiceProtocol
    
    // MARK: - Initializer
    
    public init(
        transactionService: TransactionServiceProtocol,
        accountService: AccountServiceProtocol,
        categoryService: CategoryServiceProtocol,
        parserService: ParserServiceProtocol,
        budgetService: BudgetServiceProtocol,
        merchantIntelligenceService: MerchantIntelligenceServiceProtocol = MerchantIntelligenceService.shared,
        merchantRuleService: MerchantRuleServiceProtocol? = nil,
        fingerprintService: ImportFingerprintServiceProtocol? = nil,
        dataExportService: DataExportServiceProtocol? = nil
    ) {
        self.transactionService = transactionService
        self.accountService = accountService
        self.categoryService = categoryService
        self.parserService = parserService
        self.budgetService = budgetService
        self.merchantIntelligenceService = merchantIntelligenceService
        self.merchantRuleService = merchantRuleService
        self.fingerprintService = fingerprintService
        self.dataExportService = dataExportService ?? MockDataExportService()
    }
    
    // MARK: - Factory Constructors
    
    /// Creates a production live container wired to the given SwiftData ModelContainer.
    public static func live(modelContainer: ModelContainer) -> DependencyContainer {
        let ruleService = MerchantRuleService(modelContainer: modelContainer)
        let parserOrchestrator = ParserOrchestrator(merchantRuleService: ruleService)
        let exportService = DataExportService(modelContainer: modelContainer)
        
        return DependencyContainer(
            transactionService: SwiftDataTransactionService(modelContainer: modelContainer),
            accountService: SwiftDataAccountService(modelContainer: modelContainer),
            categoryService: SwiftDataCategoryService(modelContainer: modelContainer),
            parserService: parserOrchestrator,
            budgetService: SwiftDataBudgetService(modelContainer: modelContainer),
            merchantIntelligenceService: MerchantIntelligenceService.shared,
            merchantRuleService: ruleService,
            fingerprintService: ImportFingerprintService(modelContainer: modelContainer),
            dataExportService: exportService
        )
    }
    
    /// Creates a mock / in-memory container populated with realistic sample data for Previews and Unit Tests.
    public static func mock() -> DependencyContainer {
        let parserOrchestrator = ParserOrchestrator()
        
        return DependencyContainer(
            transactionService: MockTransactionService(),
            accountService: MockAccountService(),
            categoryService: MockCategoryService(),
            parserService: parserOrchestrator,
            budgetService: MockBudgetService(),
            merchantIntelligenceService: MerchantIntelligenceService.shared,
            dataExportService: MockDataExportService()
        )
    }
    
    /// Creates an empty in-memory container for isolated test cases.
    public static func inMemoryEmpty() -> DependencyContainer {
        let parserOrchestrator = ParserOrchestrator()
        
        return DependencyContainer(
            transactionService: MockTransactionService(sampleData: []),
            accountService: MockAccountService(sampleData: []),
            categoryService: MockCategoryService(sampleData: []),
            parserService: parserOrchestrator,
            budgetService: MockBudgetService(sampleData: []),
            merchantIntelligenceService: MerchantIntelligenceService.shared,
            dataExportService: MockDataExportService()
        )
    }
}

// MARK: - SwiftUI Environment Key

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer = .mock()
}

public extension EnvironmentValues {
    var dependencyContainer: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}
