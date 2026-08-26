//
//  BudgetsOverviewView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Budgets & Spending Limits Feature View with Projections and Pace Analysis.
//

import SwiftUI

public struct BudgetsOverviewView: View {
    @Environment(\.appState) private var appState
    @Environment(\.dependencyContainer) private var container
    
    @State private var viewModel = BudgetsViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Month Navigation Bar
                    monthNavigationBar
                    
                    // Daily Allowance Banner
                    if viewModel.dailyAllowance > .zero && viewModel.remainingDaysInMonth > 0 {
                        dailyAllowanceBanner
                    }
                    
                    // At-Risk Warnings
                    if !viewModel.atRiskBudgets.isEmpty {
                        atRiskWarningBanner
                    }
                    
                    // Overall Monthly Budget Hero Card
                    overallBudgetHeroCard
                    
                    // Category Budgets Header
                    HStack {
                        Text("Category Budgets")
                            .font(Typography.title3)
                            .foregroundStyle(ColorTokens.textPrimary)
                        Spacer()
                        Button(action: {
                            viewModel.selectedBudgetForEdit = nil
                            viewModel.isComposerPresented = true
                        }) {
                            Label("Add Budget", systemImage: "plus")
                                .font(Typography.footnote.weight(.semibold))
                                .foregroundStyle(ColorTokens.brandPrimary)
                        }
                    }
                    .padding(.horizontal, 4)
                    
                    // Category Budgets List
                    if viewModel.categoryBudgets.isEmpty {
                        CardContainer {
                            EmptyStateView(
                                iconName: "chart.pie",
                                title: "No Category Budgets Set",
                                message: "Set spending limits for individual categories to keep everyday expenses under control.",
                                actionTitle: "Set Category Budget"
                            ) {
                                viewModel.selectedBudgetForEdit = nil
                                viewModel.isComposerPresented = true
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            ForEach(viewModel.categoryBudgets) { budget in
                                categoryBudgetCard(budget)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(ColorTokens.backgroundPrimary)
            .navigationTitle("Budgets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        viewModel.selectedBudgetForEdit = nil
                        viewModel.isComposerPresented = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(ColorTokens.brandPrimary)
                    }
                }
            }
            .sheet(isPresented: $viewModel.isComposerPresented) {
                BudgetComposerView(budget: viewModel.selectedBudgetForEdit, targetMonth: viewModel.selectedMonth)
            }
            .onChange(of: viewModel.isComposerPresented) { oldValue, newValue in
                if !newValue {
                    Task {
                        await viewModel.loadBudgets(container: container)
                    }
                }
            }
            .task {
                await viewModel.loadBudgets(container: container)
            }
            .refreshable {
                await viewModel.loadBudgets(container: container)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var monthNavigationBar: some View {
        HStack {
            Button(action: {
                Task {
                    await viewModel.selectPreviousMonth(container: container)
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ColorTokens.brandPrimary)
                    .frame(width: 36, height: 36)
                    .background(ColorTokens.backgroundTertiary)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.brandPrimary)
                Text(DateFormatterHelper.shared.monthYear(for: viewModel.selectedMonth))
                    .font(Typography.headline)
                    .foregroundStyle(ColorTokens.textPrimary)
            }
            
            Spacer()
            
            Button(action: {
                Task {
                    await viewModel.selectNextMonth(container: container)
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ColorTokens.brandPrimary)
                    .frame(width: 36, height: 36)
                    .background(ColorTokens.backgroundTertiary)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var dailyAllowanceBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 20))
                .foregroundStyle(ColorTokens.brandPrimary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily Allowance: \(CurrencyFormatter.shared.format(amount: viewModel.dailyAllowance, fractionDigits: 0))/day")
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                
                Text("You have \(viewModel.remainingDaysInMonth) days remaining in \(DateFormatterHelper.shared.monthYear(for: viewModel.selectedMonth)).")
                    .font(Typography.caption2)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(ColorTokens.brandPrimary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(ColorTokens.brandPrimary.opacity(0.25), lineWidth: 1)
        )
    }
    
    private var atRiskWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundStyle(ColorTokens.warningAccent)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.atRiskBudgets.count) Categories At Risk of Overspending")
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                
                let names = viewModel.atRiskBudgets.compactMap(\.categoryName).prefix(2).joined(separator: ", ")
                Text("Higher burn rate than expected month pace (\(names))")
                    .font(Typography.caption2)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(ColorTokens.warningAccent.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(ColorTokens.warningAccent.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var overallBudgetHeroCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Overall Monthly Spend")
                            .font(Typography.subheadline)
                            .foregroundStyle(ColorTokens.textSecondary)
                        
                        Text(CurrencyFormatter.shared.format(amount: viewModel.totalSpent))
                            .font(Typography.amountHero)
                            .foregroundStyle(ColorTokens.textPrimary)
                    }
                    
                    Spacer()
                    
                    // Progress percentage badge
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(viewModel.overallProgressPercent * 100))%")
                            .font(Typography.title2.weight(.bold))
                            .foregroundStyle(overallProgressColor)
                        
                        Text("of \(CurrencyFormatter.shared.formatCompact(amount: viewModel.totalLimit))")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(ColorTokens.backgroundTertiary)
                            .frame(height: 12)
                        
                        Capsule()
                            .fill(overallProgressColor)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(viewModel.overallProgressPercent))), height: 12)
                    }
                }
                .frame(height: 12)
                
                Divider()
                    .overlay(ColorTokens.separator)
                
                // Projections & Month Pace Footer
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Projected EOM Spend")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                        Text(CurrencyFormatter.shared.format(amount: viewModel.projectedMonthSpend, fractionDigits: 0))
                            .font(Typography.subheadline.weight(.semibold))
                            .foregroundStyle(viewModel.projectedMonthSpend > viewModel.totalLimit && viewModel.totalLimit > 0 ? ColorTokens.criticalAccent : ColorTokens.textPrimary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Month Elapsed")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                        Text("\(Int(viewModel.monthPacePercent * 100))% Pace")
                            .font(Typography.subheadline.weight(.semibold))
                            .foregroundStyle(ColorTokens.textPrimary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func categoryBudgetCard(_ budget: BudgetDTO) -> some View {
        Button(action: {
            viewModel.selectedBudgetForEdit = budget
            viewModel.isComposerPresented = true
        }) {
            CardContainer(padding: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(budget.categoryName ?? "Category Budget")
                            .font(Typography.headline)
                            .foregroundStyle(ColorTokens.textPrimary)
                        
                        Spacer()
                        
                        Text("\(Int(budget.progressPercent * 100))%")
                            .font(Typography.subheadline.weight(.bold))
                            .foregroundStyle(progressColor(for: budget))
                    }
                    
                    // Progress Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(ColorTokens.backgroundTertiary)
                                .frame(height: 8)
                            
                            Capsule()
                                .fill(progressColor(for: budget))
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(budget.progressPercent))), height: 8)
                        }
                    }
                    .frame(height: 8)
                    
                    HStack {
                        Text("Spent: \(CurrencyFormatter.shared.format(amount: budget.spentAmount, fractionDigits: 0))")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                        
                        Spacer()
                        
                        Text("Limit: \(CurrencyFormatter.shared.format(amount: budget.limitAmount, fractionDigits: 0))")
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(ColorTokens.textPrimary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private var overallProgressColor: Color {
        if viewModel.totalLimit > 0 && viewModel.totalSpent > viewModel.totalLimit {
            return ColorTokens.criticalAccent
        } else if viewModel.overallProgressPercent >= 0.80 {
            return ColorTokens.warningAccent
        } else {
            return ColorTokens.incomeAccent
        }
    }
    
    private func progressColor(for budget: BudgetDTO) -> Color {
        if budget.isExceeded {
            return ColorTokens.criticalAccent
        } else if budget.progressPercent >= Double(budget.alertThresholdPercent) / 100.0 {
            return ColorTokens.warningAccent
        } else {
            return ColorTokens.incomeAccent
        }
    }
}

#Preview {
    BudgetsOverviewView()
        .environment(AppState())
        .environment(\.dependencyContainer, .mock())
}
