import XCTest
@testable import ExpenseManager

final class BackupCurrencyCompatibilityTests: XCTestCase {
    func testLegacyINRAndExplicitForeignCurrencyDoNotFollowDisplayPreference() throws {
        let original = CurrencyFormatter.defaultCurrencyCode
        defer { CurrencyFormatter.setPreferredCurrency(original) }
        CurrencyFormatter.setPreferredCurrency("USD")
        let legacy = BudgetBackupDTO(id: "legacy", categoryID: nil, limitAmount: 100, month: Date(), alertThresholdPercent: 80, createdAt: Date(), updatedAt: Date())
        let foreign = BudgetBackupDTO(id: "foreign", categoryID: nil, limitAmount: 100, month: Date(), alertThresholdPercent: 80, createdAt: Date(), updatedAt: Date(), currencyCode: "USD")
        let encoder = DataExportService.createJSONEncoder()
        let legacyData = try encoder.encode(legacy)
        let foreignData = try encoder.encode(foreign)
        let legacyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: legacyData) as? [String: Any])
        let foreignObject = try XCTUnwrap(JSONSerialization.jsonObject(with: foreignData) as? [String: Any])
        XCTAssertNil(legacyObject["currencyCode"])
        XCTAssertEqual(foreignObject["currencyCode"] as? String, "USD")
        CurrencyFormatter.setPreferredCurrency("EUR")
        let decoder = DataExportService.createJSONDecoder()
        XCTAssertEqual(try decoder.decode(BudgetBackupDTO.self, from: legacyData).currencyCode, "INR")
        XCTAssertEqual(try decoder.decode(BudgetBackupDTO.self, from: foreignData).currencyCode, "USD")
    }
}
