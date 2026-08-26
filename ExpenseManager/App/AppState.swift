//
//  AppState.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Observable App-Level State & Navigation Coordinator.
//

import SwiftUI
import Observation
import LocalAuthentication

/// Top-level application tabs.
public enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case dashboard
    case transactions
    case budgets
    case analytics
    case settings
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .transactions: return "Transactions"
        case .budgets: return "Budgets"
        case .analytics: return "Analytics"
        case .settings: return "Settings"
        }
    }
    
    public var iconName: String {
        switch self {
        case .dashboard: return "rectangle.grid.2x2.fill"
        case .transactions: return "list.bullet.rectangle.portrait.fill"
        case .budgets: return "chart.pie.fill"
        case .analytics: return "chart.xyaxis.line"
        case .settings: return "gearshape.fill"
        }
    }
}

/// Global sheet presentations.
public enum AppSheet: Identifiable, Sendable, Equatable {
    case manualEntry(candidate: TransactionCandidate? = nil)
    case smartTextEntry
    case voiceEntry
    case importReviewQueue
    case addAccount
    case accountComposer(account: AccountDTO? = nil)
    case accountsList
    case categoryComposer
    case categoriesManagement
    case budgetComposer(budget: BudgetDTO? = nil)
    case transactionDetail(transaction: TransactionCandidate)
    case transactionFilter
    case transactionBatchCategorize
    case smsDiagnostics
    
    public var id: String {
        switch self {
        case .manualEntry(let candidate): return "manualEntry_\(candidate?.id.uuidString ?? "new")"
        case .smartTextEntry: return "smartTextEntry"
        case .voiceEntry: return "voiceEntry"
        case .importReviewQueue: return "importReviewQueue"
        case .addAccount: return "addAccount"
        case .accountComposer(let account): return "accountComposer_\(account?.id ?? "new")"
        case .accountsList: return "accountsList"
        case .categoryComposer: return "categoryComposer"
        case .categoriesManagement: return "categoriesManagement"
        case .budgetComposer(let budget): return "budgetComposer_\(budget?.id ?? "new")"
        case .transactionDetail(let tx): return "transactionDetail_\(tx.id.uuidString)"
        case .transactionFilter: return "transactionFilter"
        case .transactionBatchCategorize: return "transactionBatchCategorize"
        case .smsDiagnostics: return "smsDiagnostics"
        }
    }
}

/// Central application observable state managing active tab, sheets, toasts, and security locks.
@Observable
@MainActor
public final class AppState {
    
    // MARK: - State Properties
    
    public var selectedTab: AppTab = .dashboard
    public var presentedSheet: AppSheet? = nil
    public var activeToast: ToastMessage? = nil
    public var pendingReviewCount: Int = 0
    
    // Biometric Security (GT-66)
    public var requireBiometrics: Bool {
        didSet {
            UserDefaults.standard.set(requireBiometrics, forKey: "requireBiometrics")
            if requireBiometrics {
                isBiometricallyLocked = true
            } else {
                isBiometricallyLocked = false
            }
        }
    }
    
    public var isBiometricallyLocked: Bool
    public var biometricErrorMessage: String? = nil
    
    private var toastDismissTask: Task<Void, Never>?
    
    public init() {
        let isBioRequired = UserDefaults.standard.bool(forKey: "requireBiometrics")
        self.requireBiometrics = isBioRequired
        self.isBiometricallyLocked = isBioRequired
    }
    
    // MARK: - Biometric Actions (GT-66)
    
    public func lockApp() {
        if requireBiometrics {
            self.isBiometricallyLocked = true
            self.biometricErrorMessage = nil
        }
    }
    
    public func authenticateBiometrics() {
        guard requireBiometrics else {
            self.isBiometricallyLocked = false
            return
        }
        
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) ||
              context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Fail closed
            self.isBiometricallyLocked = true
            self.biometricErrorMessage = "Biometrics or passcode not configured."
            return
        }
        
        let reason = "Unlock Expense Manager to access your financial records."
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [weak self] success, evalError in
            Task { @MainActor in
                guard let self = self else { return }
                if success {
                    self.isBiometricallyLocked = false
                    self.biometricErrorMessage = nil
                } else {
                    self.isBiometricallyLocked = true
                    self.biometricErrorMessage = evalError?.localizedDescription ?? "Authentication failed."
                }
            }
        }
    }
    
    // MARK: - Toast Handling
    
    /// Presents a transient toast banner to the user.
    public func showToast(
        title: String,
        message: String? = nil,
        type: ToastMessage.ToastType = .info,
        duration: TimeInterval = 3.0
    ) {
        toastDismissTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.activeToast = ToastMessage(
                title: title,
                message: message,
                type: type,
                duration: duration
            )
        }
        
        toastDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.25)) {
                    self.activeToast = nil
                }
            }
        }
    }
    
    /// Immediately dismisses the active toast.
    public func dismissToast() {
        toastDismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.25)) {
            self.activeToast = nil
        }
    }
    
    // MARK: - Sheet Navigation
    
    public func presentSheet(_ sheet: AppSheet) {
        self.presentedSheet = sheet
    }
    
    public func dismissSheet() {
        self.presentedSheet = nil
    }
}

// MARK: - SwiftUI Environment Key

private struct AppStateKey: EnvironmentKey {
    static let defaultValue: AppState = AppState()
}

public extension EnvironmentValues {
    var appState: AppState {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }
}
