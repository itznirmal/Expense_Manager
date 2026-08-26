//
//  AppLogger.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Zero Sensitive Financial / PII Logging Subsystem.
//

import Foundation
import os

/// Centralized, privacy-first logging subsystem for Expense Manager.
/// Invariant: Raw financial data, complete card/account numbers, and raw SMS messages
/// must NEVER be output to system logs.
public enum AppLogger: Sendable {
    
    // MARK: - Subsystems & Categories
    
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.expensemanager.app"
    
    /// General application lifecycle, UI events, and navigation
    public static let general = Logger(subsystem: subsystem, category: "general")
    
    /// Transaction creation, updates, and balance ledger modifications
    public static let transactions = Logger(subsystem: subsystem, category: "transactions")
    
    /// NLP, deterministic parsing, SMS processing, and candidate classification
    public static let parsing = Logger(subsystem: subsystem, category: "parsing")
    
    /// Account management and balance synchronization
    public static let accounts = Logger(subsystem: subsystem, category: "accounts")
    
    /// Budget calculations, thresholds, and pace alerting
    public static let budgets = Logger(subsystem: subsystem, category: "budgets")
    
    /// SwiftData persistence, migrations, and model context events
    public static let storage = Logger(subsystem: subsystem, category: "storage")
    
    /// Storage database alias
    public static let database = storage
    
    /// Biometrics, App Lock, and export sanitization security events
    public static let security = Logger(subsystem: subsystem, category: "security")
    
    // MARK: - Shared Facade
    
    public struct LoggerFacade: Sendable {
        public func info(_ message: String) {
            AppLogger.general.info("\(message, privacy: .public)")
        }
        
        public func error(_ message: String) {
            AppLogger.general.error("\(message, privacy: .public)")
        }
        
        public func debug(_ message: String) {
            AppLogger.general.debug("\(message, privacy: .public)")
        }
        
        public func warning(_ message: String) {
            AppLogger.general.warning("\(message, privacy: .public)")
        }
        
        public func fault(_ message: String) {
            AppLogger.general.fault("\(message, privacy: .public)")
        }
    }
    
    public static let shared = LoggerFacade()
    
    // MARK: - Static Convenience Logging
    
    public static func info(_ message: String) {
        general.info("\(message, privacy: .public)")
    }
    
    public static func error(_ message: String, error: (any Error)? = nil) {
        if let error = error {
            general.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
        } else {
            general.error("\(message, privacy: .public)")
        }
    }
    
    public static func debug(_ message: String) {
        general.debug("\(message, privacy: .public)")
    }
    
    public static func warning(_ message: String) {
        general.warning("\(message, privacy: .public)")
    }
    
    // MARK: - Privacy & Redaction Helpers
    
    /// Sanitizes an account or card number by exposing only the last 4 digits.
    /// Example: "123456789012" -> "•••• 9012"
    public static func sanitize(accountNumber: String?) -> String {
        guard let accountNumber = accountNumber, !accountNumber.isEmpty else {
            return "•••• [empty]"
        }
        let digits = accountNumber.filter { $0.isNumber }
        if digits.count >= 4 {
            let lastFour = digits.suffix(4)
            return "•••• \(lastFour)"
        } else {
            return "•••• [short]"
        }
    }
    
    /// Sanitizes merchant names for diagnostic logging without logging personal notes.
    public static func sanitize(merchantName: String?) -> String {
        guard let merchant = merchantName?.trimmingCharacters(in: .whitespacesAndNewlines), !merchant.isEmpty else {
            return "[Unknown Merchant]"
        }
        // Limit length to prevent logging accidental conversational leakage
        if merchant.count > 30 {
            let truncated = merchant.prefix(30)
            return "\(truncated)..."
        }
        return merchant
    }
    
    /// Hashes an input source string to produce a safe diagnostic fingerprint.
    public static func fingerprint(text: String) -> String {
        var hasher = Hasher()
        hasher.combine(text)
        let hash = abs(hasher.finalize())
        return "FP-\(String(hash, radix: 16).uppercased().prefix(8))"
    }
}
