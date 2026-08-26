//
//  ExpenseShortcutsProvider.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  AppShortcutsProvider exposing Siri Voice Commands and Shortcuts App Actions.
//

import Foundation
import AppIntents

/// Registers predefined Siri voice phrases and Shortcuts for Expense Manager.
public struct ExpenseShortcutsProvider: AppShortcutsProvider {
    
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Log Expense in \(.applicationName)",
                "Quick Expense with \(.applicationName)",
                "Add Transaction in \(.applicationName)",
                "Log money in \(.applicationName)"
            ],
            shortTitle: "Log Expense",
            systemImageName: "square.and.pencil"
        )
        
        AppShortcut(
            intent: ParseTextExpenseIntent(),
            phrases: [
                "Parse SMS in \(.applicationName)",
                "Import Message with \(.applicationName)",
                "Parse Expense in \(.applicationName)"
            ],
            shortTitle: "Parse Text or SMS",
            systemImageName: "message.badge.filled.fill"
        )
    }
}
