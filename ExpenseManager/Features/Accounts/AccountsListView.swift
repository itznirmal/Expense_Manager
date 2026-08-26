//
//  AccountsListView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Accounts Ledger & Balance Management Screen.
//

import SwiftUI

public struct AccountsListView: View {
    @Environment(\.appState) private var appState
    @Environment(\.dependencyContainer) private var container
    
    @State private var viewModel = AccountsListViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Net Worth & Assets/Liabilities Hero Card
                    heroSummaryCard
                    
                    // Bank Accounts Section
                    if !viewModel.bankAccounts.isEmpty {
                        accountSection(title: "Bank & Savings Accounts", icon: "building.columns.fill", accounts: viewModel.bankAccounts)
                    }
                    
                    // Credit Cards Section
                    if !viewModel.creditCardAccounts.isEmpty {
                        accountSection(title: "Credit Cards", icon: "creditcard.fill", accounts: viewModel.creditCardAccounts)
                    }
                    
                    // Wallets & Cash Section
                    if !viewModel.walletAndCashAccounts.isEmpty {
                        accountSection(title: "Cash & Wallets", icon: "banknote.fill", accounts: viewModel.walletAndCashAccounts)
                    }
                    
                    // Archived Section
                    if viewModel.showArchived && !viewModel.archivedAccounts.isEmpty {
                        accountSection(title: "Archived Accounts", icon: "archivebox.fill", accounts: viewModel.archivedAccounts)
                    }
                }
                .padding()
            }
            .background(ColorTokens.backgroundPrimary)
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        viewModel.showArchived.toggle()
                    }) {
                        Image(systemName: viewModel.showArchived ? "archivebox.fill" : "archivebox")
                            .font(.system(size: 18))
                            .foregroundStyle(viewModel.showArchived ? ColorTokens.brandPrimary : ColorTokens.textSecondary)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        viewModel.selectedAccountForEdit = nil
                        viewModel.isComposerPresented = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(ColorTokens.brandPrimary)
                    }
                }
            }
            .sheet(isPresented: $viewModel.isComposerPresented) {
                AccountComposerView(account: viewModel.selectedAccountForEdit)
            }
            .onChange(of: viewModel.isComposerPresented) { oldValue, newValue in
                if !newValue {
                    Task {
                        await viewModel.loadAccounts(container: container)
                    }
                }
            }
            .task {
                await viewModel.loadAccounts(container: container)
            }
            .refreshable {
                await viewModel.loadAccounts(container: container)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var heroSummaryCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                Text("Total Net Worth")
                    .font(Typography.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
                
                Text(CurrencyFormatter.shared.format(amount: viewModel.netWorth))
                    .font(Typography.amountHero)
                    .foregroundStyle(ColorTokens.textPrimary)
                
                Divider()
                    .overlay(ColorTokens.separator)
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Assets")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                        Text(CurrencyFormatter.shared.format(amount: viewModel.totalAssets))
                            .font(Typography.subheadline.weight(.semibold))
                            .foregroundStyle(ColorTokens.incomeAccent)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Total Liabilities")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                        Text(CurrencyFormatter.shared.format(amount: viewModel.totalLiabilities))
                            .font(Typography.subheadline.weight(.semibold))
                            .foregroundStyle(viewModel.totalLiabilities > .zero ? ColorTokens.criticalAccent : ColorTokens.textPrimary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func accountSection(title: String, icon: String, accounts: [AccountDTO]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.brandPrimary)
                Text(title)
                    .font(Typography.headline)
                    .foregroundStyle(ColorTokens.textPrimary)
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 10) {
                ForEach(accounts) { account in
                    accountCard(account)
                }
            }
        }
    }
    
    private func accountCard(_ account: AccountDTO) -> some View {
        Button(action: {
            viewModel.selectedAccountForEdit = account
            viewModel.isComposerPresented = true
        }) {
            CardContainer(padding: 14) {
                HStack(spacing: 14) {
                    Image(systemName: account.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.white)
                        .frame(width: 44, height: 44)
                        .background(ColorTokens.color(for: account.colorToken))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(account.name)
                                .font(Typography.headline)
                                .foregroundStyle(ColorTokens.textPrimary)
                            
                            if account.isArchived {
                                Text("Archived")
                                    .font(Typography.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(ColorTokens.backgroundTertiary)
                                    .clipShape(Capsule())
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                        }
                        
                        HStack(spacing: 6) {
                            Text(account.type.displayName)
                            if let last4 = account.lastFour, !last4.isEmpty {
                                Text("•••• \(last4)")
                            }
                        }
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(CurrencyFormatter.shared.format(amount: account.balance, currencyCode: account.currencyCode))
                            .font(Typography.headline)
                            .foregroundStyle(account.type == .creditCard && account.balance < 0 ? ColorTokens.criticalAccent : ColorTokens.textPrimary)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ColorTokens.textQuaternary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: {
                viewModel.selectedAccountForEdit = account
                viewModel.isComposerPresented = true
            }) {
                Label("Edit Account", systemImage: "pencil")
            }
            
            Button(action: {
                Task {
                    await viewModel.toggleArchive(account: account, container: container)
                }
            }) {
                Label(account.isArchived ? "Unarchive" : "Archive", systemImage: account.isArchived ? "tray.and.arrow.up" : "archivebox")
            }
        }
    }
}

#Preview {
    AccountsListView()
        .environment(AppState())
        .environment(\.dependencyContainer, .mock())
}
