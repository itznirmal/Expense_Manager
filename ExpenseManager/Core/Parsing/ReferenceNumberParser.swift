//
//  ReferenceNumberParser.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  UPI VPA, UTR, and Transaction Reference Number Extractor.
//

import Foundation

/// Extracted reference indicators including UPI handles and transaction identifiers.
public struct ExtractedReference: Equatable, Sendable {
    public let upiVPA: String?
    public let utr: String?
    public let referenceNumber: String?
    public let matchedString: String
    public let range: Range<String.Index>?
    
    public init(
        upiVPA: String? = nil,
        utr: String? = nil,
        referenceNumber: String? = nil,
        matchedString: String = "",
        range: Range<String.Index>? = nil
    ) {
        self.upiVPA = upiVPA
        self.utr = utr
        self.referenceNumber = referenceNumber
        self.matchedString = matchedString
        self.range = range
    }
}

/// Extractor for UPI Virtual Payment Addresses (VPAs), UTRs, and bank reference IDs.
public struct ReferenceNumberParser: Sendable {
    
    public init() {}
    
    // UPI VPA pattern (e.g. "swiggy@upi", "merchant@okhdfcbank", "user@okaxis", "store@paytm")
    private static let upiVpaRegex = "(?i)\\b([a-zA-Z0-9._-]+@(upi|okhdfcbank|okaxis|okicici|oksbi|paytm|apl|ybl|axl|ibl|barodampay|idfcbank|postbank|fbl|airtel|federal))\\b"
    
    // UTR number pattern (e.g. "UTR: 123456789012", "UTR 123456789012")
    private static let utrRegex = "(?i)\\b(?:utr[:\\s/]+)([0-9a-zA-Z]{10,16})\\b"
    
    // Generic transaction reference / UPI reference pattern (e.g. "UPI/482019283741", "Ref 123456", "Txn ID: TXN123456789")
    private static let referenceRegex = "(?i)\\b(?:upi/([0-9]{10,16})|ref(?:\\s+no\\.?)?[:\\s/]+([0-9a-zA-Z]{6,18})|txn\\s+(?:id[:\\s/]+)?([0-9a-zA-Z]{6,18}))\\b"
    
    /// Extracts UPI VPAs, UTRs, and reference IDs from text.
    public static func extractReference(from text: String) -> ExtractedReference? {
        let normalized = InputNormalizer.normalize(text)
        guard !normalized.isEmpty else { return nil }
        let nsRange = NSRange(location: 0, length: normalized.utf16.count)
        
        var detectedVPA: String? = nil
        var detectedUTR: String? = nil
        var detectedRef: String? = nil
        var matchedStrings: [String] = []
        var matchedRange: Range<String.Index>? = nil
        
        // 1. Check UPI VPA
        if let regex = try? NSRegularExpression(pattern: upiVpaRegex, options: []),
           let match = regex.firstMatch(in: normalized, options: [], range: nsRange),
           match.numberOfRanges >= 2,
           let fullRange = Range(match.range(at: 0), in: normalized),
           let vpaRange = Range(match.range(at: 1), in: normalized) {
            
            detectedVPA = String(normalized[vpaRange])
            matchedStrings.append(String(normalized[fullRange]))
            matchedRange = fullRange
        }
        
        // 2. Check UTR
        if let regex = try? NSRegularExpression(pattern: utrRegex, options: []),
           let match = regex.firstMatch(in: normalized, options: [], range: nsRange),
           match.numberOfRanges >= 2,
           let fullRange = Range(match.range(at: 0), in: normalized),
           let utrRange = Range(match.range(at: 1), in: normalized) {
            
            detectedUTR = String(normalized[utrRange])
            matchedStrings.append(String(normalized[fullRange]))
            if matchedRange == nil {
                matchedRange = fullRange
            }
        }
        
        // 3. Check General Reference Number
        if let regex = try? NSRegularExpression(pattern: referenceRegex, options: []),
           let match = regex.firstMatch(in: normalized, options: [], range: nsRange),
           let fullRange = Range(match.range(at: 0), in: normalized) {
            
            for index in 1..<match.numberOfRanges {
                let range = match.range(at: index)
                if range.location != NSNotFound, let subRange = Range(range, in: normalized) {
                    detectedRef = String(normalized[subRange])
                    break
                }
            }
            matchedStrings.append(String(normalized[fullRange]))
            if matchedRange == nil {
                matchedRange = fullRange
            }
        }
        
        guard detectedVPA != nil || detectedUTR != nil || detectedRef != nil else {
            return nil
        }
        
        let primaryRef = detectedUTR ?? detectedRef ?? detectedVPA
        
        return ExtractedReference(
            upiVPA: detectedVPA,
            utr: detectedUTR,
            referenceNumber: primaryRef,
            matchedString: matchedStrings.joined(separator: " "),
            range: matchedRange
        )
    }
}
