//
//  DashboardView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Glanceable Financial Dashboard Screen with Apple HIG Hero Cards, Pace Engine & Quick Actions.
//

import SwiftUI

public struct DashboardView: View {
    @Environment(\.appState) private var appState
    @Environment(\.dependencyContainer) private var container
    
    @State private var viewModel = DashboardViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Pending Review Queue Banner
                    if appState.pendingReviewCount > 0 {
                        reviewQueueBanner
                    }
                    
                    // Anomalous Transaction Alert (if any)
                    if let firstAnomaly = viewModel.anomalousAlerts.first {
                        anomalyAlertBanner(firstAnomaly)
                    }
                    
                    // Hero Net Worth Card
                    heroNetWorthCard
                    
                    // Monthly Cash Flow Card
                    monthlyCashFlowCard
                    
                    // Quick Action Grid
                    quickActionGrid
                    
                    // Spending Pace vs Budget Overview
                    if viewModel.overallBudgetLimit > .zero {
                        budgetPaceCard
                    }
                    
                    // Top Spending Categories Carousel
                    if !viewModel.topCategories.isEmpty {
                        categorySpendingCarousel
                    }
                    
                    // Recurring Subscriptions Preview
                    if !viewModel.recurringSubscriptions.isEmpty {
                        recurringSubscriptionsSection
                    }
                    
                    // Recent Transactions Section Header
                    recentTransactionsHeader
                    
                    // Recent Transactions List / Empty State
                    if viewModel.recentTransactions.isEmpty {
                        emptyTransactionsCard
                    } else {
                        VStack(spacing: 10) {
                            ForEach(viewModel.recentTransactions) { item in
                                transactionRow(item)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(ColorTokens.backgroundPrimary)
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        appState.presentSheet(.smartTextEntry)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(ColorTokens.brandPrimary)
                    }
                }
            }
            .sheet(item: $viewModel.selectedDetailTransaction) { tx in
                TransactionDetailView(
                    transaction: tx,
                    onEdit: { candidate in
                        viewModel.selectedEditTransaction = candidate
                    },
                    onDelete: { id in
                        viewModel.recentTransactions.removeAll { $0.id.uuidString == id }
                    }
                )
            }
            .sheet(item: $viewModel.selectedEditTransaction) { candidate in
                ManualTransactionComposerView(candidate: candidate)
            }
            .task {
                await viewModel.loadDashboardData(container: container, appState: appState)
            }
            .refreshable {
                await viewModel.loadDashboardData(container: container, appState: appState)
            }
        }
    }
    
    // MARK: - 1. Hero Net Worth Card
    
    private var heroNetWorthCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Total Net Worth")
                        .font(Typography.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary)
                    
                    Spacer()
                    
                    Button(action: {
                        appState.presentSheet(.accountsList)
                    }) {
                        HStack(spacing: 4) {
                            Text("Manage")
                            Image(systemName: "chevron.right")
                        }
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(ColorTokens.brandPrimary)
                    }
                }
                
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(CurrencyFormatter.shared.format(amount: viewModel.netWorth))
                        .font(Typography.amountHero)
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    if !viewModel.otherCurrencyBalances.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(viewModel.otherCurrencyBalances) { other in
                                Text("+ \(CurrencyFormatter.shared.format(amount: other.netBalance, currencyCode: other.currencyCode))")
                                    .font(Typography.caption2.weight(.semibold))
                                    .foregroundStyle(ColorTokens.brandPrimary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(ColorTokens.brandPrimary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Total Net Worth: \(CurrencyFormatter.shared.format(amount: viewModel.netWorth))\(viewModel.otherCurrencyBalances.map { ", and \(CurrencyFormatter.shared.format(amount: $0.netBalance, currencyCode: $0.currencyCode))" }.joined())")
                
                Divider().overlay(ColorTokens.separator)
                
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(ColorTokens.incomeAccent)
                            .frame(width: 8, height: 8)
                        Text("Assets: \(CurrencyFormatter.shared.formatCompact(amount: viewModel.totalAssets))")
                            .font(Typography.caption.weight(.medium))
                            .foregroundStyle(ColorTokens.textPrimary)
                    }
                    .accessibilityLabel("Total Assets: \(CurrencyFormatter.shared.format(amount: viewModel.totalAssets))")
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.totalLiabilities > .zero ? ColorTokens.criticalAccent : ColorTokens.textTertiary)
                            .frame(width: 8, height: 8)
                        Text("Liabilities: \(CurrencyFormatter.shared.formatCompact(amount: viewModel.totalLiabilities))")
                            .font(Typography.caption.weight(.medium))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .accessibilityLabel("Total Liabilities: \(CurrencyFormatter.shared.format(amount: viewModel.totalLiabilities))")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - 2. Monthly Cash Flow Card
    
    private var monthlyCashFlowCard: some View {
        CardContainer {
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.left")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(ColorTokens.incomeAccent)
                            Text("Income")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                        Text(CurrencyFormatter.shared.format(amount: viewModel.monthlyIncome, fractionDigits: 0))
                            .font(Typography.headline)
                            .foregroundStyle(ColorTokens.incomeAccent)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Expenses")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textSecondary)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(ColorTokens.expenseAccent)
                        }
                        Text(CurrencyFormatter.shared.format(amount: viewModel.monthlyExpense, fractionDigits: 0))
                            .font(Typography.headline)
                            .foregroundStyle(ColorTokens.expenseAccent)
                    }
                }
                
                Divider().overlay(ColorTokens.separator)
                
                HStack {
                    Text("Net Savings This Month")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                    Spacer()
                    HStack(spacing: 8) {
                        Text(CurrencyFormatter.shared.format(amount: viewModel.netSavings, fractionDigits: 0))
                            .font(Typography.subheadline.weight(.bold))
                            .foregroundStyle(viewModel.netSavings >= 0 ? ColorTokens.incomeAccent : ColorTokens.expenseAccent)
                        
                        Text("\(String(format: "%.0f", viewModel.savingsRate))%")
                            .font(Typography.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(viewModel.netSavings >= 0 ? ColorTokens.incomeAccent.opacity(0.15) : ColorTokens.criticalAccent.opacity(0.15))
                            .foregroundStyle(viewModel.netSavings >= 0 ? ColorTokens.incomeAccent : ColorTokens.criticalAccent)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
    
    // MARK: - 3. Quick Action Grid
    
    private var quickActionGrid: some View {
        HStack(spacing: 8) {
            quickActionButton(
                title: "Smart Add",
                icon: "sparkles",
                color: ColorTokens.brandPrimary
            ) {
                appState.presentSheet(.smartTextEntry)
            }
            
            quickActionButton(
                title: "Voice",
                icon: "mic.fill",
                color: ColorTokens.criticalAccent
            ) {
                appState.presentSheet(.voiceEntry)
            }
            
            quickActionButton(
                title: "Manual",
                icon: "square.and.pencil",
                color: ColorTokens.incomeAccent
            ) {
                appState.presentSheet(.manualEntry())
            }
            
            quickActionButton(
                title: "Sandbox",
                icon: "stethoscope",
                color: ColorTokens.transferAccent
            ) {
                appState.presentSheet(.smsDiagnostics)
            }
            
            quickActionButton(
                title: "Review",
                icon: "tray.full.fill",
                color: ColorTokens.warningAccent
            ) {
                appState.presentSheet(.importReviewQueue)
            }
        }
    }
    
    private func quickActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.12))
                    .clipShape(Circle())
                
                Text(title)
                    .font(Typography.caption2.weight(.medium))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(ColorTokens.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(ColorTokens.borderSubtle, lineWidth: 1)
            )
        }
    }
    
    // MARK: - 4. Budget Pace Card
    
    private var budgetPaceCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Budget Spending Pace")
                        .font(Typography.subheadline.weight(.semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer()
                    Text("\(Int(viewModel.budgetProgressPercent * 100))% Spent")
                        .font(Typography.caption.weight(.bold))
                        .foregroundStyle(viewModel.budgetProgressPercent > viewModel.monthPacePercent ? ColorTokens.warningAccent : ColorTokens.incomeAccent)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(ColorTokens.backgroundTertiary)
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(viewModel.budgetProgressPercent > 0.9 ? ColorTokens.criticalAccent : (viewModel.budgetProgressPercent > 0.7 ? ColorTokens.warningAccent : ColorTokens.incomeAccent))
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(viewModel.budgetProgressPercent))), height: 8)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Text("Spent: \(CurrencyFormatter.shared.format(amount: viewModel.overallBudgetSpent, fractionDigits: 0))")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                    Spacer()
                    Text("Cap: \(CurrencyFormatter.shared.format(amount: viewModel.overallBudgetLimit, fractionDigits: 0))")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
    }
    
    // MARK: - 5. Top Categories Carousel
    
    private var categorySpendingCarousel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top Spending Categories")
                .font(Typography.headline)
                .foregroundStyle(ColorTokens.textPrimary)
                .padding(.horizontal, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.topCategories) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: item.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(ColorTokens.color(for: item.colorToken))
                                    .frame(width: 32, height: 32)
                                    .background(ColorTokens.color(for: item.colorToken).opacity(0.15))
                                    .clipShape(Circle())
                                
                                Spacer()
                                
                                Text("\(Int(item.percentage * 100))%")
                                    .font(Typography.caption.weight(.bold))
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                            
                            Text(item.category)
                                .font(Typography.caption.weight(.semibold))
                                .foregroundStyle(ColorTokens.textPrimary)
                                .lineLimit(1)
                            
                            Text(CurrencyFormatter.shared.format(amount: item.amount, fractionDigits: 0))
                                .font(Typography.subheadline.weight(.bold))
                                .foregroundStyle(ColorTokens.textPrimary)
                        }
                        .frame(width: 130)
                        .padding(12)
                        .background(ColorTokens.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(ColorTokens.borderSubtle, lineWidth: 1)
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    // MARK: - 6. Recurring Subscriptions Section
    
    private var recurringSubscriptionsSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Recurring Subscriptions", systemImage: "repeat")
                        .font(Typography.subheadline.weight(.semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer()
                    Text("\(viewModel.recurringSubscriptions.count) Active")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                
                VStack(spacing: 8) {
                    ForEach(viewModel.recurringSubscriptions.prefix(3)) { sub in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sub.merchantName)
                                    .font(Typography.subheadline.weight(.medium))
                                    .foregroundStyle(ColorTokens.textPrimary)
                                Text("Next due: \(DateFormatterHelper.shared.shortDate(for: sub.nextExpectedDate)) • \(sub.frequency.rawValue)")
                                    .font(Typography.caption2)
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                            Spacer()
                            Text(CurrencyFormatter.shared.format(amount: sub.amount, currencyCode: sub.currencyCode))
                                .font(Typography.subheadline.weight(.semibold))
                                .foregroundStyle(ColorTokens.textPrimary)
                        }
                        
                        if sub.id != viewModel.recurringSubscriptions.prefix(3).last?.id {
                            Divider().overlay(ColorTokens.separator)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 7. Recent Transactions Header & Rows
    
    private var recentTransactionsHeader: some View {
        HStack {
            Text("Recent Transactions")
                .font(Typography.title3)
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer()
            Button("See All") {
                appState.selectedTab = .transactions
            }
            .font(Typography.subheadline.weight(.semibold))
            .foregroundStyle(ColorTokens.brandPrimary)
        }
        .padding(.horizontal, 4)
    }
    
    private var emptyTransactionsCard: some View {
        CardContainer {
            EmptyStateView(
                iconName: "tray",
                title: "No Transactions Yet",
                message: "Spend normally, your tracker catches up automatically.",
                actionTitle: "Add Transaction"
            ) {
                appState.presentSheet(.smartTextEntry)
            }
        }
    }
    
    private func transactionRow(_ item: TransactionCandidate) -> some View {
        Button(action: {
            viewModel.selectedDetailTransaction = item
        }) {
            CardContainer(padding: 12) {
                HStack(spacing: 12) {
                    Image(systemName: item.type.iconName)
                        .font(.system(size: 18))
                        .foregroundStyle(ColorTokens.brandPrimary)
                        .frame(width: 38, height: 38)
                        .background(ColorTokens.brandPrimary.opacity(0.1))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.merchantName.isEmpty ? item.type.displayName : item.merchantName)
                            .font(Typography.headline)
                            .foregroundStyle(ColorTokens.textPrimary)
                        
                        HStack(spacing: 6) {
                            Text(item.categorySuggestion ?? "General")
                            Text("•")
                            Text(DateFormatterHelper.shared.relativeDateString(for: item.transactionDate))
                        }
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                    }
                    
                    Spacer()
                    
                    AmountBadgeView(
                        amount: item.amount,
                        currencyCode: item.currencyCode,
                        type: item.type == .expense ? .expense : (item.type == .income ? .income : .transfer),
                        size: .medium
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task {
                    await viewModel.deleteTransaction(id: item.id.uuidString, container: container, appState: appState)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            Button {
                viewModel.selectedEditTransaction = item
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(ColorTokens.brandPrimary)
        }
    }
    
    // MARK: - 8. Alerts & Banners
    
    private var reviewQueueBanner: some View {
        Button(action: {
            appState.presentSheet(.importReviewQueue)
        }) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(ColorTokens.warningAccent)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(appState.pendingReviewCount) Transactions Need Review")
                        .font(Typography.subheadline.weight(.semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    Text("Tap to triage and accept incoming transactions")
                        .font(Typography.caption2)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .padding(12)
            .background(ColorTokens.warningAccent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(ColorTokens.warningAccent.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private func anomalyAlertBanner(_ alert: AnomalousTransactionAlert) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.badge.clock.fill")
                .font(.system(size: 20))
                .foregroundStyle(ColorTokens.criticalAccent)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Unusual Spending Spike Detected")
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                
                Text(alert.reason)
                    .font(Typography.caption2)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(ColorTokens.criticalAccent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(ColorTokens.criticalAccent.opacity(0.25), lineWidth: 1)
        )
    }
}

#Preview {
    DashboardView()
        .environment(AppState())
        .environment(\.dependencyContainer, .mock())
}
