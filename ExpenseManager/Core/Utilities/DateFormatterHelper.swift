//
//  DateFormatterHelper.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Date formatting utilities & calendar calculations.
//

import Foundation

/// Thread-safe helper for formatting dates and calculating financial accounting periods.
public final class DateFormatterHelper: Sendable {
    
    public static let shared = DateFormatterHelper()
    
    public init() {}
    
    // MARK: - Relative & Friendly Date Formatting
    
    /// Returns a human-friendly relative date description (e.g., "Today", "Yesterday", "Wednesday", or "25 Aug").
    public func relativeDateString(for date: Date, relativeTo referenceDate: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let components = calendar.dateComponents([.day, .year], from: date, to: referenceDate)
            if let dayDiff = components.day, dayDiff > 0 && dayDiff < 7 {
                let weekdayFormatter = DateFormatter()
                weekdayFormatter.dateFormat = "EEEE"
                return weekdayFormatter.string(from: date)
            } else if let yearDiff = components.year, yearDiff != 0 {
                let fullFormatter = DateFormatter()
                fullFormatter.dateFormat = "d MMM yyyy"
                return fullFormatter.string(from: date)
            } else {
                let monthDayFormatter = DateFormatter()
                monthDayFormatter.dateFormat = "d MMM"
                return monthDayFormatter.string(from: date)
            }
        }
    }
    
    /// Returns a short standard date string, e.g. "25 Aug 2026".
    public func shortDate(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    /// Returns time formatted string, e.g. "10:45 AM".
    public func timeOnly(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Returns formatted month and year, e.g. "August 2026".
    public func monthYear(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    // MARK: - Accounting Periods & Boundary Calculations
    
    /// Returns the beginning of the month for the given date.
    public func startOfMonth(for date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
    
    /// Returns the end of the month (last second) for the given date.
    public func endOfMonth(for date: Date, calendar: Calendar = .current) -> Date {
        let start = startOfMonth(for: date, calendar: calendar)
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: start),
           let end = calendar.date(byAdding: .second, value: -1, to: nextMonth) {
            return end
        }
        return date
    }
    
    /// Returns the start of the day (00:00:00).
    public func startOfDay(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }
    
    /// Returns the end of the day (23:59:59).
    public func endOfDay(for date: Date, calendar: Calendar = .current) -> Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return calendar.date(byAdding: components, to: startOfDay(for: date, calendar: calendar)) ?? date
    }
}
