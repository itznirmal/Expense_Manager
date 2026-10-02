import SwiftUI

/// Spending first; detailed reports and automation remain available on demand.
public struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(DependencyContainer.self) private var container
    @State private var viewModel = DashboardViewModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let error = viewModel.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(ColorTokens.criticalAccent)
                        Button("Try again") { Task { await refresh() } }
                    }
                    CardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recorded spending this month").font(.headline)
                            Text(money(viewModel.monthlyExpense))
                                .font(Typography.amountHero)
                                .accessibilityIdentifier("monthlySpending")
                            Text("Expenses minus refunds · " + appState.preferredCurrencyCode)
                                .font(.subheadline).foregroundStyle(.secondary)
                            Button {
                                appState.presentSheet(.manualEntry(candidate: nil))
                            } label: {
                                Label("Add expense", systemImage: "plus")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("addExpense")
                            Button("Use smart text") { appState.presentSheet(.smartTextEntry) }
                                .frame(minHeight: 44)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if appState.pendingReviewCount > 0 {
                        Button { appState.presentSheet(.importReviewQueue) } label: {
                            Label("\(appState.pendingReviewCount) entries need review", systemImage: "tray.full")
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                    }

                    if viewModel.overallBudgetLimit > 0 {
                        CardContainer {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Monthly limit").font(.headline)
                                Text("\(money(viewModel.remainingBudget)) remaining")
                                ProgressView(value: viewModel.budgetProgressPercent)
                                    .accessibilityLabel("Monthly spending limit")
                                Button("See plan") { appState.selectedTab = .budgets }
                                    .frame(minHeight: 44)
                            }
                        }
                    }

                    if !viewModel.topCategories.isEmpty {
                        Text("Where it went").font(.title2.bold())
                        ForEach(viewModel.topCategories) { category in
                            HStack {
                                Image(systemName: category.icon).accessibilityHidden(true)
                                Text(category.category)
                                Spacer()
                                Text(money(category.amount)).monospacedDigit()
                            }
                            .padding(.vertical, 8)
                        }
                        Button("Explore spending") { appState.presentSheet(.analytics) }
                            .frame(minHeight: 44)
                    }

                    HStack {
                        Text("Recent entries").font(.title2.bold())
                        Spacer()
                        Button("See all") { appState.selectedTab = .transactions }
                            .frame(minHeight: 44)
                    }
                    if viewModel.recentTransactions.isEmpty {
                        Text("Your first expense will appear here. Budgets and accounts can wait.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.recentTransactions) { transaction in
                            Button { appState.presentSheet(.transactionDetail(transaction: transaction)) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: transaction.type.iconName).accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(transaction.merchantName).foregroundStyle(.primary)
                                        Text(transaction.transactionDate, style: .date)
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(CurrencyFormatter.shared.format(amount: transaction.amount, currencyCode: transaction.currencyCode))
                                        .monospacedDigit().foregroundStyle(.primary)
                                }
                                .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .background(ColorTokens.backgroundPrimary)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(viewModel.availableCurrencyCodes, id: \.self) { code in
                            Button(code) { appState.preferredCurrencyCode = code }
                        }
                    } label: { Text(appState.preferredCurrencyCode) }
                    .accessibilityLabel("Currency shown in spending summary")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { appState.presentSheet(.settings) } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .task(id: appState.dataRevision) { await refresh() }
            .refreshable { await refresh() }
        }
    }

    private func refresh() async {
        await appState.refreshPendingReview(container: container)
        await viewModel.loadDashboardData(container: container, appState: appState)
    }

    private func money(_ amount: Decimal) -> String {
        CurrencyFormatter.shared.format(amount: amount, currencyCode: appState.preferredCurrencyCode)
    }
}

#Preview {
    DashboardView().environment(AppState()).environment(DependencyContainer.mock())
}
