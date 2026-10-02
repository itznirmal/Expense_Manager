import XCTest
import SwiftData
@testable import ExpenseManager

final class BudgetSchemaMigrationTests: XCTestCase {
    private struct LegacyFixtureSnapshot {
        let categoryID: String
        let accountID: String
        let transactionID: String
        let budgetID: String
        let budgetMonth: Date
        let budgetCreatedAt: Date
        let budgetUpdatedAt: Date
        let transactionDate: Date
        let transactionAmount: Decimal
    }

    @MainActor
    func testV1BudgetFixtureMigratesToV2WithINRCurrencyAndPreservedFields() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("expense-manager-v1-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let snapshot = try seedLegacyStore(at: storeURL)

        let currentConfiguration = ModelConfiguration(
            schema: ExpenseManagerSchemaV2.schema,
            url: storeURL
        )
        let migratedContainer = try ModelContainer(
            for: ExpenseManagerSchemaV2.schema,
            migrationPlan: ExpenseManagerMigrationPlan.self,
            configurations: currentConfiguration
        )
        let context = migratedContainer.mainContext
        let migratedBudgets = try context.fetch(FetchDescriptor<BudgetRecord>())
        let migratedCategories = try context.fetch(FetchDescriptor<CategoryRecord>())
        let migratedAccounts = try context.fetch(FetchDescriptor<AccountRecord>())
        let migratedTransactions = try context.fetch(FetchDescriptor<TransactionRecord>())

        XCTAssertEqual(migratedBudgets.count, 1)
        XCTAssertEqual(migratedBudgets.first?.id, snapshot.budgetID)
        XCTAssertEqual(migratedBudgets.first?.categoryID, snapshot.categoryID)
        XCTAssertEqual(migratedBudgets.first?.limitAmount, Decimal(string: "1234.56"))
        XCTAssertEqual(migratedBudgets.first?.month, snapshot.budgetMonth)
        XCTAssertEqual(migratedBudgets.first?.createdAt, snapshot.budgetCreatedAt)
        XCTAssertEqual(migratedBudgets.first?.updatedAt, snapshot.budgetUpdatedAt)
        XCTAssertEqual(migratedBudgets.first?.alertThresholdPercent, 75)
        XCTAssertEqual(migratedBudgets.first?.currencyCode, "INR")

        XCTAssertEqual(migratedCategories.count, 1)
        XCTAssertEqual(migratedCategories.first?.id, snapshot.categoryID)
        XCTAssertEqual(migratedCategories.first?.name, "Food")

        XCTAssertEqual(migratedAccounts.count, 1)
        XCTAssertEqual(migratedAccounts.first?.id, snapshot.accountID)
        XCTAssertEqual(migratedAccounts.first?.currencyCode, "INR")
        XCTAssertEqual(migratedAccounts.first?.currentBalance, Decimal(4900))

        XCTAssertEqual(migratedTransactions.count, 1)
        XCTAssertEqual(migratedTransactions.first?.id, snapshot.transactionID)
        XCTAssertEqual(migratedTransactions.first?.transactionDate, snapshot.transactionDate)
        XCTAssertEqual(migratedTransactions.first?.amount, snapshot.transactionAmount)
        XCTAssertEqual(migratedTransactions.first?.category?.id, snapshot.categoryID)
        XCTAssertEqual(migratedTransactions.first?.account?.id, snapshot.accountID)
    }

    @MainActor
    private func seedLegacyStore(at storeURL: URL) throws -> LegacyFixtureSnapshot {
        let categoryID = "legacy-food"
        let accountID = "legacy-account"
        let transactionID = "legacy-transaction"
        let budgetID = "legacy-budget"
        let budgetMonth = Date(timeIntervalSince1970: 1_756_000_000)
        let budgetCreatedAt = Date(timeIntervalSince1970: 1_755_000_000)
        let budgetUpdatedAt = Date(timeIntervalSince1970: 1_756_000_000)
        let transactionDate = Date(timeIntervalSince1970: 1_756_100_000)
        let transactionAmount = Decimal(string: "100.10")!

        do {
            let legacyConfiguration = ModelConfiguration(
                schema: ExpenseManagerSchemaV1.schema,
                url: storeURL
            )
            let legacyContainer = try ModelContainer(
                for: ExpenseManagerSchemaV1.schema,
                configurations: legacyConfiguration
            )
            let legacyContext = ModelContext(legacyContainer)
            let legacyCategory = ExpenseManagerSchemaV1.CategoryRecord(
                id: categoryID,
                name: "Food",
                type: CategoryType.expense.rawValue
            )
            let legacyAccount = ExpenseManagerSchemaV1.AccountRecord(
                id: accountID,
                name: "Wallet",
                type: AccountType.cash.rawValue,
                currencyCode: "INR",
                openingBalance: Decimal(5000),
                currentBalance: Decimal(4900),
                icon: "banknote.fill",
                colorToken: "green"
            )
            let legacyTransaction = ExpenseManagerSchemaV1.TransactionRecord(
                id: transactionID,
                type: TransactionType.expense.rawValue,
                amount: transactionAmount,
                currencyCode: "INR",
                merchantName: "Cafe",
                category: legacyCategory,
                account: legacyAccount,
                transactionDate: transactionDate,
                source: InputSource.manual.rawValue
            )
            let legacyBudget = ExpenseManagerSchemaV1.BudgetRecord(
                id: budgetID,
                categoryID: categoryID,
                limitAmount: Decimal(string: "1234.56")!,
                month: budgetMonth,
                alertThresholdPercent: 75,
                createdAt: budgetCreatedAt,
                updatedAt: budgetUpdatedAt
            )
            legacyContext.insert(legacyCategory)
            legacyContext.insert(legacyAccount)
            legacyContext.insert(legacyTransaction)
            legacyContext.insert(legacyBudget)
            try legacyContext.save()
        }

        return LegacyFixtureSnapshot(
            categoryID: categoryID,
            accountID: accountID,
            transactionID: transactionID,
            budgetID: budgetID,
            budgetMonth: budgetMonth,
            budgetCreatedAt: budgetCreatedAt,
            budgetUpdatedAt: budgetUpdatedAt,
            transactionDate: transactionDate,
            transactionAmount: transactionAmount
        )
    }
}
