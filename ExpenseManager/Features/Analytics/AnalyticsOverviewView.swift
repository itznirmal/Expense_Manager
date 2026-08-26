//
//  AnalyticsOverviewView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Financial Analytics & Interactive Swift Charts Feature View.
//

import SwiftUI
import Charts

public struct AnalyticsOverviewView: View {
    @Environment(\.appState) private var appState
    @Environment(\.dependencyContainer) private var container
    
    @State private var viewModel = AnalyticsViewModel()
    @State private var selectedCategory: CategorySpendingItem? = nil
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Time Horizon Segmented Picker
                    horizonPicker
                    
                    // Summary KPI Cards Grid
                    kpiSummaryGrid
                    
                    // Monthly Cash Flow Bar Chart
                    if !viewModel.monthlyCashFlows.isEmpty {
                        monthlyCashFlowSection
                    }
                    
                    // Category Breakdown Donut Chart
                    if !viewModel.categoryBreakdowns.isEmpty {
                        categoryBreakdownSection
                    }
                    
                    // Daily Spending Trend Line Chart
                    if !viewModel.dailySpendingTrend.isEmpty {
                        dailySpendingTrendSection
                    }
                    
                    // Top 5 Merchants Table
                    if !viewModel.topMerchants.isEmpty {
                        topMerchantsSection
                    }
                }
                .padding()
            }
            .background(ColorTokens.backgroundPrimary)
            .navigationTitle("Analytics")
            .task {
                await viewModel.loadAnalytics(container: container)
            }
            .refreshable {
                await viewModel.loadAnalytics(container: container)
            }
        }
    }
    
    // MARK: - 1. Time Horizon Picker
    
    private var horizonPicker: some View {
        Picker("Time Horizon", selection: $viewModel.selectedHorizon) {
            ForEach(AnalyticsTimeHorizon.allCases) { horizon in
                Text(horizon.rawValue).tag(horizon)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.selectedHorizon) { oldValue, newValue in
            Task {
                await viewModel.setTimeHorizon(newValue, container: container)
            }
        }
    }
    
    // MARK: - 2. KPI Summary Grid
    
    private var kpiSummaryGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statTile(
                    title: "Income",
                    amount: viewModel.totalIncome,
                    color: ColorTokens.incomeAccent,
                    icon: "arrow.down.left"
                )
                
                statTile(
                    title: "Expenses",
                    amount: viewModel.totalExpense,
                    color: ColorTokens.expenseAccent,
                    icon: "arrow.up.right"
                )
            }
            
            HStack(spacing: 12) {
                CardContainer {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "banknote")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(viewModel.netSavings >= 0 ? ColorTokens.incomeAccent : ColorTokens.expenseAccent)
                            Text("Net Savings")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                        
                        Text(CurrencyFormatter.shared.format(amount: viewModel.netSavings))
                            .font(Typography.headline)
                            .foregroundStyle(viewModel.netSavings >= 0 ? ColorTokens.incomeAccent : ColorTokens.expenseAccent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Text("Rate: \(String(format: "%.1f", viewModel.savingsRate))%")
                            .font(Typography.caption2.weight(.medium))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                CardContainer {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(ColorTokens.brandPrimary)
                            Text("Daily Average")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                        
                        Text(CurrencyFormatter.shared.format(amount: viewModel.averageDailyExpense, fractionDigits: 0))
                            .font(Typography.headline)
                            .foregroundStyle(ColorTokens.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Text("\(viewModel.selectedHorizon.displayName) burn")
                            .font(Typography.caption2)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    private func statTile(title: String, amount: Decimal, color: Color, icon: String) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(color)
                    Text(title)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                
                Text(CurrencyFormatter.shared.format(amount: amount))
                    .font(Typography.headline)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - 3. Monthly Cash Flow Bar Chart
    
    private var monthlyCashFlowSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Income vs Expenses")
                        .font(Typography.headline)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer()
                    HStack(spacing: 12) {
                        chartLegendPill(title: "Income", color: ColorTokens.incomeAccent)
                        chartLegendPill(title: "Expense", color: ColorTokens.expenseAccent)
                    }
                }
                
                Chart {
                    ForEach(viewModel.monthlyCashFlows) { item in
                        BarMark(
                            x: .value("Month", item.monthLabel),
                            y: .value("Amount", item.incomeDouble)
                        )
                        .foregroundStyle(ColorTokens.incomeAccent)
                        .position(by: .value("Type", "Income"))
                        .cornerRadius(4)
                        
                        BarMark(
                            x: .value("Month", item.monthLabel),
                            y: .value("Amount", item.expenseDouble)
                        )
                        .foregroundStyle(ColorTokens.expenseAccent)
                        .position(by: .value("Type", "Expense"))
                        .cornerRadius(4)
                    }
                }
                .frame(height: 180)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Monthly Income versus Expenses bar chart for \(viewModel.selectedHorizon.displayName). Total Income: \(CurrencyFormatter.shared.format(amount: viewModel.totalIncome)), Total Expense: \(CurrencyFormatter.shared.format(amount: viewModel.totalExpense)).")
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        if let doubleValue = value.as(Double.self) {
                            AxisValueLabel {
                                Text(CurrencyFormatter.shared.formatCompact(amount: Decimal(doubleValue)))
                                    .font(Typography.caption2)
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 4. Category Breakdown Donut Chart
    
    private var categoryBreakdownSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Category Spending Breakdown")
                        .font(Typography.headline)
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    Spacer()
                    
                    if selectedCategory != nil {
                        Button("Reset") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCategory = nil
                            }
                        }
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(ColorTokens.brandPrimary)
                    }
                }
                
                HStack(alignment: .center, spacing: 20) {
                    // Donut Chart
                    Chart(viewModel.categoryBreakdowns) { item in
                        SectorMark(
                            angle: .value("Amount", item.totalAmountDouble),
                            innerRadius: .ratio(0.618),
                            angularInset: 1.5
                        )
                        .foregroundStyle(ColorTokens.color(for: item.colorToken))
                        .cornerRadius(3)
                        .opacity(selectedCategory == nil || selectedCategory?.id == item.id ? 1.0 : 0.35)
                    }
                    .frame(width: 140, height: 140)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Category spending distribution donut chart with \(viewModel.categoryBreakdowns.count) categories.")
                    
                    // Legend & Interactive Percentages List
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.categoryBreakdowns.prefix(4)) { item in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if selectedCategory?.id == item.id {
                                        selectedCategory = nil
                                    } else {
                                        selectedCategory = item
                                    }
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(ColorTokens.color(for: item.colorToken))
                                        .frame(width: 10, height: 10)
                                    
                                    Text(item.categoryName)
                                        .font(Typography.caption.weight(selectedCategory?.id == item.id ? .bold : .medium))
                                        .foregroundStyle(selectedCategory?.id == item.id ? ColorTokens.brandPrimary : ColorTokens.textPrimary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Text("\(Int(item.percentage * 100))%")
                                        .font(Typography.caption.weight(.semibold))
                                        .foregroundStyle(ColorTokens.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(item.categoryName): \(CurrencyFormatter.shared.format(amount: item.totalAmount)), \(Int(item.percentage * 100)) percent of total spending.")
                        }
                    }
                }
                .padding(.vertical, 4)
                
                // Selected category callout detail card
                if let selected = selectedCategory {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selected.categoryName)
                                .font(Typography.subheadline.weight(.semibold))
                                .foregroundStyle(ColorTokens.textPrimary)
                            Text("\(selected.transactionCount) transactions")
                                .font(Typography.caption2)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                        
                        Spacer()
                        
                        Text(CurrencyFormatter.shared.format(amount: selected.totalAmount))
                            .font(Typography.headline)
                            .foregroundStyle(ColorTokens.textPrimary)
                    }
                    .padding(10)
                    .background(ColorTokens.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
    
    // MARK: - 5. Daily Spending Trend Line Chart
    
    private var dailySpendingTrendSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Daily Spending Trend")
                        .font(Typography.headline)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer()
                    chartLegendPill(title: "7-Day Avg", color: ColorTokens.brandPrimary)
                }
                
                Chart {
                    ForEach(viewModel.dailySpendingTrend) { point in
                        // Daily Bars
                        BarMark(
                            x: .value("Date", point.dayLabel),
                            y: .value("Daily", point.amountDouble)
                        )
                        .foregroundStyle(ColorTokens.brandPrimary.opacity(0.25))
                        .cornerRadius(2)
                        
                        // 7-day Moving Average Line
                        LineMark(
                            x: .value("Date", point.dayLabel),
                            y: .value("Moving Avg", point.movingAverageDouble)
                        )
                        .foregroundStyle(ColorTokens.brandPrimary)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisValueLabel()
                            .font(Typography.caption2)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        if let doubleValue = value.as(Double.self) {
                            AxisValueLabel {
                                Text(CurrencyFormatter.shared.formatCompact(amount: Decimal(doubleValue)))
                                    .font(Typography.caption2)
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 6. Top Merchants Section
    
    private var topMerchantsSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top 5 Merchants")
                    .font(Typography.headline)
                    .foregroundStyle(ColorTokens.textPrimary)
                
                VStack(spacing: 8) {
                    ForEach(Array(viewModel.topMerchants.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(Typography.caption.weight(.bold))
                                .foregroundStyle(ColorTokens.textTertiary)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.merchantName)
                                    .font(Typography.headline)
                                    .foregroundStyle(ColorTokens.textPrimary)
                                
                                Text("\(item.transactionCount) transactions • \(item.categorySuggestion ?? "General")")
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                            
                            Spacer()
                            
                            Text(CurrencyFormatter.shared.format(amount: item.totalAmount))
                                .font(Typography.headline)
                                .foregroundStyle(ColorTokens.textPrimary)
                        }
                        .padding(.vertical, 4)
                        
                        if index < viewModel.topMerchants.count - 1 {
                            Divider()
                                .overlay(ColorTokens.separator)
                        }
                    }
                }
            }
        }
    }
    
    private func chartLegendPill(title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(Typography.caption2.weight(.medium))
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }
}

#Preview {
    AnalyticsOverviewView()
        .environment(AppState())
        .environment(\.dependencyContainer, .mock())
}
