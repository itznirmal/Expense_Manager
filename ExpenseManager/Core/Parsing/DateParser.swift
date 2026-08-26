//
//  DateParser.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Temporal Phrase & Absolute Date Parser.
//

import Foundation

/// Result of a date extraction operation.
public struct ExtractedDate: Equatable, Sendable {
    public let date: Date
    public let rawMatch: String
    public let range: Range<String.Index>
    
    public init(date: Date, rawMatch: String, range: Range<String.Index>) {
        self.date = date
        self.rawMatch = rawMatch
        self.range = range
    }
}

/// Robust extractor for temporal phrases and explicit date patterns.
public struct DateParser: Sendable {
    
    public init() {}
    
    // Relative date keyword mappings
    private static let relativePatterns: [(pattern: String, dayOffset: Int)] = [
        ("(?i)\\bday before yesterday\\b", -2),
        ("(?i)\\byesterday(?:\\s+(?:night|evening|morning|afternoon))?\\b|\\byday\\b|\\blast\\s+night\\b", -1),
        ("(?i)\\btoday(?:\\s+(?:night|evening|morning|afternoon))?\\b|\\btonight\\b|\\bthis\\s+(?:morning|evening|afternoon)\\b", 0)
    ]
    
    // Weekday names for "last <weekday>"
    private static let weekdays: [String: Int] = [
        "sunday": 1,
        "monday": 2,
        "tuesday": 3,
        "wednesday": 4,
        "thursday": 5,
        "friday": 6,
        "saturday": 7
    ]
    
    // Month abbreviations & names
    private static let monthNames: [String: Int] = [
        "jan": 1, "january": 1,
        "feb": 2, "february": 2,
        "mar": 3, "march": 3,
        "apr": 4, "april": 4,
        "may": 5,
        "jun": 6, "june": 6,
        "jul": 7, "july": 7,
        "aug": 8, "august": 8,
        "sep": 9, "sept": 9, "september": 9,
        "oct": 10, "october": 10,
        "nov": 11, "november": 11,
        "dec": 12, "december": 12
    ]
    
    /// Extracts a date from natural language or formatted strings.
    public static func extractDate(
        from text: String,
        referenceDate: Date = Date(),
        calendar: Calendar = Calendar.current
    ) -> ExtractedDate? {
        let normalized = InputNormalizer.normalize(text)
        guard !normalized.isEmpty else { return nil }
        let nsRange = NSRange(location: 0, length: normalized.utf16.count)
        
        // 1. Match Relative Words ("today", "yesterday", "last night", "day before yesterday")
        for (pattern, offset) in relativePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: normalized, options: [], range: nsRange),
               let range = Range(match.range, in: normalized) {
                
                let targetDate = calendar.date(byAdding: .day, value: offset, to: referenceDate) ?? referenceDate
                return ExtractedDate(
                    date: targetDate,
                    rawMatch: String(normalized[range]),
                    range: range
                )
            }
        }
        
        // 2. Match "last <weekday>" (e.g. "last Friday", "last monday")
        let lastWeekdayPattern = "(?i)\\blast\\s+(sunday|monday|tuesday|wednesday|thursday|friday|saturday)\\b"
        if let regex = try? NSRegularExpression(pattern: lastWeekdayPattern, options: []),
           let match = regex.firstMatch(in: normalized, options: [], range: nsRange),
           match.numberOfRanges >= 2,
           let fullRange = Range(match.range(at: 0), in: normalized),
           let dayRange = Range(match.range(at: 1), in: normalized) {
            
            let dayName = String(normalized[dayRange]).lowercased()
            if let targetWeekday = weekdays[dayName] {
                let currentWeekday = calendar.component(.weekday, from: referenceDate)
                var diff = currentWeekday - targetWeekday
                if diff <= 0 {
                    diff += 7
                }
                let targetDate = calendar.date(byAdding: .day, value: -diff, to: referenceDate) ?? referenceDate
                return ExtractedDate(
                    date: targetDate,
                    rawMatch: String(normalized[fullRange]),
                    range: fullRange
                )
            }
        }
        
        // 3. Match Day Month [Year] with optional '-', '/', or space (e.g. "25-AUG-26", "25-Aug-26", "25Aug26", "25 August 2026")
        let dayMonthPattern = "(?i)\\b([0-3]?[0-9])(?:st|nd|rd|th)?(?:\\s*[-/]?\\s*)(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)(?:\\s*[-/]?\\s*([0-9]{2,4}))?\\b"
        if let regex = try? NSRegularExpression(pattern: dayMonthPattern, options: []),
           let match = regex.firstMatch(in: normalized, options: [], range: nsRange),
           match.numberOfRanges >= 3,
           let fullRange = Range(match.range(at: 0), in: normalized),
           let dayRange = Range(match.range(at: 1), in: normalized),
           let monthRange = Range(match.range(at: 2), in: normalized) {
            
            let day = Int(normalized[dayRange]) ?? 1
            let monthStr = String(normalized[monthRange]).lowercased()
            let month = monthNames[monthStr] ?? 1
            
            var year = calendar.component(.year, from: referenceDate)
            if match.numberOfRanges >= 4, match.range(at: 3).location != NSNotFound,
               let yearRange = Range(match.range(at: 3), in: normalized),
               let explicitYear = Int(normalized[yearRange]) {
                if explicitYear < 100 {
                    year = 2000 + explicitYear
                } else {
                    year = explicitYear
                }
            }
            
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            components.hour = 12
            
            if let date = calendar.date(from: components) {
                return ExtractedDate(
                    date: date,
                    rawMatch: String(normalized[fullRange]),
                    range: fullRange
                )
            }
        }
        
        // 4. Match Month Day [Year] (e.g. "Aug 25", "August 25 2026", "Aug-25-2026")
        let monthDayPattern = "(?i)\\b(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)(?:\\s*[-/]?\\s*)([0-3]?[0-9])(?:st|nd|rd|th)?(?:,?\\s*[-/]?\\s*([0-9]{2,4}))?\\b"
        if let regex = try? NSRegularExpression(pattern: monthDayPattern, options: []),
           let match = regex.firstMatch(in: normalized, options: [], range: nsRange),
           match.numberOfRanges >= 3,
           let fullRange = Range(match.range(at: 0), in: normalized),
           let monthRange = Range(match.range(at: 1), in: normalized),
           let dayRange = Range(match.range(at: 2), in: normalized) {
            
            let monthStr = String(normalized[monthRange]).lowercased()
            let month = monthNames[monthStr] ?? 1
            let day = Int(normalized[dayRange]) ?? 1
            
            var year = calendar.component(.year, from: referenceDate)
            if match.numberOfRanges >= 4, match.range(at: 3).location != NSNotFound,
               let yearRange = Range(match.range(at: 3), in: normalized),
               let explicitYear = Int(normalized[yearRange]) {
                if explicitYear < 100 {
                    year = 2000 + explicitYear
                } else {
                    year = explicitYear
                }
            }
            
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            components.hour = 12
            
            if let date = calendar.date(from: components) {
                return ExtractedDate(
                    date: date,
                    rawMatch: String(normalized[fullRange]),
                    range: fullRange
                )
            }
        }
        
        // 5. Match ISO / Delimited Formats (e.g. 25/08/2026, 25-08-2026, 2026-08-25, 25/08/26)
        let numericDatePattern = "\\b([0-3]?[0-9])[/-]([0-1]?[0-9])[/-]([0-9]{2,4})\\b|\\b([0-9]{4})[/-]([0-1]?[0-9])[/-]([0-3]?[0-9])\\b"
        if let regex = try? NSRegularExpression(pattern: numericDatePattern, options: []),
           let match = regex.firstMatch(in: normalized, options: [], range: nsRange),
           let fullRange = Range(match.range(at: 0), in: normalized) {
            
            let matchStr = String(normalized[fullRange])
            if let parsedDate = parseNumericDateString(matchStr, calendar: calendar, referenceDate: referenceDate) {
                return ExtractedDate(
                    date: parsedDate,
                    rawMatch: matchStr,
                    range: fullRange
                )
            }
        }
        
        return nil
    }
    
    private static func parseNumericDateString(_ str: String, calendar: Calendar, referenceDate: Date) -> Date? {
        let parts = str.components(separatedBy: CharacterSet(charactersIn: "/-."))
        guard parts.count == 3 else { return nil }
        
        // Check for YYYY-MM-DD
        if parts[0].count == 4, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) {
            var comp = DateComponents()
            comp.year = year
            comp.month = month
            comp.day = day
            comp.hour = 12
            return calendar.date(from: comp)
        }
        
        // DD/MM/YYYY or DD/MM/YY
        if let day = Int(parts[0]), let month = Int(parts[1]), var year = Int(parts[2]) {
            if year < 100 {
                year += 2000
            }
            // Basic sanity validation
            guard (1...31).contains(day), (1...12).contains(month) else { return nil }
            var comp = DateComponents()
            comp.year = year
            comp.month = month
            comp.day = day
            comp.hour = 12
            return calendar.date(from: comp)
        }
        
        return nil
    }
}
