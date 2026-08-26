//
//  DatabaseContainer.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  SwiftData Database Container & Schema Manager.
//

import Foundation
import SwiftData

/// Central SwiftData ModelContainer manager configuring production persistence and in-memory test/preview stores.
public final class DatabaseContainer: @unchecked Sendable {
    
    // MARK: - Canonical Schema
    
    public static let schema = Schema([
        TransactionRecord.self,
        AccountRecord.self,
        CategoryRecord.self,
        TagRecord.self,
        MerchantRuleRecord.self,
        ImportFingerprintRecord.self,
        BudgetRecord.self
    ])
    
    // MARK: - Shared Production Singleton
    
    public static let shared: DatabaseContainer = {
        do {
            let container = try createContainer(inMemory: false)
            return DatabaseContainer(container: container)
        } catch {
            AppLogger.database.fault("Failed to initialize production SwiftData container: \(error.localizedDescription, privacy: .public)")
            fatalError("Failed to initialize SwiftData ModelContainer: \(error)")
        }
    }()
    
    // MARK: - Instance Properties
    
    public let container: ModelContainer
    
    @MainActor
    public var mainContext: ModelContext {
        container.mainContext
    }
    
    // MARK: - Initializer
    
    public init(container: ModelContainer) {
        self.container = container
    }
    
    // MARK: - Container Factories
    
    /// Creates a production SQLite or in-memory `ModelContainer`.
    public static func createContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    
    /// Convenience factory for isolated in-memory unit tests and SwiftUI previews.
    public static func inMemory() throws -> ModelContainer {
        try createContainer(inMemory: true)
    }
}
