//
//  InputNormalizer.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Text Sanitization, Unicode Normalization, and Tokenization.
//

import Foundation

/// Cleans, normalizes, and tokenizes raw input strings across all ingestion sources.
public struct InputNormalizer: Sendable {
    
    public init() {}
    
    /// Normalizes raw input text by standardizing unicode quotes, dashes, spaces, and trimming.
    public static func normalize(_ text: String) -> String {
        var result = text
        
        // 1. Standardize Unicode non-breaking spaces and zero-width spaces
        result = result.replacingOccurrences(of: "\u{00A0}", with: " ")
        result = result.replacingOccurrences(of: "\u{200B}", with: "")
        result = result.replacingOccurrences(of: "\u{FEFF}", with: "")
        
        // 2. Standardize quotation marks
        result = result.replacingOccurrences(of: "[“”„«»]", with: "\"", options: .regularExpression)
        result = result.replacingOccurrences(of: "[‘’`´]", with: "'", options: .regularExpression)
        
        // 3. Standardize hyphens, en-dashes, em-dashes, minus signs
        result = result.replacingOccurrences(of: "[—–−―]", with: "-", options: .regularExpression)
        
        // 4. Standardize ellipses
        result = result.replacingOccurrences(of: "…", with: "...")
        
        // 5. Replace multiple consecutive whitespace / tab characters with a single space
        result = result.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        
        // 6. Trim leading/trailing whitespace and newlines
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return result
    }
    
    /// Tokenizes normalized text into words while preserving punctuation cues.
    public static func tokenize(_ text: String) -> [String] {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return [] }
        return normalized.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    }
    
    /// Removes specified substring ranges from the original text and cleans remaining whitespace.
    public static func removingRanges(_ text: String, ranges: [Range<String.Index>]) -> String {
        guard !ranges.isEmpty else { return normalize(text) }
        
        // Sort ranges in reverse order so character offsets remain valid during mutation
        let sortedRanges = ranges.sorted { $0.lowerBound > $1.lowerBound }
        var result = text
        
        for range in sortedRanges {
            if range.lowerBound >= result.startIndex && range.upperBound <= result.endIndex {
                result.removeSubrange(range)
            }
        }
        
        return normalize(result)
    }
}
