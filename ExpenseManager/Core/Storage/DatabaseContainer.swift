import Foundation
import SwiftData

/// A failing store open is surfaced to the app; existing files are never reset.
public final class DatabaseContainer {
    public static var schema: Schema { ExpenseManagerSchemaV2.schema }
    public let container: ModelContainer
    public var modelContainer: ModelContainer { container }
    @MainActor public var mainContext: ModelContext { container.mainContext }

    public init(container: ModelContainer) { self.container = container }

    public static func production() throws -> DatabaseContainer {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return DatabaseContainer(container: try createContainer(inMemory: true))
        }
        return DatabaseContainer(container: try createContainer())
    }

    public static func createContainer(inMemory: Bool = false, storeURL: URL? = nil) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        } else {
            let defaultConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
            if !inMemory, let recoveredURL = try StartupRecoveryService.selectedStoreURL(defaultURL: defaultConfiguration.url, preferences: CurrencyFormatter.preferences) {
                configuration = ModelConfiguration(schema: schema, url: recoveredURL, cloudKitDatabase: .none)
            } else {
                configuration = defaultConfiguration
            }
        }
        if !inMemory {
            let directory = configuration.url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            #if os(iOS)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
            try protectStoreFiles(at: configuration.url)
            #endif
        }
        let container = try ModelContainer(
            for: ExpenseManagerSchemaV2.schema,
            migrationPlan: ExpenseManagerMigrationPlan.self,
            configurations: configuration
        )
        #if os(iOS)
        if !inMemory { try protectStoreFiles(at: configuration.url) }
        #endif
        return container
    }

    #if os(iOS)
    private static func protectStoreFiles(at url: URL) throws {
        for path in [url.path, url.path + "-wal", url.path + "-shm"] where FileManager.default.fileExists(atPath: path) {
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: path)
        }
    }
    #endif

    public static func inMemory() throws -> ModelContainer { try createContainer(inMemory: true) }
}
