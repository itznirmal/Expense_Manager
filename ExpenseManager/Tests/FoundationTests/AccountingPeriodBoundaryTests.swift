import XCTest
@testable import ExpenseManager

final class AccountingPeriodBoundaryTests: XCTestCase {
    func testFractionalLastSecondIncludedAndNextPeriodExcluded() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 12)))
        let nextMonth = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 1)))
        let lastEntry = nextMonth.addingTimeInterval(-0.125)
        XCTAssertLessThanOrEqual(lastEntry, DateFormatterHelper.shared.endOfMonth(for: date, calendar: calendar))
        XCTAssertLessThan(lastEntry, DateFormatterHelper.shared.endOfDay(for: date, calendar: calendar))
        XCTAssertLessThan(DateFormatterHelper.shared.endOfMonth(for: date, calendar: calendar), nextMonth)
        XCTAssertLessThan(DateFormatterHelper.shared.endOfDay(for: date, calendar: calendar), nextMonth)
    }
}
