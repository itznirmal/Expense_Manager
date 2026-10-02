import XCTest
@testable import ExpenseManager

final class MoneyFormattingRegressionTests: XCTestCase {
    func testParsingRejectsTrailingGarbageAndMalformedSigns() {
        let formatter = CurrencyFormatter.shared
        let locale = Locale(identifier: "en_US")
        XCTAssertNil(formatter.parse(from: "12.50coffee", locale: locale))
        XCTAssertNil(formatter.parse(from: "12-50", locale: locale))
        XCTAssertNil(formatter.parse(from: "NaN", locale: locale))
        XCTAssertNil(formatter.parse(from: "1,2", locale: locale))
        XCTAssertNil(formatter.parse(from: "(-12.50)", locale: locale))
        XCTAssertEqual(formatter.parse(from: ".50", locale: locale), Decimal(string: "0.50"))
        XCTAssertEqual(formatter.parse(from: "0.10", locale: locale)! + formatter.parse(from: "0.20", locale: locale)!, Decimal(string: "0.30"))
    }

    func testLocalizedAmountRoundTripAndCurrencyPrecision() {
        let formatter = CurrencyFormatter.shared
        let amount = Decimal(string: "1234.56")!
        let locale = Locale(identifier: "de_DE")
        let text = formatter.format(amount: amount, currencyCode: "EUR", locale: locale, includeSymbol: false)
        XCTAssertEqual(formatter.parse(from: text, locale: locale), amount)
        XCTAssertEqual(CurrencyFormatter.fractionDigits(for: "JPY"), 0)
        XCTAssertEqual(CurrencyFormatter.fractionDigits(for: "KWD"), 3)
    }

    func testCompactFormattingUsesExactDecimalThresholds() {
        let formatter = CurrencyFormatter.shared
        let locale = Locale(identifier: "en_IN")
        XCTAssertTrue(formatter.formatCompact(amount: 150000, currencyCode: "INR", locale: locale).contains("1.50 L"))
        XCTAssertTrue(formatter.formatCompact(amount: 25000000, currencyCode: "INR", locale: locale).contains("2.50 Cr"))
    }
}
