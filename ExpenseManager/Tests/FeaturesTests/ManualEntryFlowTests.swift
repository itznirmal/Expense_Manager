import XCTest
@testable import ExpenseManager

@MainActor
final class ManualEntryFlowTests: XCTestCase {
    func testAmountOnlyCanBeSavedWithoutRequiredAccountOrMerchant() async throws {
        let container = DependencyContainer.inMemoryEmpty()
        let viewModel = ManualTransactionComposerViewModel()
        viewModel.currencyCode = "USD"
        viewModel.amountText = "12.50"
        await viewModel.loadData(container: container)
        XCTAssertTrue(viewModel.canSave)
        let saved = await viewModel.saveTransaction(container: container, appState: AppState())
        XCTAssertTrue(saved)
        let entries = try await container.transactionService.fetchRecentTransactions(limit: 10)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.amount, Decimal(string: "12.50"))
        XCTAssertEqual(entries.first?.currencyCode, "USD")
    }

    func testChangingEntryCurrencyChoosesOnlyMatchingAccounts() async throws {
        let container = DependencyContainer.inMemoryEmpty()
        _ = try await container.accountService.createAccount(name: "Dollar", type: .bank, openingBalance: 100, currencyCode: "USD", icon: "banknote", colorToken: "blue", lastFour: nil)
        _ = try await container.accountService.createAccount(name: "Rupee", type: .bank, openingBalance: 100, currencyCode: "INR", icon: "banknote", colorToken: "blue", lastFour: nil)
        let viewModel = ManualTransactionComposerViewModel()
        viewModel.currencyCode = "USD"
        await viewModel.loadData(container: container)
        viewModel.currencyCode = "INR"
        viewModel.selectCurrency()
        XCTAssertEqual(viewModel.matchingCurrencyAccounts.count, 1)
        XCTAssertEqual(viewModel.matchingCurrencyAccounts.first?.id, viewModel.selectedAccountID)
        XCTAssertNil(viewModel.selectedDestinationAccountID)
    }
}
