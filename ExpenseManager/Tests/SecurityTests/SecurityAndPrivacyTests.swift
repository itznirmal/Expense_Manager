import XCTest
import Speech
@testable import ExpenseManager

@MainActor
final class SecurityAndPrivacyTests: XCTestCase {

    func testBiometricFailClosedOnUnconfiguredDevice() {
        let appState = AppState()
        appState.requireBiometrics = true
        // Without mocked LAContext, calling this will use the real context.
        // On simulator/device without biometrics, it will fail and lock.
        appState.authenticateBiometrics()
        // Wait for async execution
        let expectation = XCTestExpectation(description: "Wait for bio async block")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(appState.isBiometricallyLocked, "Biometrics must fail closed on unconfigured device.")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testAudioRecordingServiceLifecycleAndPrivacyState() async {
        let service = AudioRecordingService(locale: Locale(identifier: "en-IN"))
        XCTAssertFalse(service.isRecording, "Service should not be recording initially")
        XCTAssertEqual(service.audioPower, 0.0, "Initial audio power must be 0.0")
        
        // Test stopRecording under concurrency/thread-safety locks
        await service.stopRecording()
        XCTAssertFalse(service.isRecording, "Service must remain stopped after stopRecording")
        XCTAssertEqual(service.audioPower, 0.0, "Audio power must be reset to 0.0 on stop")
    }

    func testJSONBackupIntegrityVerificationAndCorruptPayloadRejection() async throws {
        let container = try DatabaseContainer.inMemory()
        let service = DataExportService(modelContainer: container)
        
        let validBackupData = try await service.exportJSONBackup()
        let payload = try service.validateBackupPayload(validBackupData)
        XCTAssertEqual(payload.schemaVersion, 1)
        
        // Corrupt the package checksum deterministically, including when the
        // in-memory fixture contains no transactions to mutate.
        var payloadObject = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: validBackupData) as? [String: Any]
        )
        payloadObject["checksum"] = String(repeating: "0", count: 64)
        let corruptedData = try JSONSerialization.data(withJSONObject: payloadObject, options: [.sortedKeys])
        
        do {
            _ = try service.validateBackupPayload(corruptedData)
            XCTFail("Should have thrown error for corrupted payload or checksum mismatch")
        } catch {
            // Expected
            XCTAssertTrue(true)
        }
    }

    func testCSVFormulaInjectionSanitization() {
        let input = "=cmd|' /C calc'!A0"
        let sanitized = CSVFormulaSanitizer.sanitizeAndEscape(input)
        XCTAssertEqual(sanitized, "\"'=cmd|' /C calc'!A0\"")
        
        let input2 = "@SUM(1+1)"
        let sanitized2 = CSVFormulaSanitizer.sanitizeAndEscape(input2)
        XCTAssertEqual(sanitized2, "\"'@SUM(1+1)\"")
    }
}
