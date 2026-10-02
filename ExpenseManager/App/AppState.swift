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
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .dashboard: return "Today"
        case .transactions: return "History"
        case .budgets: return "Plan"
        }
    }
    
    public var iconName: String {
        switch self {
        case .dashboard: return "rectangle.grid.2x2.fill"
        case .transactions: return "list.bullet.rectangle.portrait.fill"
        case .budgets: return "chart.pie.fill"
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
    case splitTransaction(transaction: TransactionCandidate)
    case statementImport
    case settings
    case analytics
    
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
        case .splitTransaction(let tx): return "splitTransaction_\(tx.id.uuidString)"
        case .statementImport: return "statementImport"
        case .settings: return "settings"
        case .analytics: return "analytics"
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
    public var dataRevision: Int = 0
    public var hasCompletedOnboarding: Bool {
        didSet { preferences.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    public var preferredCurrencyCode: String {
        didSet {
            guard Locale.commonISOCurrencyCodes.contains(preferredCurrencyCode) else {
                preferredCurrencyCode = oldValue
                return
            }
            preferences.set(preferredCurrencyCode, forKey: "preferredCurrencyCode")
            dataRevision += 1
        }
    }
    public private(set) var isSceneActive: Bool = true
    public var shouldHideSensitiveContent: Bool { !isSceneActive || (requireBiometrics && isBiometricallyLocked) }
    
    // Biometric Security (GT-66)
    public var requireBiometrics: Bool {
        didSet {
            preferences.set(requireBiometrics, forKey: "requireBiometrics")
            if requireBiometrics {
                isBiometricallyLocked = true
                if preferences === UserDefaults.standard { WidgetSnapshotStore.setShowsAmounts(false) }
            } else {
                isBiometricallyLocked = false
            }
        }
    }
    
    public var isBiometricallyLocked: Bool
    public var biometricErrorMessage: String? = nil
    public var sheetAfterDismiss: AppSheet?
    
    private var toastDismissTask: Task<Void, Never>?
    private let preferences: UserDefaults
    private var authenticationGeneration = 0
    private var authenticationContext: LAContext?
    private var pendingAuthenticationSuccess = false
    private var pendingAppLockSetting: Bool?
    
    public init(preferences: UserDefaults = CurrencyFormatter.preferences) {
        self.preferences = preferences
        self.hasCompletedOnboarding = preferences.bool(forKey: "hasCompletedOnboarding")
        let storedCurrency = preferences.string(forKey: "preferredCurrencyCode") ?? preferences.string(forKey: "defaultCurrency") ?? "INR"
        self.preferredCurrencyCode = Locale.commonISOCurrencyCodes.contains(storedCurrency) ? storedCurrency : "INR"
        let isBioRequired = preferences.bool(forKey: "requireBiometrics")
        self.requireBiometrics = isBioRequired
        self.isBiometricallyLocked = isBioRequired
    }
    
    // MARK: - Biometric Actions (GT-66)
    
    public func lockApp() {
        authenticationGeneration += 1
        authenticationContext?.invalidate()
        authenticationContext = nil
        pendingAuthenticationSuccess = false
        pendingAppLockSetting = nil
        coverSensitiveContent()
        if requireBiometrics {
            self.isBiometricallyLocked = true
            self.biometricErrorMessage = nil
        }
    }

    public func coverSensitiveContent(dismissSheets: Bool = true) {
        isSceneActive = false
        toastDismissTask?.cancel()
        activeToast = nil
        if dismissSheets { presentedSheet = nil }
        if dismissSheets { sheetAfterDismiss = nil }
        if requireBiometrics { isBiometricallyLocked = true }
    }

    public func activateScene() {
        isSceneActive = true
        if let enabled = pendingAppLockSetting {
            requireBiometrics = enabled
            isBiometricallyLocked = false
            pendingAppLockSetting = nil
        }
        if pendingAuthenticationSuccess {
            isBiometricallyLocked = false
            pendingAuthenticationSuccess = false
        }
    }

    /// Security preferences change only after authentication in the current session.
    public func requestAppLockChange(to enabled: Bool) {
        guard !shouldHideSensitiveContent else { return }
        let context = LAContext()
        authenticationContext?.invalidate()
        authenticationContext = context
        authenticationGeneration += 1
        let generation = authenticationGeneration
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            authenticationContext = nil
            showToast(title: "Authentication unavailable", message: "Set up Face ID, Touch ID, or a device passcode to change App Lock.", type: .warning)
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: enabled ? "Enable App Lock." : "Disable App Lock.") { [weak self] success, _ in
            Task { @MainActor in
                guard let self, self.authenticationGeneration == generation else { return }
                self.authenticationContext = nil
                guard success else {
                    self.showToast(title: "App Lock unchanged", message: "Authentication did not complete.", type: .warning)
                    return
                }
                if self.isSceneActive {
                    self.requireBiometrics = enabled
                    self.isBiometricallyLocked = false
                } else {
                    self.pendingAppLockSetting = enabled
                }
            }
        }
    }

    public func refreshPendingReview(container: DependencyContainer) async {
        do {
            pendingReviewCount = try await container.transactionService.fetchPendingReviewTransactions().count
        } catch {
            showToast(title: "Couldn't load items to review", message: "Please try again.", type: .error)
        }
    }
    
    public func authenticateBiometrics() {
        guard requireBiometrics else {
            self.isBiometricallyLocked = false
            return
        }
        guard authenticationContext == nil else { return }
        
        let context = LAContext()
        authenticationContext?.invalidate()
        authenticationContext = context
        authenticationGeneration += 1
        let generation = authenticationGeneration
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) ||
              context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Fail closed
            authenticationContext = nil
            self.isBiometricallyLocked = true
            self.biometricErrorMessage = "Biometrics or passcode not configured."
            return
        }
        
        let reason = "Unlock Expense Manager to access your financial records."
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [weak self] success, evalError in
            Task { @MainActor in
                guard let self = self, self.authenticationGeneration == generation else { return }
                self.authenticationContext = nil
                if success {
                    if self.isSceneActive {
                        self.isBiometricallyLocked = false
                    } else {
                        self.pendingAuthenticationSuccess = true
                    }
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
        guard !shouldHideSensitiveContent else { return }
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
        guard !shouldHideSensitiveContent else { return }
        self.presentedSheet = sheet
    }
    
    public func dismissSheet() {
        self.presentedSheet = nil
    }

    public func replaceSheet(with sheet: AppSheet) {
        guard !shouldHideSensitiveContent else { return }
        sheetAfterDismiss = sheet
        presentedSheet = nil
    }
}
