//
//  RootView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Root Tab Navigation Shell with Toast, Sheet & Biometric Lock Coordinator.
//

import SwiftUI

public struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(DependencyContainer.self) private var container
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = RootViewModel()
    
    public init() {}
    
    public var body: some View {
        @Bindable var state = appState
        
        ZStack(alignment: .top) {
            if appState.shouldHideSensitiveContent {
                if appState.isSceneActive {
                    BiometricLockShieldView()
                } else {
                    ColorTokens.backgroundPrimary.ignoresSafeArea()
                        .overlay(Image(systemName: "lock.shield").font(.largeTitle))
                }
            } else if !appState.hasCompletedOnboarding {
                SpendingWelcomeView()
            } else {
                mainTabContent(state: state)
            }
            
            // Toast Banner Overlay
            if !appState.shouldHideSensitiveContent, let toast = appState.activeToast {
                toastBanner(toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(300)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await appState.refreshPendingReview(container: container) }
            }
        }
        .task { await appState.refreshPendingReview(container: container) }
        // Sheet Presentations
        .sheet(item: $state.presentedSheet, onDismiss: {
            appState.dataRevision += 1
            if let next = appState.sheetAfterDismiss, !appState.shouldHideSensitiveContent {
                appState.sheetAfterDismiss = nil
                appState.presentSheet(next)
            }
            Task { await appState.refreshPendingReview(container: container) }
        }) { sheet in
            Group {
            switch sheet {
            case .smartTextEntry:
                SmartTextComposerView()
            case .manualEntry(let candidate):
                ManualTransactionComposerView(candidate: candidate)
            case .voiceEntry:
                VoiceEntryView()
            case .importReviewQueue:
                ReviewQueueView()
            case .smsDiagnostics:
                SMSDiagnosticsView()
            case .addAccount:
                AccountComposerView()
            case .accountComposer(let account):
                AccountComposerView(account: account)
            case .accountsList:
                AccountsListView()
            case .categoryComposer:
                CategoryComposerView()
            case .categoriesManagement:
                CategoriesManagementView()
            case .budgetComposer(let budget):
                BudgetComposerView(budget: budget)
            case .transactionDetail(let tx):
                TransactionDetailView(transaction: tx)
            case .transactionFilter:
                TransactionFilterSheetView(viewModel: TransactionsListViewModel())
            case .transactionBatchCategorize:
                Text("Batch Categorize")
            case .splitTransaction(let tx):
                SplitTransactionView(transaction: tx)
            case .statementImport:
                StatementImportView()
            case .settings:
                SettingsView()
            case .analytics:
                AnalyticsOverviewView()
            }
            }
            .overlay {
                if appState.shouldHideSensitiveContent {
                    if appState.isSceneActive {
                        BiometricLockShieldView()
                    } else {
                        ColorTokens.backgroundPrimary.ignoresSafeArea()
                            .overlay(Image(systemName: "lock.shield").font(.largeTitle))
                    }
                }
            }
        }
    }
    
    // MARK: - Main Tab Content
    
    private func mainTabContent(state: AppState) -> some View {
        @Bindable var bindableState = state
        return TabView(selection: $bindableState.selectedTab) {
            DashboardView()
                .tabItem {
                    Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.iconName)
                }
                .tag(AppTab.dashboard)
            
            TransactionsListView()
                .tabItem {
                    Label(AppTab.transactions.title, systemImage: AppTab.transactions.iconName)
                }
                .tag(AppTab.transactions)
            
            BudgetsOverviewView()
                .tabItem {
                    Label(AppTab.budgets.title, systemImage: AppTab.budgets.iconName)
                }
                .tag(AppTab.budgets)
            
        }
        .tint(ColorTokens.brandPrimary)
    }
    
    // MARK: - Toast Banner View
    
    private func toastBanner(_ toast: ToastMessage) -> some View {
        HStack(spacing: 12) {
            Image(systemName: toast.type.iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(toastIconColor(for: toast.type))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                
                if let message = toast.message {
                    Text(message)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Button(action: {
                appState.dismissToast()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(6)
                    .background(ColorTokens.backgroundTertiary)
                    .clipShape(Circle())
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Dismiss notification")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ColorTokens.elevatedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ColorTokens.borderSubtle, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private func toastIconColor(for type: ToastMessage.ToastType) -> Color {
        switch type {
        case .info: return ColorTokens.brandPrimary
        case .success: return ColorTokens.incomeAccent
        case .warning: return ColorTokens.warningAccent
        case .error: return ColorTokens.criticalAccent
        }
    }
}

#Preview("Light Mode") {
    RootView()
        .environment(AppState())
        .environment(DependencyContainer.mock())
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    RootView()
        .environment(AppState())
        .environment(DependencyContainer.mock())
        .preferredColorScheme(.dark)
}
