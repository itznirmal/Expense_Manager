import XCTest
@testable import ExpenseManager

@MainActor
final class AppLockStateTests: XCTestCase {
    func testCurrencyPreferencePersistsWithoutRelabelingAnotherState() {
        let suite = "CurrencyStateTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(preferences: defaults)
        state.preferredCurrencyCode = "USD"
        XCTAssertEqual(AppState(preferences: defaults).preferredCurrencyCode, "USD")
        state.preferredCurrencyCode = "INVALID"
        XCTAssertEqual(state.preferredCurrencyCode, "USD")
    }

    func testBackgroundCoverClearsFinancialOverlaysAndBlocksNewSheets() {
        let suite = "AppLockStateTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(preferences: defaults)
        state.showToast(title: "Saved", message: "USD 25.00 at Cafe", type: .success)
        state.presentSheet(.manualEntry())
        state.coverSensitiveContent()
        XCTAssertTrue(state.shouldHideSensitiveContent)
        XCTAssertNil(state.activeToast)
        XCTAssertNil(state.presentedSheet)
        state.showToast(title: "Another amount", type: .success)
        state.presentSheet(.smartTextEntry)
        XCTAssertNil(state.activeToast)
        XCTAssertNil(state.presentedSheet)
    }

    func testAppLockPersistsAndColdLaunchStartsLocked() {
        let suite = "AppLockStateTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(preferences: defaults)
        state.requireBiometrics = true
        let relaunched = AppState(preferences: defaults)
        XCTAssertTrue(relaunched.requireBiometrics)
        XCTAssertTrue(relaunched.isBiometricallyLocked)
        relaunched.activateScene()
        XCTAssertTrue(relaunched.shouldHideSensitiveContent)
    }
}
