import Foundation

public enum StartupRecoveryError: LocalizedError, Equatable, Sendable {
    case invalidRecoveryStoreID
    case missingRecoveryStore

    public var errorDescription: String? {
        switch self {
        case .invalidRecoveryStoreID:
            return "The saved recovery store identifier is invalid."
        case .missingRecoveryStore:
            return "The saved recovery store is unavailable. Choose a recovery backup or restore the original store."
        }
    }
}

/// Creates an isolated, protected store from a validated backup during startup
/// recovery. The active store is never replaced by this service.
@MainActor
public enum StartupRecoveryService {
    public nonisolated static let recoveryStoreIDKey = "recoveryStoreID"

    /// Validates and restores a backup into a fresh recovery store.
    ///
    /// The preference pointer changes only after the new store has completed its
    /// restore save. Failed restores leave the prior pointer and original store
    /// untouched; an incomplete recovery directory is intentionally left
    /// inactive for later quarantine or cleanup.
    public static func restoreBackup(
        data: Data,
        directory: URL,
        preferences: UserDefaults
    ) async throws -> DatabaseContainer {
        // Perform every decode, checksum, graph, enum, and money check before
        // asking SwiftData to create any recovery files.
        _ = try DataExportService.validateBackupPayloadData(data)

        let recoveryID = UUID()
        let storeURL = recoveryStoreURL(directory: directory, identifier: recoveryID)
        let modelContainer = try DatabaseContainer.createContainer(storeURL: storeURL)
        let exportService = DataExportService(modelContainer: modelContainer)
        _ = try await exportService.restoreJSONBackup(from: data)

        // This is the commit point for selecting the recovered store.
        preferences.set(recoveryID.uuidString, forKey: recoveryStoreIDKey)
        return DatabaseContainer(container: modelContainer)
    }

    /// Returns the previously committed recovery store when its preference is
    /// a canonical UUID and the store file still exists. Nil means that no
    /// recovery pointer has been committed; an invalid or missing committed
    /// store throws so startup cannot silently fall back to the old ledger.
    /// The input is the application's normal `default.store` URL.
    public nonisolated static func selectedStoreURL(
        defaultURL: URL,
        preferences: UserDefaults
    ) throws -> URL? {
        guard let token = preferences.string(forKey: recoveryStoreIDKey) else {
            return nil
        }
        guard let identifier = UUID(uuidString: token),
              token.caseInsensitiveCompare(identifier.uuidString) == .orderedSame else {
            throw StartupRecoveryError.invalidRecoveryStoreID
        }

        let url = recoveryStoreURL(
            directory: defaultURL.deletingLastPathComponent(),
            identifier: identifier
        )
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw StartupRecoveryError.missingRecoveryStore
        }
        return url
    }

    private nonisolated static func recoveryStoreURL(directory: URL, identifier: UUID) -> URL {
        directory
            .appendingPathComponent("RecoveredStores", isDirectory: true)
            .appendingPathComponent(identifier.uuidString, isDirectory: true)
            .appendingPathComponent("default.store", isDirectory: false)
    }
}
