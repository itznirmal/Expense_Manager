import XCTest
import SwiftData
@testable import ExpenseManager

final class StartupRecoveryTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var originalStoreURL: URL!
    private var preferences: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExpenseManagerRecoveryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        originalStoreURL = temporaryDirectory.appendingPathComponent("default.store")
        try Data("original-store-sentinel", encoding: .utf8)!.write(to: originalStoreURL, options: .atomic)

        suiteName = "ExpenseManager.StartupRecoveryTests.\(UUID().uuidString)"
        preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        preferences.removePersistentDomain(forName: suiteName)
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
        originalStoreURL = nil
        preferences = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    @MainActor
    func testInvalidChecksumLeavesPointerAndOriginalStoreUntouched() async throws {
        let validBackup = try await MockDataExportService().exportJSONBackup()
        let invalidBackup = try tamperChecksum(in: validBackup)
        preferences.set("prior-recovery", forKey: StartupRecoveryService.recoveryStoreIDKey)

        do {
            _ = try await StartupRecoveryService.restoreBackup(
                data: invalidBackup,
                directory: temporaryDirectory,
                preferences: preferences
            )
            XCTFail("Invalid checksum should prevent recovery")
        } catch {
            guard case DataExportError.checksumMismatch = error else {
                return XCTFail("Expected checksum mismatch, got \(error)")
            }
        }

        XCTAssertEqual(
            preferences.string(forKey: StartupRecoveryService.recoveryStoreIDKey),
            "prior-recovery"
        )
        XCTAssertEqual(
            try Data(contentsOf: originalStoreURL),
            Data("original-store-sentinel", encoding: .utf8)
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: temporaryDirectory.appendingPathComponent("RecoveredStores").path
            )
        )
    }

    @MainActor
    func testSuccessfulRecoveryCommitsPointerAfterRestoreAndPreservesOriginal() async throws {
        let backup = try await MockDataExportService().exportJSONBackup()
        let recovered = try await StartupRecoveryService.restoreBackup(
            data: backup,
            directory: temporaryDirectory,
            preferences: preferences
        )

        let accounts = try recovered.container.mainContext.fetch(FetchDescriptor<AccountRecord>())
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts.first?.currentBalance, Decimal(50_000))

        let recoveryToken = try XCTUnwrap(
            preferences.string(forKey: StartupRecoveryService.recoveryStoreIDKey)
        )
        let recoveryID = try XCTUnwrap(UUID(uuidString: recoveryToken))
        XCTAssertEqual(recoveryToken, recoveryID.uuidString)

        let selectedURL = try XCTUnwrap(
            try StartupRecoveryService.selectedStoreURL(
                defaultURL: originalStoreURL,
                preferences: preferences
            )
        )
        XCTAssertEqual(selectedURL.lastPathComponent, "default.store")
        XCTAssertTrue(FileManager.default.fileExists(atPath: selectedURL.path))
        XCTAssertEqual(
            try Data(contentsOf: originalStoreURL),
            Data("original-store-sentinel", encoding: .utf8)
        )
    }

    @MainActor
    func testSelectedStoreURLRejectsMalformedOrMissingRecoveryPointer() throws {
        XCTAssertNil(
            try StartupRecoveryService.selectedStoreURL(
                defaultURL: originalStoreURL,
                preferences: preferences
            )
        )

        preferences.set("../../outside", forKey: StartupRecoveryService.recoveryStoreIDKey)
        XCTAssertThrowsError(
            try StartupRecoveryService.selectedStoreURL(
                defaultURL: originalStoreURL,
                preferences: preferences
            )
        )

        preferences.set(UUID().uuidString, forKey: StartupRecoveryService.recoveryStoreIDKey)
        XCTAssertThrowsError(
            try StartupRecoveryService.selectedStoreURL(
                defaultURL: originalStoreURL,
                preferences: preferences
            )
        )
    }

    private func tamperChecksum(in data: Data) throws -> Data {
        var object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object["checksum"] = String(repeating: "0", count: 64)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
