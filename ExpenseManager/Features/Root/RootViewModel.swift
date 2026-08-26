//
//  RootViewModel.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Root Coordinator View Model.
//

import SwiftUI
import Observation

@Observable
@MainActor
public final class RootViewModel {
    public var isQuickActionMenuPresented: Bool = false
    
    public init() {}
    
    public func handleQuickActionTap(appState: AppState) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        appState.presentSheet(.smartTextEntry)
    }
    
    public func handleLongPressQuickAction() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        isQuickActionMenuPresented = true
    }
}
