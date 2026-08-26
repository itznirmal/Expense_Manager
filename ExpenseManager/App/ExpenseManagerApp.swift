//
//  ExpenseManagerApp.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Application Lifecycle Entry Point.
//

import SwiftUI
import SwiftData

@main
struct ExpenseManagerApp: App {
    @State private var appState = AppState()
    private let databaseContainer = DatabaseContainer.shared
    @State private var container: DependencyContainer
    
    init() {
        let dbContainer = DatabaseContainer.shared
        _container = State(initialValue: DependencyContainer.live(modelContainer: dbContainer.container))
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(\.dependencyContainer, container)
                .modelContainer(databaseContainer.container)
                .task {
                    // Seed default taxonomy on initial launch
                    try? await container.categoryService.seedDefaultCategoriesIfNeeded()
                }
        }
    }
}
